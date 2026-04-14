#!/usr/bin/env bash
# SessionStart hook for the session-tab-namer skill.
#
# Reads the hook input JSON from stdin, pulls session_id, and sets a
# fallback terminal tab name like "claude:a3f2c1" using the first 6 chars
# of the session ID. Writes the OSC 0 escape directly to /dev/tty so it
# bypasses Claude Code's stdout capture and actually reaches the terminal.
#
# Emits additionalContext back to Claude so the model knows the fallback
# is in place and should replace it with a semantic name once the user's
# objective is clear.

set -euo pipefail

input="$(cat)"

# Extract session_id — prefer jq, fall back to sed if jq is not installed.
if command -v jq >/dev/null 2>&1; then
  session_id="$(printf '%s' "$input" | jq -r '.session_id // "unknown"')"
else
  session_id="$(printf '%s' "$input" | sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
  [[ -z "$session_id" ]] && session_id="unknown"
fi

# If we couldn't get a real session_id, use plain "claude" rather than
# an ugly stub like "claude:unknow" or "claude:".
if [[ -z "$session_id" || "$session_id" == "unknown" ]]; then
  tab_name="claude"
else
  tab_name="claude:${session_id:0:6}"
fi

# Rename the tab. /dev/tty bypasses the hook's captured stdout and
# reaches the actual terminal emulator. Group redirect so a failing
# `> /dev/tty` open (e.g. no controlling terminal) doesn't leak
# "Device not configured" onto stderr.
{ printf '\033]0;%s\007' "$tab_name" > /dev/tty; } 2>/dev/null || true

# Emit the JSON envelope back to Claude. Use jq to build it when
# available so tab_name is properly escaped; otherwise fall back to a
# heredoc (session_id from Claude Code should be a uuid, so embedding
# it in JSON is safe in practice).
context_msg="Terminal tab was auto-named '${tab_name}' by the session-tab-namer skill. Invoke that skill to replace the fallback with a semantic name like 'build:<thing>' or 'research:<topic>' as soon as the user's objective is clear."

if command -v jq >/dev/null 2>&1; then
  jq -n --arg msg "$context_msg" '{
    hookSpecificOutput: {
      hookEventName: "SessionStart",
      additionalContext: $msg
    }
  }'
else
  cat <<EOF
{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"${context_msg}"}}
EOF
fi
