#!/usr/bin/env bash
# Uninstaller for the session-tab-namer SessionStart hook.
#
# Removes the hook entry from ~/.claude/settings.json. Keeps a
# timestamped backup. Idempotent: running it when no entry is present
# is a no-op that exits cleanly. Does not delete the skill files
# themselves — remove ~/.claude/skills/session-tab-namer/ by hand if
# you also want to uninstall the skill.

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK_PATH="${SKILL_DIR}/scripts/session_start_hook.sh"
SETTINGS="${HOME}/.claude/settings.json"

if [[ ! -f "$SETTINGS" ]]; then
  echo "No settings.json at $SETTINGS — nothing to uninstall."
  exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq is required to safely edit settings.json." >&2
  exit 1
fi

if ! jq empty "$SETTINGS" >/dev/null 2>&1; then
  echo "Error: $SETTINGS is not valid JSON. Refusing to edit." >&2
  exit 1
fi

# Check whether our hook is even present before touching anything.
if ! jq -e --arg cmd "$HOOK_PATH" '
  (.hooks.SessionStart // [])
  | map(.hooks // [] | map(.command))
  | flatten
  | index($cmd)
' "$SETTINGS" >/dev/null 2>&1; then
  echo "session-tab-namer hook not found in $SETTINGS — nothing to do."
  exit 0
fi

backup="${SETTINGS}.bak.$(date +%s)"
cp "$SETTINGS" "$backup"

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

# Remove any SessionStart entries referencing our hook. If the
# SessionStart array ends up empty, drop it entirely to keep the
# settings file tidy.
jq --arg cmd "$HOOK_PATH" '
  if .hooks.SessionStart then
    .hooks.SessionStart |= map(
      select((.hooks // [] | map(.command) | index($cmd)) == null)
    )
    | if (.hooks.SessionStart | length) == 0
      then del(.hooks.SessionStart)
      else .
    end
  else . end
  | if (.hooks // {}) == {} then del(.hooks) else . end
' "$SETTINGS" > "$tmp"

if ! jq empty "$tmp" >/dev/null 2>&1; then
  echo "Error: edited settings.json is not valid JSON. Aborting." >&2
  echo "Original file is unchanged. Backup at $backup" >&2
  exit 1
fi

mv "$tmp" "$SETTINGS"
trap - EXIT

echo "Uninstalled session-tab-namer SessionStart hook."
echo "  Settings: $SETTINGS"
echo "  Backup:   $backup"
echo
echo "The skill files at $SKILL_DIR are still in place — remove them by hand if you want to fully uninstall."
