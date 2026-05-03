# session-tab-namer

A [Claude Code](https://claude.com/claude-code) skill + `SessionStart` hook that auto-names your terminal tab for every Claude session, based on what the session is actually for.

Instead of staring at a row of identical `claude` tabs wondering which is which, you get tabs like:

```
build:embabel-multi-agent    research:jwt-rotation    debug:pytest-flaky    write:payments-q2-prd
```

Works in iTerm2, Terminal.app, cmux, WezTerm, kitty, Alacritty, GNOME Terminal, and tmux (with `allow-rename on`).

## How it works

Two pieces cooperate:

1. **`SessionStart` hook** (`skills/session-tab-namer/scripts/session_start_hook.sh`) fires the instant a new Claude Code session opens and sets a fallback name like `claude:a3f2c1` using the first 6 chars of the session ID. Your tab is never nameless.
2. **Skill** (`skills/session-tab-namer/SKILL.md`) tells Claude to replace the fallback with a semantic name (`build:*`, `research:*`, `debug:*`, ...) as soon as your objective is clear — without you having to ask.

Renaming uses the universal `OSC 0` escape sequence:

```bash
printf '\033]0;build:embabel-multi-agent\007' > /dev/tty
```

The `> /dev/tty` redirect is load-bearing: Claude Code captures Bash stdout, so without it the escape never reaches the terminal's window manager.

Tab names are also persisted to `~/.claude/session-names/<session-id>` so other tools and hooks can read the current session's name.

## Install

### Option A: Claude Code plugin (recommended)

```bash
claude plugin marketplace add mathewtbenjamin/session-tab-namer
claude plugin install session-tab-namer@session-tab-namer
```

Then register the SessionStart hook (requires `jq`):

```bash
bash ~/.claude/plugins/cache/session-tab-namer/session-tab-namer/*/skills/session-tab-namer/scripts/install.sh
```

### Option B: Manual install

Requires `jq` (`brew install jq` / `apt-get install jq`).

```bash
git clone https://github.com/mathewtbenjamin/session-tab-namer.git
cd session-tab-namer
make install
```

That will:

1. Copy `skills/session-tab-namer/` into `~/.claude/skills/session-tab-namer/`.
2. Register the `SessionStart` hook in `~/.claude/settings.json` (idempotent, keeps a timestamped backup).

Open a new Claude Code session. The tab should immediately read `claude:<6-char-id>`. Tell Claude what you're working on and the tab will rebrand itself to something like `build:embabel-multi-agent`.

## Uninstall

### Plugin install

Remove the hook from `settings.json` first, then uninstall:

```bash
bash ~/.claude/plugins/cache/session-tab-namer/session-tab-namer/*/skills/session-tab-namer/scripts/uninstall.sh
claude plugin uninstall session-tab-namer@session-tab-namer
claude plugin marketplace remove session-tab-namer
```

### Manual install

```bash
make uninstall
```

Removes the hook entry from `~/.claude/settings.json` (backed up first). The skill files under `~/.claude/skills/session-tab-namer/` stay put — delete that directory by hand if you want a clean slate.

## Naming convention

`<prefix>:<short-kebab-description>` — aim for ~30 characters.

| Prefix     | When                                                                  |
| ---------- | --------------------------------------------------------------------- |
| `build:`   | Shipping a feature, system, or artifact                               |
| `research:`| Reading, comparing, understanding — output is knowledge, not code     |
| `debug:`   | Chasing a specific bug or failure                                     |
| `review:`  | Reading a PR, diff, or doc for feedback                               |
| `refactor:`| Reshaping existing code without changing behavior                     |
| `plan:`    | Designing an approach before touching code                            |
| `write:`   | Prose artifacts — PRDs, docs, posts                                   |
| `ops:`     | Deploys, infra, secrets, one-off admin                                |
| `spike:`   | Throwaway exploration, proof-of-concept                               |

The skill deliberately doesn't hard-code this list — Claude picks whatever single short word best describes the session's dominant activity.

## Benchmark

3 core prompts (build, research, debug) benchmarked with-skill vs without-skill baselines (3 prompts × 3 runs × 7 checks = 21 assertions per arm). 5 additional edge-case prompts (vague prompts, explicit renames, objective shifts, multi-objective sessions, non-code work) are documented in `skills/session-tab-namer/evals/evals.json` for future runs.

| Metric     | With skill            | Without skill         | Delta  |
| ---------- | --------------------- | --------------------- | ------ |
| Pass rate  | 100% (21/21 asserts)  | 48% (10/21 asserts)   | +52 pp |
| Time       | 28.0s                 | 19.8s                 | +8.2s  |
| Tokens     | 20,657                | 17,398                | +3,259 |

The baseline frequently forgot to rename at all, or wrote to captured stdout so the rename silently failed. The skill makes renaming reliable and consistent at the cost of roughly +8s and +3k tokens per session — a once-per-session overhead that pays for itself the first time you need to find a specific tab.

## Repository layout

```
.
├── .claude-plugin/
│   ├── plugin.json                       # plugin manifest for marketplace
│   └── marketplace.json                  # marketplace manifest
├── skills/
│   └── session-tab-namer/
│       ├── SKILL.md                      # skill body Claude reads
│       ├── scripts/
│       │   ├── session_start_hook.sh     # the hook
│       │   ├── install.sh                # registers hook in settings.json
│       │   └── uninstall.sh              # removes hook from settings.json
│       └── evals/
│           └── evals.json                # eight benchmark prompts
├── docs/
│   └── FIELD_NOTES.md                    # what we learned building this
├── tests/
│   └── install_test.sh                   # integration test for install.sh
├── demo.tape                             # VHS recording script for demo GIF
├── CONTRIBUTING.md                       # how to contribute
├── SECURITY.md                           # security policy
├── Makefile                              # install / uninstall / test targets
└── README.md
```

## Troubleshooting

- **Tab didn't rename.** Check your shell has access to a controlling TTY: `[ -c /dev/tty ] && echo tty`. (`[ -t 0 ]` only tests whether stdin is a TTY, which isn't the same thing — OSC 0 needs `/dev/tty`.) The hook silently no-ops when `/dev/tty` isn't writable, as happens in some non-interactive or captured-IO contexts.
- **Using tmux and nothing changes.** Add to `~/.tmux.conf`:
  ```
  set-option -g allow-rename on
  set-option -g set-titles on
  ```
