#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PET_ID="${CODEX_PET_ID:-}"
if [[ -z "$PET_ID" ]]; then
  echo "Set CODEX_PET_ID to your installed Codex pet folder name." >&2
  echo "Example: CODEX_PET_ID=your-pet-name ./scripts/install.sh" >&2
  exit 1
fi
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
INSTALL_DIR="$CODEX_HOME/pets/$PET_ID/usage-overlay"
BIN_DIR="$INSTALL_DIR/bin"
ASSET_DIR="$INSTALL_DIR/assets"
LAUNCH_DIR="$HOME/Library/LaunchAgents"
HOST_LABEL="com.codex-pet.usage-bubble.$PET_ID.host"
SYNC_LABEL="com.codex-pet.usage-bubble.$PET_ID.sync"
NODE_BIN="${NODE_BIN:-$(command -v node)}"

if [[ -z "$NODE_BIN" ]]; then
  echo "Could not find node. Install Node.js or set NODE_BIN=/path/to/node." >&2
  exit 1
fi

mkdir -p "$BIN_DIR" "$ASSET_DIR" "$LAUNCH_DIR" "$ROOT/.swift-module-cache"

cp "$ROOT"/assets/*.png "$ASSET_DIR"/
cp "$ROOT/scripts/sync-codex-usage.mjs" "$BIN_DIR/sync-codex-usage.mjs"
cp "$ROOT/scripts/set-percent.mjs" "$BIN_DIR/set-percent.mjs"

CLANG_MODULE_CACHE_PATH="$ROOT/.swift-module-cache" swiftc \
  "$ROOT/Sources/UsageBubbleHost.swift" \
  -o "$BIN_DIR/UsageBubbleHost"

cat > "$LAUNCH_DIR/$HOST_LABEL.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$HOST_LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>$BIN_DIR/UsageBubbleHost</string>
  </array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>CODEX_PET_ID</key><string>$PET_ID</string>
    <key>CODEX_HOME</key><string>$CODEX_HOME</string>
    <key>USAGE_BUBBLE_OVERLAY_DIR</key><string>$INSTALL_DIR</string>
  </dict>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>StandardOutPath</key><string>$INSTALL_DIR/host.out.log</string>
  <key>StandardErrorPath</key><string>$INSTALL_DIR/host.err.log</string>
</dict>
</plist>
PLIST

cat > "$LAUNCH_DIR/$SYNC_LABEL.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$SYNC_LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>$NODE_BIN</string>
    <string>$BIN_DIR/sync-codex-usage.mjs</string>
  </array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>CODEX_PET_ID</key><string>$PET_ID</string>
    <key>CODEX_HOME</key><string>$CODEX_HOME</string>
    <key>USAGE_BUBBLE_OVERLAY_DIR</key><string>$INSTALL_DIR</string>
  </dict>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>StandardOutPath</key><string>$INSTALL_DIR/sync.out.log</string>
  <key>StandardErrorPath</key><string>$INSTALL_DIR/sync.err.log</string>
</dict>
</plist>
PLIST

launchctl bootout "gui/$(id -u)" "$LAUNCH_DIR/$HOST_LABEL.plist" >/dev/null 2>&1 || true
launchctl bootout "gui/$(id -u)" "$LAUNCH_DIR/$SYNC_LABEL.plist" >/dev/null 2>&1 || true
launchctl bootstrap "gui/$(id -u)" "$LAUNCH_DIR/$HOST_LABEL.plist"
launchctl bootstrap "gui/$(id -u)" "$LAUNCH_DIR/$SYNC_LABEL.plist"

echo "Installed Codex pet usage bubble for pet id: $PET_ID"
echo "Overlay dir: $INSTALL_DIR"
