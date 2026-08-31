#!/usr/bin/env bash
set -euo pipefail

plugin_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
qt_bin=/usr/lib/qt6/bin
omarchy_root=${OMARCHY_PATH:-/usr/share/omarchy}

python3 "$plugin_dir/tests/static_contract.py"
python3 -m json.tool "$plugin_dir/manifest.json" >/dev/null
for shell_script in "$plugin_dir"/tests/*.sh "$plugin_dir"/scripts/release/*.sh; do
  bash -n "$shell_script"
done

omarchy plugin validate "$plugin_dir"

test_root=$(mktemp -d)
fake_pid=""
cleanup() {
  if [[ -n $fake_pid ]]; then
    kill "$fake_pid" 2>/dev/null || true
    wait "$fake_pid" 2>/dev/null || true
  fi
  rm -rf -- "$test_root"
}
trap cleanup EXIT
mkdir -p "$test_root/qs"
ln -s "$omarchy_root/shell/Commons" "$test_root/qs/Commons"
ln -s "$omarchy_root/shell/Ui" "$test_root/qs/Ui"
cp "$plugin_dir/tests/harness.qml" "$test_root/shell.qml"
ln -s "$omarchy_root/shell/Commons" "$test_root/Commons"
ln -s "$omarchy_root/shell/Ui" "$test_root/Ui"

qml_files=(
  "$plugin_dir/BarWidget.qml"
  "$plugin_dir/Panel.qml"
  "$plugin_dir/OmaCalendarClient.qml"
  "$plugin_dir/components/MonthGrid.qml"
  "$plugin_dir/components/AgendaList.qml"
  "$plugin_dir/components/EventEditor.qml"
  "$plugin_dir/components/CompactTimeline.qml"
  "$plugin_dir/tests/client_harness.qml"
  "$plugin_dir/tests/layout_harness.qml"
  "$plugin_dir/tests/tst_keyboard.qml"
  "$plugin_dir/tests/agenda_harness.qml"
  "$plugin_dir/tests/default_calendar_harness.qml"
)

for qml_file in "${qml_files[@]}"; do
  "$qt_bin/qmllint" \
    --missing-property disable \
    --signal-handler-parameters disable \
    --max-warnings 0 \
    -I "$test_root" \
    -I /usr/lib/qt6/qml \
    -I "$plugin_dir" \
    "$qml_file"
done

QT_QPA_PLATFORM=offscreen "$qt_bin/qmltestrunner" \
  -input "$plugin_dir/tests/tst_model.qml" \
  -import "$plugin_dir"

QT_QPA_PLATFORM=offscreen "$qt_bin/qmltestrunner" \
  -input "$plugin_dir/tests/tst_keyboard.qml" \
  -import "$test_root" \
  -import "$plugin_dir"

run_client_scenario() {
  local scenario=$1
  local socket_path="$test_root/$scenario.sock"
  local client_output
  local client_status

  python3 "$plugin_dir/tests/fake_daemon.py" "$socket_path" "$scenario" &
  fake_pid=$!
  for _attempt in $(seq 1 100); do
    [[ -S $socket_path ]] && break
    sleep 0.02
  done
  [[ -S $socket_path ]]

  set +e
  client_output=$(timeout 15s env \
    OMACALENDAR_TEST_SCENARIO="$scenario" \
    OMACALENDAR_TEST_SOCKET="$socket_path" \
    OMACALENDAR_WIDGET_ENTRY="file://$plugin_dir/tests/client_harness.qml" \
    quickshell --no-color --path "$test_root/shell.qml" 2>&1)
  client_status=$?
  set -e

  if [[ $client_status -ne 0 ]] || ! grep -q "CLIENT_TEST_PASS \[$scenario\]" <<<"$client_output"; then
    printf '%s\n' "$client_output" >&2
    exit 1
  fi

  kill "$fake_pid"
  wait "$fake_pid" 2>/dev/null || true
  fake_pid=""
  printf 'IPC scenario passed: %s\n' "$scenario"
}

for scenario in happy mutation-contract gap sync-status offline restart incompatible; do
  run_client_scenario "$scenario"
done

set +e
agenda_output=$(timeout 5s env \
  OMACALENDAR_WIDGET_ENTRY="file://$plugin_dir/tests/agenda_harness.qml" \
  quickshell --no-color --path "$test_root/shell.qml" 2>&1)
agenda_status=$?
set -e
if [[ $agenda_status -ne 0 ]] || ! grep -q "AGENDA_TEST_PASS" <<<"$agenda_output"; then
  printf '%s\n' "$agenda_output" >&2
  exit 1
fi
echo "Agenda timeline smoke passed"

set +e
default_calendar_output=$(timeout 5s env \
  OMACALENDAR_WIDGET_ENTRY="file://$plugin_dir/tests/default_calendar_harness.qml" \
  quickshell --no-color --path "$test_root/shell.qml" 2>&1)
default_calendar_status=$?
set -e
if [[ $default_calendar_status -ne 0 ]] || ! grep -q "DEFAULT_CALENDAR_TEST_PASS" <<<"$default_calendar_output"; then
  printf '%s\n' "$default_calendar_output" >&2
  exit 1
fi
echo "Default calendar smoke passed"

for scale in 1 1.25 2; do
  set +e
  runtime_output=$(timeout 2s env \
    QT_SCALE_FACTOR="$scale" \
    OMACALENDAR_WIDGET_ENTRY="file://$plugin_dir/tests/layout_harness.qml" \
    quickshell --no-color --path "$test_root/shell.qml" 2>&1)
  runtime_status=$?
  set -e

  if [[ $runtime_status -ne 0 && $runtime_status -ne 124 ]]; then
    printf '%s\n' "$runtime_output" >&2
    exit "$runtime_status"
  fi

  if grep -q "ERROR: Failed to load configuration" <<<"$runtime_output"; then
    printf '%s\n' "$runtime_output" >&2
    exit 1
  fi

  if ! grep -q "LAYOUT_TEST_PASS" <<<"$runtime_output"; then
    printf '%s\n' "$runtime_output" >&2
    exit 1
  fi
  printf 'Layout smoke passed at scale %s\n' "$scale"
done

echo "OmaCalendar widget validation passed"