- **Hook never fires.** Verify it's registered: `jq '.hooks.SessionStart' ~/.claude/settings.json`. Re-run `make install` if empty.
- **`jq: command not found`.** Install jq: `brew install jq` or `apt-get install jq`.

## FAQ

**Does this work over SSH?**
Yes. OSC 0 is a terminal-emulator escape sequence, so it travels over SSH transparently and is interpreted by whichever terminal you opened the SSH session from.

**Does this work in tmux?**
Yes, but tmux captures window titles by default. Add `set-option -g allow-rename on` and `set-option -g set-titles on` to `~/.tmux.conf`. Without those, the escape is silently dropped by tmux.

**Why does the skill use a SessionStart fallback instead of waiting for a real name?**
If the session starts nameless, there's a window where you can't distinguish tabs. The 6-char session ID fallback (`claude:a3f2c1`) gives every tab *some* identity from the instant it opens. The skill replaces it with a semantic name as soon as your objective is clear.

**Is tab-renaming visible to the model?**
No. The OSC 0 escape is written to `/dev/tty`, not stdout. Claude Code captures stdout for the model's context, which is exactly why the `> /dev/tty` redirect is load-bearing — without it, the escape never reaches the terminal.

**Will this change the shell prompt or any other state?**
No. OSC 0 only touches the window/tab title. The shell prompt, working directory, and environment are untouched.

**Does this collect any telemetry?**
No. The hook and skill are local-only. The only thing written outside your terminal is the timestamped backup of `~/.claude/settings.json` during install.

**Why OSC 0 instead of a terminal-specific API?**
OSC 0 is honored by every mainstream emulator (iTerm2, Terminal.app, Alacritty, WezTerm, kitty, GNOME Terminal) and by tmux with `allow-rename` on. Per-emulator APIs would fragment the skill and still not cover every case.

## License

MIT. See [LICENSE](LICENSE).

## Credits

Built by [@mathewtbenjamin](https://github.com/mathewtbenjamin) with Claude Code. If this is useful to you and you improve it, PRs welcome.
