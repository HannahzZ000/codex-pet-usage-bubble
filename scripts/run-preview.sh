#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PET_ID="${CODEX_PET_ID:-}"
if [[ -z "$PET_ID" ]]; then
  echo "Set CODEX_PET_ID to your installed Codex pet folder name." >&2
  echo "Example: CODEX_PET_ID=your-pet-name ./scripts/run-preview.sh" >&2
  exit 1
fi
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
INSTALL_DIR="$CODEX_HOME/pets/$PET_ID/usage-overlay"

mkdir -p "$ROOT/.swift-module-cache" "$INSTALL_DIR/assets"
cp "$ROOT"/assets/*.png "$INSTALL_DIR/assets"/

CLANG_MODULE_CACHE_PATH="$ROOT/.swift-module-cache" swiftc \
  "$ROOT/Sources/UsageBubbleHost.swift" \
  -o "$ROOT/.UsageBubbleHost"

CODEX_PET_ID="$PET_ID" \
CODEX_HOME="$CODEX_HOME" \
USAGE_BUBBLE_OVERLAY_DIR="$INSTALL_DIR" \
"$ROOT/.UsageBubbleHost" --always-show
