#!/usr/bin/env bash
# Integration test for skills/session-tab-namer/scripts/install.sh.
#
# Runs install.sh against a temporary HOME (so ~/.claude/settings.json is
# synthetic), then asserts:
#   1. hooks.SessionStart contains an entry whose command path matches our hook
#   2. A timestamped backup was created alongside the edited settings.json
#   3. Running the installer a second time does NOT duplicate the entry
#      (idempotency)
#   4. settings.json remains valid JSON after both runs
#
# Exits 0 on success, 1 on any assertion failure. Safe to run repeatedly:
# each invocation builds its own tmp HOME and tears it down at the end.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_SH="$REPO_ROOT/skills/session-tab-namer/scripts/install.sh"
UNINSTALL_SH="$REPO_ROOT/skills/session-tab-namer/scripts/uninstall.sh"

if [[ ! -x "$INSTALL_SH" ]]; then
  echo "FAIL: install.sh not executable at $INSTALL_SH" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "FAIL: jq is required to run this test" >&2
  exit 1
fi

tmp_home="$(mktemp -d)"
trap 'rm -rf "$tmp_home"' EXIT

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

pass() {
  echo "PASS: $1"
}

echo "### Test 1: fresh install registers the hook"
HOME="$tmp_home" bash "$INSTALL_SH" >/dev/null

settings="$tmp_home/.claude/settings.json"
[[ -f "$settings" ]] || fail "settings.json was not created at $settings"

jq empty "$settings" >/dev/null 2>&1 || fail "settings.json is not valid JSON after install"

hook_count="$(jq '[.hooks.SessionStart[]?.hooks[]? | select(.command | endswith("session_start_hook.sh"))] | length' "$settings")"
[[ "$hook_count" == "1" ]] || fail "expected 1 hook entry after first install, got $hook_count"
pass "fresh install registered exactly one hook entry"

echo "### Test 2: timestamped backup was created"
backup_count="$(find "$tmp_home/.claude" -maxdepth 1 -name 'settings.json.bak.*' -type f | wc -l | tr -d '[:space:]')"
[[ "$backup_count" -ge 1 ]] || fail "expected at least 1 timestamped backup, got $backup_count"
pass "timestamped backup exists ($backup_count file(s))"

echo "### Test 3: second install does not duplicate the hook (idempotent)"
sleep 1  # ensure a distinct timestamp for the second backup
HOME="$tmp_home" bash "$INSTALL_SH" >/dev/null

jq empty "$settings" >/dev/null 2>&1 || fail "settings.json is not valid JSON after second install"
hook_count_2="$(jq '[.hooks.SessionStart[]?.hooks[]? | select(.command | endswith("session_start_hook.sh"))] | length' "$settings")"
[[ "$hook_count_2" == "1" ]] || fail "expected 1 hook entry after second install, got $hook_count_2 (idempotency broken)"
pass "second install left exactly one hook entry (idempotent)"

echo "### Test 4: uninstaller removes the hook cleanly"
if [[ -x "$UNINSTALL_SH" ]]; then
  HOME="$tmp_home" bash "$UNINSTALL_SH" >/dev/null || fail "uninstall.sh exited non-zero"
  hook_count_3="$(jq '[.hooks.SessionStart[]?.hooks[]? | select(.command | endswith("session_start_hook.sh"))] | length' "$settings")"
  [[ "$hook_count_3" == "0" ]] || fail "expected 0 hook entries after uninstall, got $hook_count_3"
  jq empty "$settings" >/dev/null 2>&1 || fail "settings.json is not valid JSON after uninstall"
  pass "uninstaller removed the hook entry cleanly"
else
  echo "SKIP: uninstall.sh not executable; skipping test 4"
fi

echo
echo "All install-integration tests passed."
