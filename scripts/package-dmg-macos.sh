#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
repo="$PWD"
zip="${1:-$repo/build/package/SoftVault-macOS-arm64.zip}"
output="${2:-$repo/build/package}"
mkdir -p "$output" build/dmg-stage
stage=$(mktemp -d "$repo/build/dmg-stage/package.XXXXXX")
ditto -x -k "$zip" "$stage/source"
package="$stage/source/SoftVault-macOS-arm64"
python3 - "$package" <<'PY'
import hashlib,json,pathlib,sys
r=pathlib.Path(sys.argv[1])
for x in json.loads((r/'manifest.json').read_text()):
 p=r/x['path']
 assert p.resolve().is_relative_to(r.resolve())
 assert hashlib.sha256(p.read_bytes()).hexdigest()==x['sha256'],x['path']
PY
app="$package/Soft Vault.app"
codesign --verify --deep --strict "$app"
version=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$app/Contents/Info.plist")
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
mkdir "$stage/image"
ditto "$app" "$stage/image/Soft Vault.app"
ln -s /Applications "$stage/image/Applications"
cp "$package/THIRD_PARTY_NOTICES.txt" "$stage/image/"
printf '%s\n' 'Soft Vault.app을 Applications로 드래그한 뒤 디스크를 꺼내세요.' '기존 원본 영상과 카탈로그는 앱 교체·제거로 삭제되지 않습니다.' > "$stage/image/설치 안내.txt"
dmg="$output/SoftVault-$version-macOS-arm64.dmg"
test ! -e "$dmg"
hdiutil create -volname 'Soft Vault' -srcfolder "$stage/image" -format UDZO -ov "$dmg"
hdiutil verify "$dmg"
(cd "$output" && shasum -a 256 "$(basename "$dmg")" > "$(basename "$dmg").sha256")
echo "$dmg"
