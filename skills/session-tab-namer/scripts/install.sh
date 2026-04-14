#!/usr/bin/env bash
# Installer for the session-tab-namer SessionStart hook.
#
# Registers scripts/session_start_hook.sh in ~/.claude/settings.json
# under hooks.SessionStart. Idempotent: running it twice will not
# duplicate the entry. Keeps a timestamped backup of settings.json
# before editing and validates the edited file parses as JSON before
# replacing the original.

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK_PATH="${SKILL_DIR}/scripts/session_start_hook.sh"
SETTINGS="${HOME}/.claude/settings.json"

if [[ ! -f "$HOOK_PATH" ]]; then
  echo "Error: hook script not found at $HOOK_PATH" >&2
  exit 1
fi

chmod +x "$HOOK_PATH"

if ! command -v jq >/dev/null 2>&1; then
  cat >&2 <<'MSG'
Error: jq is required to safely edit settings.json.
Install with:   brew install jq     (macOS)
            or: apt-get install jq  (Debian/Ubuntu)
Then re-run this installer.
MSG
  exit 1
fi

mkdir -p "$(dirname "$SETTINGS")"
[[ -f "$SETTINGS" ]] || echo '{}' > "$SETTINGS"

# Guard: settings.json must parse as JSON before we touch it. If it
# doesn't, we refuse to proceed rather than clobber a hand-edited file.
if ! jq empty "$SETTINGS" >/dev/null 2>&1; then
  echo "Error: $SETTINGS is not valid JSON. Refusing to edit." >&2
  echo "Fix the file by hand, then re-run this installer." >&2
  exit 1
fi

backup="${SETTINGS}.bak.$(date +%s)"
cp "$SETTINGS" "$backup"

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

jq --arg cmd "$HOOK_PATH" '
  .hooks = (.hooks // {})
  | .hooks.SessionStart = (
      ((.hooks.SessionStart // [])
       | map(select((.hooks // [] | map(.command) | index($cmd)) == null)))
      + [{
          "matcher": "",
          "hooks": [{"type": "command", "command": $cmd}]
        }]
    )
' "$SETTINGS" > "$tmp"

# Guard: verify the edited file is still valid JSON before replacing.
# If jq somehow produced garbage, fail loud instead of clobbering.
if ! jq empty "$tmp" >/dev/null 2>&1; then
  echo "Error: edited settings.json is not valid JSON. Aborting." >&2
  echo "Original file is unchanged at $SETTINGS" >&2
  echo "Backup is at $backup" >&2
  exit 1
fi

mv "$tmp" "$SETTINGS"
trap - EXIT

echo "Installed session-tab-namer SessionStart hook."
echo "  Hook:     $HOOK_PATH"
echo "  Settings: $SETTINGS"
echo "  Backup:   $backup"
echo
echo "Open a new Claude Code session to see a fallback tab name like 'claude:a3f2c1'."
echo "To uninstall, run: bash $SKILL_DIR/scripts/uninstall.sh"
