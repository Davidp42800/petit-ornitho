#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
FLUTTER_SDK_DIR="${TMPDIR:-/tmp}/petit-ornitho-flutter-3.41.6"
if [ ! -x "$FLUTTER_SDK_DIR/bin/flutter" ]; then
  git clone --depth 1 --branch 3.41.6 https://github.com/flutter/flutter.git "$FLUTTER_SDK_DIR"
fi
"$FLUTTER_SDK_DIR/bin/flutter" pub get --enforce-lockfile
"$FLUTTER_SDK_DIR/bin/flutter" build web --release --pwa-strategy=none
python3 scripts/compact_web_catalogues.py build/web
