#!/bin/bash
# One-line install + run:
#   curl -fsSL https://raw.githubusercontent.com/arctan2/divine-intervention/main/install.sh | bash
set -euo pipefail

ZIP_URL="${DI_ZIP_URL:-https://github.com/arctan2/divine-intervention/releases/latest/download/DivineIntervention.zip}"
DEST="$HOME/Applications"
TMP="$(mktemp -d)"

mkdir -p "$DEST"
curl -fsSL "$ZIP_URL" -o "$TMP/di.zip"
pkill -x DivineIntervention 2>/dev/null || true
rm -rf "$DEST/DivineIntervention.app"
ditto -x -k "$TMP/di.zip" "$DEST"
xattr -cr "$DEST/DivineIntervention.app" 2>/dev/null || true
rm -rf "$TMP"
open "$DEST/DivineIntervention.app"
