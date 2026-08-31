#!/usr/bin/env bash
set -euo pipefail

repository_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
output_path=${1:-"$repository_root/preview.png"}
if [[ $output_path != /* ]]; then
  output_path="$PWD/$output_path"
fi
output_directory=$(dirname "$output_path")

if [[ ! -d $output_directory ]]; then
  echo "preview output directory does not exist: $output_directory" >&2
  exit 1
fi
if [[ -L $output_path ]]; then
  echo "refusing to replace a symlinked preview: $output_path" >&2
  exit 1
fi

for command in Hyprland grim hyprctl identify magick python3 quickshell rg tesseract; do
  if ! command -v "$command" >/dev/null; then
    echo "preview capture requires $command" >&2
    exit 1
  fi
done

parent_runtime=${XDG_RUNTIME_DIR:-}
parent_socket=${WAYLAND_DISPLAY:-}
if [[ -z $parent_runtime || -z $parent_socket ]]; then
  echo "preview capture must run in an Omarchy Wayland session" >&2
  exit 1
fi
if [[ $parent_socket = /* ]]; then
  parent_display=$parent_socket
else
  parent_display="$parent_runtime/$parent_socket"
fi
if [[ ! -S $parent_display ]]; then
  echo "parent Wayland socket is unavailable: $parent_display" >&2
  exit 1
fi

nested_runtime=$(mktemp -d)
capture_root=$(mktemp -d)
chmod 700 "$nested_runtime" "$capture_root"

hyprland_pid=""
daemon_pid=""
quickshell_pid=""
cleanup() {
  if [[ -n $quickshell_pid ]]; then
    kill "$quickshell_pid" 2>/dev/null || true
    wait "$quickshell_pid" 2>/dev/null || true
  fi
  if [[ -n $daemon_pid ]]; then
    kill "$daemon_pid" 2>/dev/null || true
    wait "$daemon_pid" 2>/dev/null || true
  fi
  if [[ -n $hyprland_pid ]]; then
    kill "$hyprland_pid" 2>/dev/null || true
    wait "$hyprland_pid" 2>/dev/null || true
  fi
  rm -rf -- "$nested_runtime" "$capture_root"
}
trap cleanup EXIT

mkdir -p "$capture_root/qs"
mkdir -p \
  "$capture_root/xdg-cache" \
  "$capture_root/xdg-config" \
  "$capture_root/xdg-data" \
  "$capture_root/xdg-state"
ln -s /usr/share/omarchy/shell/Commons "$capture_root/qs/Commons"
ln -s /usr/share/omarchy/shell/Ui "$capture_root/qs/Ui"
ln -s /usr/share/omarchy/shell/Commons "$capture_root/Commons"
ln -s /usr/share/omarchy/shell/Ui "$capture_root/Ui"
cp "$repository_root/tests/harness.qml" "$capture_root/shell.qml"

env -u HYPRLAND_INSTANCE_SIGNATURE \
  XDG_RUNTIME_DIR="$nested_runtime" \
  WAYLAND_DISPLAY="$parent_display" \
  Hyprland --config "$repository_root/tools/preview/hyprland.lua" \
  >"$capture_root/hyprland.log" 2>&1 &
hyprland_pid=$!

nested_socket=""
nested_signature=""
for _attempt in $(seq 1 250); do
  nested_socket=$(find "$nested_runtime" -maxdepth 1 -type s -name 'wayland-*' -printf '%f\n' | head -1 || true)
  nested_signature=$(find "$nested_runtime/hypr" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | head -1 || true)
  if [[ -n $nested_socket && -n $nested_signature ]]; then
    break
  fi
  if ! kill -0 "$hyprland_pid" 2>/dev/null; then
    sed -n '1,240p' "$capture_root/hyprland.log" >&2
    echo "isolated Hyprland compositor exited before becoming ready" >&2
    exit 1
  fi
  sleep 0.03
done
if [[ -z $nested_socket || -z $nested_signature ]]; then
  sed -n '1,240p' "$capture_root/hyprland.log" >&2
  echo "isolated Hyprland compositor did not become ready" >&2
  exit 1
fi

control_ready=false
for _attempt in $(seq 1 100); do
  if env XDG_RUNTIME_DIR="$nested_runtime" HYPRLAND_INSTANCE_SIGNATURE="$nested_signature" \
    hyprctl monitors -j >/dev/null 2>&1; then
    control_ready=true
    break
  fi
  sleep 0.03
done
if [[ $control_ready != true ]]; then
  echo "isolated Hyprland control socket did not become ready" >&2
  exit 1
fi

headless_created=false
for _attempt in $(seq 1 100); do
  if env XDG_RUNTIME_DIR="$nested_runtime" HYPRLAND_INSTANCE_SIGNATURE="$nested_signature" \
    hyprctl output create headless preview >/dev/null 2>&1; then
    headless_created=true
    break
  fi
  sleep 0.03
done
if [[ $headless_created != true ]]; then
  echo "isolated headless preview output could not be created" >&2
  exit 1
fi
for _attempt in $(seq 1 100); do
  if env XDG_RUNTIME_DIR="$nested_runtime" HYPRLAND_INSTANCE_SIGNATURE="$nested_signature" \
    hyprctl monitors all -j | rg -q '"name": "preview"'; then
    break
  fi
  sleep 0.03
done
if ! env XDG_RUNTIME_DIR="$nested_runtime" HYPRLAND_INSTANCE_SIGNATURE="$nested_signature" \
  hyprctl monitors all -j | rg -q '"name": "preview"'; then
  echo "isolated headless preview output was not created" >&2
  exit 1
fi

preview_socket="$nested_runtime/preview.sock"
python3 "$repository_root/tools/preview/fake_preview_daemon.py" "$preview_socket" \
  >"$capture_root/daemon.log" 2>&1 &
daemon_pid=$!
for _attempt in $(seq 1 100); do
  [[ -S $preview_socket ]] && break
  sleep 0.02
done
if [[ ! -S $preview_socket ]]; then
  echo "synthetic preview daemon did not become ready" >&2
  exit 1
fi

quickshell_log="$capture_root/quickshell.log"
env -u DBUS_SESSION_BUS_ADDRESS \
  XDG_RUNTIME_DIR="$nested_runtime" \
  XDG_CACHE_HOME="$capture_root/xdg-cache" \
  XDG_CONFIG_HOME="$capture_root/xdg-config" \
  XDG_DATA_HOME="$capture_root/xdg-data" \
  XDG_STATE_HOME="$capture_root/xdg-state" \
  WAYLAND_DISPLAY="$nested_socket" \
  HYPRLAND_INSTANCE_SIGNATURE="$nested_signature" \
  QT_QPA_PLATFORM=wayland \
  OMACALENDAR_PREVIEW_SCREEN=preview \
  OMACALENDAR_PREVIEW_SOCKET="$preview_socket" \
  OMACALENDAR_WIDGET_ENTRY="file://$repository_root/tools/preview/preview_harness.qml" \
  quickshell --no-color --path "$capture_root/shell.qml" \
  >"$quickshell_log" 2>&1 &
quickshell_pid=$!

for _attempt in $(seq 1 240); do
  if rg -q 'PREVIEW_RENDER_READY' "$quickshell_log"; then
    break
  fi
  if rg -q 'PREVIEW_CAPTURE_FAIL' "$quickshell_log" || ! kill -0 "$quickshell_pid" 2>/dev/null; then
    sed -n '1,260p' "$quickshell_log" >&2
    echo "widget preview renderer failed" >&2
    exit 1
  fi
  sleep 0.05
done
if ! rg -q 'PREVIEW_RENDER_READY' "$quickshell_log"; then
  sed -n '1,260p' "$quickshell_log" >&2
  echo "widget preview renderer timed out" >&2
  exit 1
fi

raw_capture="$capture_root/raw.png"
env XDG_RUNTIME_DIR="$nested_runtime" WAYLAND_DISPLAY="$nested_socket" \
  grim -o preview "$raw_capture"
raw_dimensions=$(identify -format '%wx%h' "$raw_capture")
if [[ $raw_dimensions != 800x800 ]]; then
  echo "isolated capture has unexpected dimensions: $raw_dimensions" >&2
  exit 1
fi

rendered_preview="$capture_root/preview.png"
magick "$raw_capture" \
  -trim +repage \
  -bordercolor '#0b0f14' -border 12 \
  -strip \
  -define png:exclude-chunks=date,time \
  "$rendered_preview"
python3 "$repository_root/tools/preview/validate_preview.py" "$rendered_preview"

mv -f -- "$rendered_preview" "$output_path"
echo "Generated privacy-safe widget preview: $output_path"
