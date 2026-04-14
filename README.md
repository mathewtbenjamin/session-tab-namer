# session-tab-namer

A [Claude Code](https://claude.com/claude-code) skill + `SessionStart` hook that auto-names your terminal tab for every Claude session, based on what the session is actually for.

Instead of staring at a row of identical `claude` tabs wondering which is which, you get tabs like:

```
build:embabel-multi-agent    research:jwt-rotation    debug:pytest-flaky    write:cortex-q2-prd
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

## Install

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

A formal eval with three real prompts (build a multi-agent app, research JWT rotation, debug a flaky pytest suite) compared the skill against a no-skill baseline:

| Metric     | With skill  | Without skill | Delta  |
| ---------- | ----------- | ------------- | ------ |
| Pass rate  | 100% (21/21)| 48% (10/21)   | +52 pp |
| Time       | 28.0s       | 19.8s         | +8.2s  |
| Tokens     | 20,657      | 17,398        | +3,259 |

The baseline frequently forgot to rename at all, or wrote to captured stdout so the rename silently failed. The skill makes renaming reliable and consistent at the cost of roughly +8s and +3k tokens per session — a once-per-session overhead that pays for itself the first time you need to find a specific tab.

## Repository layout

```
.
├── skills/
│   └── session-tab-namer/
│       ├── SKILL.md                      # skill body Claude reads
│       ├── scripts/
│       │   ├── session_start_hook.sh     # the hook
│       │   ├── install.sh                # registers hook in settings.json
│       │   └── uninstall.sh              # removes hook from settings.json
│       └── evals/
│           └── evals.json                # three benchmark prompts
├── docs/
│   ├── FIELD_NOTES.md                    # what we learned building this
│   └── BLOG.md                           # narrative writeup
├── Makefile                              # install / uninstall / test targets
└── README.md
```

## Troubleshooting

- **Tab didn't rename.** Check you're on a real TTY: `[ -t 0 ] && echo tty`. The hook silently no-ops on non-interactive shells.
- **Using tmux and nothing changes.** Add to `~/.tmux.conf`:
  ```
  set-option -g allow-rename on
  set-option -g set-titles on
  ```
- **Hook never fires.** Verify it's registered: `jq '.hooks.SessionStart' ~/.claude/settings.json`. Re-run `make install` if empty.
- **`jq: command not found`.** Install jq: `brew install jq` or `apt-get install jq`.

## License

MIT. See [LICENSE](LICENSE).

## Credits

Built by [@mathewtbenjamin](https://github.com/mathewtbenjamin) with Claude Code. If this is useful to you and you improve it, PRs welcome.
