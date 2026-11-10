#!/bin/zsh
# Builds assets/AppIcon.icns from the icon drawn by scripts/make-app-icon.swift:
#   ./scripts/make-app-icons.sh
set -euo pipefail

repo_dir=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d "${TMPDIR:-/tmp}/limi-icons.XXXXXX")
trap 'rm -rf "$work"' EXIT

name=AppIcon
png="$work/$name.png"
swift "$repo_dir/scripts/make-app-icon.swift" "$png" >/dev/null
iconset="$work/$name.iconset"
mkdir -p "$iconset"
for s in 16 32 128 256 512; do
  sips -z $s $s "$png" --out "$iconset/icon_${s}x${s}.png" >/dev/null
  sips -z $((s * 2)) $((s * 2)) "$png" --out "$iconset/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$iconset" -o "$repo_dir/assets/$name.icns"
echo "Wrote assets/$name.icns"
