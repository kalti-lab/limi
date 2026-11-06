#!/bin/zsh
# Builds the app icons drawn by scripts/make-app-icon.swift:
#   ./scripts/make-app-icons.sh pro    assets/AppIcon.icns       (AgentBar Pro)
#   ./scripts/make-app-icons.sh free   assets/AppIcon-Free.icns  (free edition, FREE ribbon)
# With no argument it builds both. build-app.sh picks the one for its edition.
set -euo pipefail

repo_dir=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d "${TMPDIR:-/tmp}/agentbar-icons.XXXXXX")
trap 'rm -rf "$work"' EXIT
if (( $# == 0 )); then set -- pro free; fi

for variant in "$@"; do
  case "$variant" in
    pro) name=AppIcon; flags=() ;;
    free) name=AppIcon-Free; flags=(--free) ;;
    *) echo "Unknown icon: $variant (pro or free)" >&2; exit 1 ;;
  esac
  png="$work/$name.png"
  swift "$repo_dir/scripts/make-app-icon.swift" "$png" "${flags[@]}" >/dev/null
  iconset="$work/$name.iconset"
  mkdir -p "$iconset"
  for s in 16 32 128 256 512; do
    sips -z $s $s "$png" --out "$iconset/icon_${s}x${s}.png" >/dev/null
    sips -z $((s * 2)) $((s * 2)) "$png" --out "$iconset/icon_${s}x${s}@2x.png" >/dev/null
  done
  iconutil -c icns "$iconset" -o "$repo_dir/assets/$name.icns"
  echo "Wrote assets/$name.icns"
done
