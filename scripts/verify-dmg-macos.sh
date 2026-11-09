#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
repo="$PWD"
dmg="${1:?Pass the verified DMG path}"
fixture="${2:?Pass a video fixture}"
mkdir -p build/installer-020
stage=$(mktemp -d "$repo/build/installer-020/mount.XXXXXX")
mount="$stage/volume"
mkdir "$mount"
hdiutil attach -readonly -nobrowse -mountpoint "$mount" "$dmg"
trap 'hdiutil detach "$mount" >/dev/null' EXIT
test "$(readlink "$mount/Applications")" = /Applications
ditto "$mount/Soft Vault.app" "$stage/Soft Vault.app"
codesign --verify --deep --strict "$stage/Soft Vault.app"
python3 - "$stage/Soft Vault.app" <<'PY'
import json,pathlib,hashlib,sys
app=pathlib.Path(sys.argv[1])
prior=json.load(open('build/e2e/installed-results.json'))
source=pathlib.Path(prior['executable']).parents[2]
old={p.relative_to(source).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in source.rglob('*') if p.is_file()}
new={p.relative_to(app).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in app.rglob('*') if p.is_file()}
assert old==new,'DMG app differs from verified release app'
print('DMG application hashes match the verified release')
PY
report="$repo/build/installer-020/macos-dmg-results.json"
env PATH=/usr/bin:/bin:/usr/sbin:/sbin "$stage/Soft Vault.app/Contents/MacOS/Soft Vault" --verify-install "$report" "$fixture" "$repo/.tools/fixtures/codecs" &
pid=$!
deadline=$(( $(date +%s) + 300 ))
while kill -0 "$pid" 2>/dev/null; do
 if [ "$(date +%s)" -ge "$deadline" ]; then kill "$pid"; echo 'DMG application verification timed out'; exit 1; fi
 sleep 2
done
wait "$pid"
python3 - "$dmg" "$report" <<'PY'
import json,pathlib,hashlib,sys
dmg,report=map(pathlib.Path,sys.argv[1:])
r=json.loads(report.read_text());assert r['passed']
r.update(dmgSHA256=hashlib.sha256(dmg.read_bytes()).hexdigest(),applicationHashesMatch=True,applicationsLinkVerified=True,signature='ad-hoc; not notarized')
report.write_text(json.dumps(r,indent=2))
print('DMG mount, application copy, signature and installed diagnostics PASS')
PY
