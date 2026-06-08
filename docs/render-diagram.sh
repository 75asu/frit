#!/usr/bin/env bash
# Render the frit architecture diagram to dark + light PNGs from ONE source.
#
# Source of truth: docs/architecture.drawio  (dark-themed, edit this).
# The light variant is derived by a color swap (no second file to maintain),
# then both are exported via the draw.io desktop CLI.
#
# Usage:  ./render-diagram.sh        (or `make diagram` from the repo root)
# Re-run any time the architecture changes; commit the updated PNGs.
set -euo pipefail
cd "$(dirname "$0")"

DRAWIO="${DRAWIO_BIN:-/Applications/draw.io.app/Contents/MacOS/draw.io}"
SCALE="${SCALE:-2}"
SRC="architecture.drawio"

[ -x "$DRAWIO" ] || { echo "draw.io CLI not found at $DRAWIO (set DRAWIO_BIN, or: brew install --cask drawio)"; exit 1; }

echo "==> dark  -> architecture-dark.png"
"$DRAWIO" -x -f png -t -s "$SCALE" --no-sandbox -o architecture-dark.png "$SRC" 2>/dev/null

echo "==> light -> architecture-light.png (derived from the dark source)"
LIGHT="$(mktemp -t frit-arch-light).drawio"
sed -E \
  -e 's/fillColor=#13161c/fillColor=#dae8fc/g' \
  -e 's/fillColor=#161616/fillColor=#f5f5f5/g' \
  -e 's/fillColor=#181320/fillColor=#e1d5e7/g' \
  -e 's/fillColor=#1e1810/fillColor=#ffe6cc/g' \
  -e 's/fillColor=#1e1c10/fillColor=#fff2cc/g' \
  -e 's/fillColor=#201313/fillColor=#f8cecc/g' \
  -e 's/fillColor=#2a1a10/fillColor=#ffe0cf/g' \
  -e 's/fontColor=#7d97c2/fontColor=#4f6f9f/g' \
  -e 's/fontColor=#8088a0/fontColor=#5a627a/g' \
  -e 's/fontColor=#8a8a8a/fontColor=#777777/g' \
  -e 's/fontColor=#999999/fontColor=#777777/g' \
  -e 's/fontColor=#9f82b3/fontColor=#7a5e8e/g' \
  -e 's/fontColor=#b5a45f/fontColor=#9a7d1a/g' \
  -e 's/fontColor=#b98a2a/fontColor=#a9760a/g' \
  -e 's/fontColor=#bcd0ec/fontColor=#1f3a5f/g' \
  -e 's/fontColor=#c8c8c8/fontColor=#333333/g' \
  -e 's/fontColor=#d2bfe2/fontColor=#4a2c66/g' \
  -e 's/fontColor=#e0a89f/fontColor=#6e2420/g' \
  -e 's/fontColor=#e6cf9c/fontColor=#6e5200/g' \
  -e 's/fontColor=#e6dba0/fontColor=#5f5400/g' \
  -e 's/fontColor=#ffd9c2/fontColor=#7a3410/g' \
  -e 's/strokeColor=#4f6f9f/strokeColor=#6c8ebf/g' \
  -e 's/strokeColor=#555555/strokeColor=#999999/g' \
  -e 's/strokeColor=#5a627a/strokeColor=#9aa5c4/g' \
  -e 's/strokeColor=#6f6f6f/strokeColor=#999999/g' \
  -e 's/strokeColor=#9aa6bf/strokeColor=#6c8ebf/g' \
  -e 's/strokeColor=#a9760a/strokeColor=#d79b00/g' \
  "$SRC" > "$LIGHT"
"$DRAWIO" -x -f png -t -s "$SCALE" --no-sandbox -o architecture-light.png "$LIGHT" 2>/dev/null
rm -f "$LIGHT"

echo "done: docs/architecture-dark.png + docs/architecture-light.png"
