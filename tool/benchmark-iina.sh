#!/bin/bash
# Native mpv callbacks inside IINA; this does not measure IINA's mouse controls.
set -euo pipefail
app=${1:?Pass the test IINA.app path}
fixtures=${2:?Pass the fixture directory}
output=${3:?Pass the JSON result path}
app=$(cd "$app" && pwd)
fixtures=$(cd "$fixtures" && pwd)
mkdir -p "$(dirname "$output")"
output="$(cd "$(dirname "$output")" && pwd)/$(basename "$output")"
script="$(cd "$(dirname "$0")" && pwd)/playback-reference.lua"
if pgrep -x IINA >/dev/null; then
  echo 'An IINA instance is already running; leave it untouched.' >&2
  exit 2
fi
if test -e "$output"; then echo 'Use a new output path.' >&2; exit 2; fi
ipc_directory=$(mktemp -d /tmp/soft-vault-iina.XXXXXX)
ipc_socket="$ipc_directory/mpv.sock"
owned_pid=''
cleanup() {
  if test -n "$owned_pid" && test "$(ps -p "$owned_pid" -o comm= 2>/dev/null)" = "$app/Contents/MacOS/IINA"; then
    kill -TERM "$owned_pid" 2>/dev/null || true
  fi
  rm -f "$ipc_socket"
  rmdir "$ipc_directory" 2>/dev/null || true
}
trap cleanup EXIT HUP INT TERM
"$app/Contents/MacOS/iina-cli" --no-stdin --mpv-config=no --mpv-hwdec=auto --mpv-volume=0 \
  --mpv-geometry=1280x800 "--mpv-input-ipc-server=$ipc_socket" \
  "--mpv-script-opts=quality-output=$output,quality-seconds=${PLAYBACK_SECONDS:-10},quality-seeks=${PLAYBACK_SEEKS:-30}" \
  "$fixtures/h264-1080p-vfr.mkv" "$fixtures/h264-1080p24-long-gop.mp4" \
  "$fixtures/h264-1080p30.mp4" "$fixtures/h264-1080p60.mp4" \
  "$fixtures/hevc-4k24-10bit.mkv" "$fixtures/hevc-4k60-10bit.mkv"
sleep 2
for candidate_pid in $(pgrep -x IINA || true); do
  if test "$(ps -p "$candidate_pid" -o comm=)" = "$app/Contents/MacOS/IINA"; then
    owned_pid=$candidate_pid
    break
  fi
done
if test -z "$owned_pid"; then echo 'Test IINA process did not launch.' >&2; exit 1; fi
# IINA applies CLI mpv properties after initialization, so setting `scripts`
# does not load a script. Load it explicitly, then replay the first entry.
python3 - "$ipc_socket" "$script" <<'PY'
import json, pathlib, socket, sys, time
for _ in range(50):
    if pathlib.Path(sys.argv[1]).exists():
        break
    time.sleep(.1)
with socket.socket(socket.AF_UNIX) as client:
    client.settimeout(5)
    client.connect(sys.argv[1])
    stream = client.makefile('rb')
    def command(arguments, request_id):
        client.sendall((json.dumps({'command': arguments, 'request_id': request_id})+'\n').encode())
        while True:
            response = json.loads(stream.readline())
            if response.get('request_id') == request_id:
                if response.get('error') != 'success':
                    raise RuntimeError(response)
                return response.get('data')
    if command(['get_property', 'playlist-count'], 1) != 6:
        raise RuntimeError('IINA did not create the six-file test playlist')
    command(['load-script', sys.argv[2]], 2)
    time.sleep(.3)
    command(['playlist-play-index', 0], 3)
PY
deadline=$(( $(date +%s) + 600 ))
while test "$(date +%s)" -lt "$deadline"; do
  status=$(python3 - "$output" <<'PY'
import json, pathlib, sys
try:
    r = json.loads(pathlib.Path(sys.argv[1]).read_text())
    rows = r.get('files', [])
    print('error' if any(x.get('error') for x in rows) else
          'complete' if len(rows) == 6 and all(x.get('completed') for x in rows) else 'pending')
except (OSError, ValueError):
    print('pending')
PY
)
  case "$status" in
    complete) echo 'IINA reference completed'; exit 0;;
    error) echo 'IINA reported a benchmark error' >&2; exit 1;;
  esac
  kill -0 "$owned_pid" 2>/dev/null || { echo 'IINA exited before completing the benchmark' >&2; exit 1; }
  sleep 2
done
echo 'IINA benchmark timed out; inspect the partial result and log.' >&2
exit 1
