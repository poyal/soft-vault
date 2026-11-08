#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
repo="$PWD"
fixture="${1:?Pass an absolute video fixture path}"
zip="$repo/build/package/SoftVault-macOS-arm64.zip"
mkdir -p build/install-smoke build/e2e
installation=$(mktemp -d "$repo/build/install-smoke/macos.XXXXXX")
ditto -x -k "$zip" "$installation"
package="$installation/SoftVault-macOS-arm64"
python3 - "$package" <<'PY'
import hashlib, json, pathlib, sys
root = pathlib.Path(sys.argv[1])
entries = json.loads((root / 'manifest.json').read_text())
for entry in entries:
    p = root / entry['path']
    assert p.resolve().is_relative_to(root.resolve()), entry['path']
    assert hashlib.sha256(p.read_bytes()).hexdigest() == entry['sha256'], entry['path']
print(f'Verified {len(entries)} package files')
PY
app="$package/Soft Vault.app"
codesign --verify --deep --strict "$app"
report="$repo/build/e2e/installed-results.json"
env PATH=/usr/bin:/bin:/usr/sbin:/sbin "$app/Contents/MacOS/Soft Vault" \
  --verify-install "$report" "$fixture" "$repo/.tools/fixtures/codecs" > "$repo/build/verification/installed.log" 2>&1 &
pid=$!
trap 'kill "$pid" 2>/dev/null || true' EXIT HUP INT TERM
deadline=$(( $(date +%s) + 300 ))
while kill -0 "$pid" 2>/dev/null; do
  if [ "$(date +%s)" -ge "$deadline" ]; then echo 'Installed verification timeout'; exit 1; fi
  sleep 2
done
wait "$pid"
trap - EXIT HUP INT TERM
python3 - "$report" "$zip" <<'PY'
import datetime, hashlib, json, pathlib, sys
p, archive = map(pathlib.Path, sys.argv[1:])
r = json.loads(p.read_text())
assert r['passed'], r
r.update(packageSHA256=hashlib.sha256(archive.read_bytes()).hexdigest(),
         verifiedAtUTC=datetime.datetime.now(datetime.timezone.utc).isoformat(),
         pathContainsDevelopmentTools=False, signature='ad-hoc; not notarized')
p.write_text(json.dumps(r, indent=2), encoding='utf-8')
print(p.read_text())
PY
