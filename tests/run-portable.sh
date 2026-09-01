#!/usr/bin/env bash
set -euo pipefail

plugin_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
qt_bin=${QT_BIN_DIR:-/usr/lib/qt6/bin}

python3 "$plugin_dir/tests/static_contract.py"
python3 "$plugin_dir/tests/qualified_app_contract.py"
python3 -m json.tool "$plugin_dir/manifest.json" >/dev/null
for shell_script in "$plugin_dir"/tests/*.sh "$plugin_dir"/scripts/release/*.sh; do
  bash -n "$shell_script"
done

QT_QPA_PLATFORM=offscreen "$qt_bin/qmltestrunner" \
  -input "$plugin_dir/tests/tst_model.qml" \
  -import "$plugin_dir"
