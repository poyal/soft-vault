#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test "$(uname -sm)" = 'Darwin arm64' || { echo 'Apple Silicon macOS is required.'; exit 1; }
mkdir -p .tools/downloads .tools/ffmpeg/bin .tools/ffmpeg/licenses
archive=.tools/downloads/ffmpeg-macos.zip
url=https://media.githubusercontent.com/media/zackees/ffmpeg_bins/df95abcb0ce6efff710dda5ef28a2f6f1dc21493/v8.0/darwin_arm64.zip
if [ ! -f "$archive" ]; then curl -fL "$url" -o "$archive"; fi
echo "b2da44a8169c4d09a97db996250690c3346f72e4795521d23d3dbb1e72421207  $archive" | shasum -a 256 -c -
unzip -oq "$archive" -d .tools/ffmpeg/extracted
for tool in ffmpeg ffprobe; do
  if [ -f ".tools/ffmpeg/bin/$tool" ]; then chmod u+w ".tools/ffmpeg/bin/$tool"; fi
  cp ".tools/ffmpeg/extracted/darwin_arm64/$tool" ".tools/ffmpeg/bin/$tool"
  chmod 755 ".tools/ffmpeg/bin/$tool"
done
curl -fsSL https://raw.githubusercontent.com/FFmpeg/FFmpeg/n7.0/COPYING.GPLv2 -o .tools/ffmpeg/licenses/COPYING.GPLv2
.tools/ffmpeg/bin/ffmpeg -version > .tools/ffmpeg/licenses/build-configuration.txt
.tools/ffmpeg/bin/ffmpeg -L > .tools/ffmpeg/licenses/license.txt 2>&1
printf '%s\n' "$url" 'FFmpeg reports version 7.0; the provider archive directory is named v8.0.' \
  'FFmpeg source: https://github.com/FFmpeg/FFmpeg/tree/n7.0' \
  > .tools/ffmpeg/licenses/source.txt
