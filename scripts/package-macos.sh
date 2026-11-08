#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
repo="$PWD"
release="$repo/build/macos/Build/Products/Release/Soft Vault.app"
test -d "$release"
test -x .tools/ffmpeg/bin/ffmpeg
test -f .tools/ffmpeg/licenses/COPYING.GPLv2
mkdir -p build/package
staging=$(mktemp -d "$repo/build/package/macos-stage.XXXXXX")
package="$staging/SoftVault-macOS-arm64"
mkdir -p "$package"
ditto "$release" "$package/Soft Vault.app"
app="$package/Soft Vault.app"
mkdir -p "$app/Contents/MacOS/tools" "$app/Contents/Resources/licenses/ffmpeg"
cp .tools/ffmpeg/bin/ffmpeg .tools/ffmpeg/bin/ffprobe "$app/Contents/MacOS/tools/"
cp .tools/ffmpeg/licenses/* "$app/Contents/Resources/licenses/ffmpeg/"
cp THIRD_PARTY_NOTICES.txt "$package/"
cat > "$package/설치 안내.txt" <<'README'
Soft Vault — Apple Silicon Mac

Soft Vault.app을 응용 프로그램 폴더로 복사하고 실행하세요.
앱 안에 재생·썸네일 도구가 포함되어 있습니다. 별도 Flutter나 FFmpeg 설치는 필요하지 않습니다.
이 배포본은 로컬 서명이며 Apple Developer ID 서명·공증을 받지 않았습니다.
macOS가 실행을 차단하면 출처를 확인한 뒤 시스템 설정의 개인정보 보호 및 보안에서 허용하세요.
앱의 전체 내용을 함께 유지하세요. 앱 교체는 원본 영상이나 카탈로그를 삭제하지 않습니다.
처음 실행할 때 앱 시작 비밀번호를 설정할 수 있습니다. 원본 영상의 암호화 기능은 아닙니다.
README 사용자 매뉴얼: https://github.com/poyal/soft-vault
README
for tool in ffmpeg ffprobe; do codesign --force --sign - "$app/Contents/MacOS/tools/$tool"; done
codesign --force --deep --sign - "$app"
codesign --verify --deep --strict --verbose=2 "$app"
python3 - "$package" <<'PY'
import hashlib, json, pathlib, sys
root = pathlib.Path(sys.argv[1])
rows = [{"path": p.relative_to(root).as_posix(), "sha256": hashlib.sha256(p.read_bytes()).hexdigest()}
        for p in sorted(root.rglob('*')) if p.is_file() and not p.is_symlink()]
(root / 'manifest.json').write_text(json.dumps(rows, indent=2, ensure_ascii=False), encoding='utf-8')
PY
zip="$repo/build/package/SoftVault-macOS-arm64.zip"
ditto -c -k --sequesterRsrc --keepParent "$package" "$zip"
(cd build/package && shasum -a 256 SoftVault-macOS-arm64.zip > SoftVault-macOS-arm64.zip.sha256)
echo "$zip"
