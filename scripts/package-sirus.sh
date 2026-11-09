#!/usr/bin/env bash
# Build a drop-in release archive for the Sirus (3.3.5a) backport.
#
#   bash scripts/package-sirus.sh [version]
#
# Produces dist/WhisperMessenger-<version>-sirus.zip whose only top-level entry
# is the WhisperMessenger/ folder, so it can be unpacked straight into
# World of Warcraft/Interface/AddOns. The version defaults to the
# "## Version:" line of WhisperMessenger.toc.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

ADDON="WhisperMessenger"
TOC="${ADDON}.toc"

VERSION="${1:-}"
if [ -z "$VERSION" ]; then
  VERSION="$(sed -n 's/^## Version:[[:space:]]*//p' "$TOC" | tr -d '\r' | head -n 1)"
fi
if [ -z "$VERSION" ]; then
  echo "error: no '## Version:' line in $TOC" >&2
  exit 1
fi

DIST="$ROOT/dist"
STAGE="$DIST/stage"
ZIP_NAME="${ADDON}-${VERSION}-sirus.zip"
OUT="$DIST/$ZIP_NAME"

# Everything the client needs at runtime. Dev files (tests, scripts, docs,
# lint configs, archive/) stay out.
ITEMS=(
  "$TOC"
  Bindings.xml
  Bootstrap.lua
  LICENSE
  Core
  Locale
  Media
  Model
  Persistence
  Transport
  UI
  Util
)

rm -rf "$STAGE" "$OUT"
mkdir -p "$STAGE/$ADDON"

for item in "${ITEMS[@]}"; do
  if [ ! -e "$item" ]; then
    echo "error: package item not found: $item" >&2
    exit 1
  fi
  cp -R "$item" "$STAGE/$ADDON/"
done

# Dev-only module index files, same list as the .pkgmeta ignore block.
if [ -f .pkgmeta ]; then
  while IFS= read -r rel; do
    rm -f "$STAGE/$ADDON/$rel"
  done < <(tr -d '\r' < .pkgmeta | sed -n 's/^[[:space:]]*-[[:space:]]*\(.*\/init\.lua\)[[:space:]]*$/\1/p')
fi

# Editor / OS junk.
find "$STAGE/$ADDON" \( -name '.DS_Store' -o -name 'Thumbs.db' -o -name '*.bak' -o -name '*.orig' \) -type f -delete

# Every file listed in the TOC must be in the package. WoW on Windows is
# case-insensitive, so compare lower-cased paths.
FILE_LIST="$(cd "$STAGE/$ADDON" && find . -type f | sed 's|^\./||' | tr '[:upper:]' '[:lower:]')"
missing=0
while IFS= read -r line || [ -n "$line" ]; do
  line="${line%$'\r'}"
  line="$(printf '%s' "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  case "$line" in
    "" | "#"*) continue ;;
  esac
  path="$(printf '%s' "$line" | tr '\\' '/' | tr '[:upper:]' '[:lower:]')"
  if ! grep -Fxq -- "$path" <<<"$FILE_LIST"; then
    echo "error: $TOC references a file that is not in the package: $line" >&2
    missing=1
  fi
done < "$STAGE/$ADDON/$TOC"
if [ "$missing" -ne 0 ]; then
  exit 1
fi

(cd "$STAGE" && zip -q -r -9 -X "$OUT" "$ADDON")
rm -rf "$STAGE"

echo "Packaged $OUT"
if [ -n "${GITHUB_OUTPUT:-}" ]; then
  {
    echo "zip_path=$OUT"
    echo "zip_name=$ZIP_NAME"
  } >> "$GITHUB_OUTPUT"
fi
