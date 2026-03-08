#!/bin/bash
set -e

SETTINGS_FILE="$HOME/.claude/settings.json"

echo "Uninstalling Claude Code for PMs and Babies..."

rm -f "$HOME/.claude/hooks/explain-for-pms.sh"

if [ -f "$SETTINGS_FILE" ]; then
  for EVENT in PostToolUse PostToolUseFailure Stop; do
    jq ".hooks.${EVENT} = [.hooks.${EVENT}[]? | select(.hooks[]?.command | contains(\"explain-for-pms\") | not)]" "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp"
    mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"

    REMAINING=$(jq ".hooks.${EVENT} | length" "$SETTINGS_FILE")
    if [ "$REMAINING" = "0" ]; then
      jq "del(.hooks.${EVENT})" "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp"
      mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
    fi
  done

  HOOK_KEYS=$(jq '.hooks | keys | length' "$SETTINGS_FILE" 2>/dev/null || echo "0")
  if [ "$HOOK_KEYS" = "0" ]; then
    jq 'del(.hooks)' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp"
    mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
  fi
fi

echo "Uninstalled. State preserved at ~/.claude-for-pms/ — rm -rf to remove."
