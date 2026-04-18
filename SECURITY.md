# Security Policy

## Supported versions

The skill is a small set of shell scripts and a skill body. Security fixes are applied to `main` and backported to the most recent release tag. Older tags are not maintained.

## Threat model

This skill runs locally on a developer machine. Its privileges are the user's own. There is no network component, no persistent daemon, and no telemetry. The relevant blast radius is:

- **`install.sh` / `uninstall.sh`** — edit `~/.claude/settings.json` via `jq`. A bug here could corrupt settings or introduce an unintended hook.
- **`session_start_hook.sh`** — runs on every Claude Code session start. A bug here could misbehave on session open but cannot escalate privileges beyond the user.
- **Tab-name content** — the tab name is a string written via OSC 0 to the user's own terminal. In principle, a maliciously-crafted name could include terminal control sequences (the "terminal escape injection" class of bug). The skill only writes names in the `<prefix>:<kebab-description>` format emitted by Claude, and the hook only writes `claude:<hex-session-id>`, so the exposure is limited to content Claude generates — but see "Reporting" below if you find a way to inject arbitrary bytes.

What this skill explicitly does NOT do:

- No network calls (no curl, no wget, no package fetches at runtime)
- No reading of secrets, tokens, SSH keys, or credential stores
- No writing outside `~/.claude/` and `~/.claude/session-names/`
- No `eval` of untrusted input
- No privileged operations (no `sudo`, no `chmod` beyond the hook script itself)

## Reporting a vulnerability

Please report security issues **privately**, not as public GitHub issues.

Preferred channels (in order):

1. GitHub's private vulnerability reporting: open an advisory at <https://github.com/mathewtbenjamin/session-tab-namer/security/advisories/new>
2. Email the maintainer at the address listed on <https://github.com/mathewtbenjamin>

Please include:

- A minimal reproducer (shell commands, environment, terminal emulator)
- The specific script and line number(s) involved if you can identify them
- Your assessment of impact (what an attacker could cause, under what preconditions)

## Response expectations

This is a personal open-source project maintained in spare time. Realistic expectations:

- Acknowledgement of the report within 7 days
- Triage and a judgement call ("confirmed bug", "working as designed", "not reproducible") within 14 days
- If a fix is warranted, a patched release within 30 days for confirmed issues

If a reported issue materially increases the skill's blast radius (e.g., a path-traversal in the installer that could overwrite arbitrary files), it will be prioritized and the response timeline compressed.

## Disclosure

Coordinated disclosure is preferred. Once a fix is shipped and tagged, the reporter is welcome to publish a writeup; the maintainer will link to it from the release notes if the reporter provides a URL.
