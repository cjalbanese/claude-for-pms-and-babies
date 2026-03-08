#!/bin/bash
# Claude Code for PMs and Babies — installer
# Usage: curl -fsSL https://raw.githubusercontent.com/cjalbanese/claude-for-pms-and-babies/main/install.sh | bash

set -e

HOOK_DIR="$HOME/.claude/hooks"
SETTINGS_FILE="$HOME/.claude/settings.json"
BASE_URL="https://raw.githubusercontent.com/cjalbanese/claude-for-pms-and-babies/main"

echo "Installing Claude Code for PMs and Babies..."

mkdir -p "$HOOK_DIR"
mkdir -p "$HOME/.claude-for-pms"

# Download
curl -fsSL "$BASE_URL/hooks-handlers/explain.sh" -o "$HOOK_DIR/explain-for-pms.sh"
chmod +x "$HOOK_DIR/explain-for-pms.sh"

# Check jq
if ! command -v jq &> /dev/null; then
  echo "Error: jq is required. brew install jq / apt install jq"
  exit 1
fi

# Setup settings.json
if [ ! -f "$SETTINGS_FILE" ]; then
  echo "{}" > "$SETTINGS_FILE"
fi

HOOK_ENTRY='{"hooks": [{"type": "command", "command": "$HOME/.claude/hooks/explain-for-pms.sh", "timeout": 10}]}'

for EVENT in PostToolUse PostToolUseFailure Stop; do
  HAS=$(jq -r ".hooks.${EVENT} // empty" "$SETTINGS_FILE")
  if [ -z "$HAS" ]; then
    jq --argjson hook "$HOOK_ENTRY" ".hooks.${EVENT} = [\$hook]" "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp"
    mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
  else
    ALREADY=$(jq -r ".hooks.${EVENT}[] | .hooks[]? | select(.command | contains(\"explain-for-pms\"))" "$SETTINGS_FILE")
    if [ -z "$ALREADY" ]; then
      jq --argjson hook "$HOOK_ENTRY" ".hooks.${EVENT} += [\$hook]" "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp"
      mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
    fi
  fi
done

echo ""
echo "Installed! Start a new Claude Code session."
echo ""
echo "  State: ~/.claude-for-pms/state.json"
echo ""
echo "To uninstall: bash <(curl -fsSL $BASE_URL/uninstall.sh)"
