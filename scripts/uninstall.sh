#!/bin/zsh
set -euo pipefail

PET_ID="${CODEX_PET_ID:-}"
if [[ -z "$PET_ID" ]]; then
  echo "Set CODEX_PET_ID to your installed Codex pet folder name." >&2
  echo "Example: CODEX_PET_ID=your-pet-name ./scripts/uninstall.sh" >&2
  exit 1
fi
HOST_LABEL="com.codex-pet.usage-bubble.$PET_ID.host"
SYNC_LABEL="com.codex-pet.usage-bubble.$PET_ID.sync"
LAUNCH_DIR="$HOME/Library/LaunchAgents"

launchctl bootout "gui/$(id -u)" "$LAUNCH_DIR/$HOST_LABEL.plist" >/dev/null 2>&1 || true
launchctl bootout "gui/$(id -u)" "$LAUNCH_DIR/$SYNC_LABEL.plist" >/dev/null 2>&1 || true
rm -f "$LAUNCH_DIR/$HOST_LABEL.plist" "$LAUNCH_DIR/$SYNC_LABEL.plist"

echo "Uninstalled launch agents for pet id: $PET_ID"
