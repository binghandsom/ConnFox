#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter 还没有安装好，或者 flutter 没有加入 PATH。"
  exit 1
fi

flutter config --enable-macos-desktop
flutter create --platforms=macos .
flutter pub get

echo
echo "macOS 工程已补齐，下一步可以运行："
echo "  flutter run -d macos"
