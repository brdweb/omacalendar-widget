#!/usr/bin/env bash
set -euo pipefail

plugin_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
runtime_dir=$(mktemp -d)
weston_log="$runtime_dir/weston.log"
weston_pid=""

cleanup() {
  if [[ -n $weston_pid ]]; then
    kill "$weston_pid" 2>/dev/null || true
    wait "$weston_pid" 2>/dev/null || true
  fi
  rm -rf -- "$runtime_dir"
}
trap cleanup EXIT

chmod 700 "$runtime_dir"
export XDG_RUNTIME_DIR="$runtime_dir"
export WAYLAND_DISPLAY=wayland-1
export QT_QPA_PLATFORM=wayland

weston \
  --backend=headless \
  --renderer=pixman \
  --fake-seat \
  --width=3840 \
  --height=2160 \
  --socket="$WAYLAND_DISPLAY" \
  --idle-time=0 \
  --no-config \
  --log="$weston_log" &
weston_pid=$!

for _attempt in $(seq 1 200); do
  [[ -S "$runtime_dir/$WAYLAND_DISPLAY" ]] && break
  kill -0 "$weston_pid" 2>/dev/null || {
    cat "$weston_log" >&2
    exit 1
  }
  sleep 0.02
done

if [[ ! -S "$runtime_dir/$WAYLAND_DISPLAY" ]]; then
  cat "$weston_log" >&2
  echo "headless Wayland compositor did not become ready" >&2
  exit 1
fi

"$plugin_dir/tests/run.sh"
