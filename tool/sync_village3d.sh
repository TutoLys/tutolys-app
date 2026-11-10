#!/usr/bin/env bash
# Copies the 3D village's built bundle into the app's assets (ADR 0126).
#
#   tool/sync_village3d.sh [path/to/village-3d/dist]
#
# The bundle ships inside the app: no CDN at runtime (offline-first). This
# refuses a bundle that loads anything from another origin, then prints
# what it weighs.
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
src="${1:-$here/../codex/village-3d/dist}"
dst="$here/assets/village3d"

[[ -f "$src/village.html" ]] || { echo "no village.html in $src" >&2; exit 1; }

# Anything fetched from the network would break offline play.
# Comment lines are skipped (three.js documents CDN usage in its comments).
if grep -rInE "(src|href|import[^'\"]*)[= (]*['\"]https?://|from ['\"]https?://|url\(['\"]?https?://" \
     --include='*.html' --include='*.js' --include='*.css' "$src" \
   | grep -vE "^[^:]+:[0-9]+:[[:space:]]*(//|\*|/\*)"; then
  echo "the bundle above loads from another origin; refusing" >&2
  exit 1
fi

rm -rf "$dst"
mkdir -p "$dst"
cp -R "$src"/. "$dst"/

# Flutter asset folders are not recursive: list every folder for pubspec.
echo "asset folders (keep pubspec.yaml in step):"
(cd "$here" && find assets/village3d -type d | sort | sed 's|$|/|; s|^|    - |')
echo "size:"
du -sh "$dst"
