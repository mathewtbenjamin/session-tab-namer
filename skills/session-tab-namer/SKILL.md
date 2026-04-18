---
name: session-tab-namer
description: Auto-names the terminal tab for every Claude Code session based on the task's intent — for example "build:embabel-multi-agent", "research:jwt-rotation", or "debug:pytest-flaky". Use this skill whenever a new Claude Code session starts, whenever the user states or changes their objective, whenever the user asks to rename/relabel the tab, and proactively early in any session that still has a fallback name like "claude:a3f2c1". A well-named tab makes it easy to track, identify, and resume working sessions across many open terminals (cmux, iTerm2, Terminal.app, tmux, WezTerm).
---

# Session Tab Namer

Keep every Claude Code session's terminal tab labeled by *what the session is actually for*, so the user can glance at a row of tabs and know which one is their multi-agent build, which is a research dive, which is a quick bug-chase.

## How tab naming works

Every mainstream terminal emulator (Terminal.app, iTerm2, cmux, tmux, Alacritty, WezTerm, kitty, GNOME Terminal) honors the **OSC 0 escape sequence** for setting window/tab titles:

```
printf '\033]0;YOUR TITLE HERE\007' > /dev/tty
```

- `\033]0;` — OSC "set icon name + window title"
- `\007` — BEL, the string terminator
- `> /dev/tty` — writes directly to the controlling terminal, bypassing anything that might capture stdout

You run this from the Bash tool. That's the whole mechanism — no terminal-specific APIs, no per-emulator branching.

Important: do **not** print the escape sequence into normal tool stdout. Claude Code captures Bash output for the model's context, so it won't reach the terminal's window manager and the tab will not actually rename. The `> /dev/tty` redirect is load-bearing.

## When to set the tab name

1. **On session start** — a `SessionStart` hook (shipped in `scripts/session_start_hook.sh`) gives every new tab an immediate fallback name like `claude:a3f2c1`, using the first 6 characters of the Claude Code session ID. That guarantees the tab always has *some* name from the instant the session opens, before the user has even typed anything.

2. **Once the objective is clear** — replace the fallback with a semantic name as soon as the user states what they want to do. Don't wait to be asked. The value of this skill is that naming happens automatically. If the first user message is "help me set up a multi-agent flow in embabel", rename the tab before or alongside starting the work.

3. **On explicit request** — "rename the tab", "relabel this session", "call this one X", "change the tab to Y" → rename immediately, no debate.

4. **When the objective shifts meaningfully** — if what began as `research:jwt-libraries` clearly turned into `build:jwt-rotation-service`, rename. Don't churn the name on every micro-pivot; rename when the headline changes.

## Naming format

`<prefix>:<short-kebab-description>`

**Prefix** — pick the single short word that best captures the session's dominant activity. There is no fixed list. Words that come up naturally: `research`, `build`, `debug`, `plan`, `review`, `refactor`, `ops`, `write`, `test`, `explore`, `deploy`, `spike`. Pick whatever fits; the goal is a label the user recognizes at a glance, not taxonomic purity. If two prefixes fit, choose the one describing the *outcome* the user wants, not the activity they're currently doing (e.g. prefer `build:` over `research:` when the research is in service of a build).

**Description** — 2–4 words, lowercase, kebab-case, concrete enough to disambiguate from other tabs the user might have open. Prefer proper nouns (project names, ticket IDs, library names) over generic phrases.

**Length** — aim for ~30 characters total. Most terminals truncate tab titles aggressively; the first 15–20 characters are what the user actually sees.

### Examples

| Objective stated by user | Good tab name | Why |
|---|---|---|
| "help me set up a multi-agent flow in embabel" | `build:embabel-multi-agent` | Project + what's being built |
| "figure out how JWT rotation works in practice" | `research:jwt-rotation` | Research prefix, concrete topic |
| "this pytest suite is flaking, help me find why" | `debug:pytest-flaky` | Debug prefix, specific symptom |
| "write the Q2 PRD for the payments service" | `write:payments-q2-prd` | Project + artifact |
| "review the auth middleware PR" | `review:auth-middleware-pr` | Review prefix, object |
| (no objective yet, fresh session) | `claude:a3f2c1` | Fallback from hook, session-id based |

### Anti-examples

- `build:stuff` — too generic, indistinguishable from other tabs
- `BUILD:Embabel_Multi_Agent_System` — caps and underscores waste visual space
- `building-a-multi-agent-system-in-embabel-for-the-payments-project` — truncates to garbage
- `session-12` — not semantic; the hook's fallback is already better

## How to rename the tab

Single Bash command:

```bash
printf '\033]0;build:embabel-multi-agent\007' > /dev/tty
```

No confirmation needed — renaming is free and reversible, and the user is expecting it. After renaming, briefly tell the user in one line what the tab is now called, e.g.:

> Named this tab `build:embabel-multi-agent` — just ask if you'd like it changed.

## Edge cases

- **tmux / screen** — OSC 0 still works, but tmux's own status bar may override it. If the rename doesn't stick, tell the user the sequence was sent but tmux is probably overriding, and suggest `set-option -g allow-rename on` and `set-option -g set-titles on` in `.tmux.conf`. Don't silently fail.
- **SSH sessions** — works transparently; the escape travels over the SSH stream to the local terminal.
- **Non-interactive / piped sessions** — `/dev/tty` may not exist. The rename command will fail harmlessly with a non-zero exit; don't retry, just skip.
- **User objects to the name** — just rename to whatever they want. Don't debate taxonomy.
- **Already-semantic name present** — if the tab is already named something like `build:xyz` (not the fallback pattern `claude:xxxxxx`), don't rename on your own initiative. Only rename on explicit request or genuine objective shift.

## Installing the SessionStart hook

The hook in `scripts/session_start_hook.sh` is what gives every new session a fallback name *before* the user says anything. It needs to be registered in `~/.claude/settings.json` under `hooks.SessionStart`.

On first use of this skill on a new machine, check whether the hook is installed:

```bash
grep -q 'session_start_hook.sh' ~/.claude/settings.json 2>/dev/null && echo installed || echo missing
```

If missing, ask the user:

> I can install a `SessionStart` hook that gives every new Claude Code tab a fallback name like `claude:a3f2c1` the instant it opens, before you've even said what the session is for. The installer edits `~/.claude/settings.json` with `jq` and keeps a timestamped backup. Want me to wire it up?

On approval, run:

```bash
bash scripts/install.sh
```

This is a one-time install per machine. The installer is idempotent — running it twice won't duplicate the hook entry.
