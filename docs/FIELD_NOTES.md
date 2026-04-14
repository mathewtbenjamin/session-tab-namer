# Field Notes

## Purpose
This document is a live working journal for the project. It records instructions, actions, decisions, issues, troubleshooting, lessons learned, and usability observations relevant to future workflow and tooling improvements.

This is **not** the README, and it is **not** a polished retrospective. It is the raw record of how the work actually happened — kept specifically so that future retrospectives, performance reflections, and AI-workflow usability research have real source material to draw from.

## How to use
Append entries as work progresses. Keep notes operational and specific. Capture the ugly parts — dead ends, corrections, friction — because those are the most valuable parts for later review. Do not rewrite history; add new entries instead.

Boundary with README: if a sentence would fit equally well in the README, it belongs in the README. Field Notes captures the *story of getting there*, not the destination.

---

## Project context
- **Project:** session-tab-namer
- **Date opened:** 2026-04-14
- **Primary objective:** Ship a Claude Code skill + SessionStart hook that auto-names terminal tabs by task intent (`build:*`, `research:*`, `debug:*`, ...), packaged for public GitHub and eventual marketplace submission.
- **Repo status:** Public repo at github.com/mathewtbenjamin/session-tab-namer, scaffolded from a personal skill at `~/.claude/skills/session-tab-namer/`.
- **Owner:** Mathew Benjamin (@mathewtbenjamin)
- **Tooling snapshot:** Bash + jq for the hook/installer; Markdown-based skill; no runtime beyond Claude Code itself. Formal eval run via skill-creator harness.

---

## Entries

### Entry — 2026-04-14 — scaffold v1 + formal eval + ship to GitHub

**Session / phase:** Initial build through production packaging
**Agent / model / harness:** Claude Opus 4.6 via Claude Code

**Instructions received**
- Build a skill that auto-names Claude Code terminal tabs based on session intent.
- Format: `<prefix>:<task>`, e.g. `research:jwt-rotation`, `build:embabel-agent`.
- Trigger on session start; include session ID as fallback until objective is known.
- Bundle the hook and the skill together.
- Let Claude pick the prefix freely — no fixed vocabulary.
- Run a formal eval AND a live-test.
- Ship to GitHub: public repo, README, field notes, blog post, production-ready.

**Actions taken**
- Wrote `SKILL.md` describing when and how to rename (OSC 0 via `/dev/tty`), naming format, edge cases for tmux/SSH/non-interactive.
- Wrote `session_start_hook.sh` reading `session_id` from stdin, emitting `hookSpecificOutput.additionalContext` back to Claude, and writing the OSC escape to `/dev/tty` (the load-bearing bit).
- Wrote jq-based `install.sh` / `uninstall.sh` that edit `~/.claude/settings.json` idempotently with timestamped backups and validate JSON before and after edit.
- Ran a formal eval via skill-creator (3 prompts × with/without × 3 runs). With-skill 100% (21/21), without-skill 48% (10/21). +52pp delta at cost of +8.2s and +3.3k tokens per session.
- Installed the hook into real `~/.claude/settings.json` for live-test.
- Created public GitHub repo `mathewtbenjamin/session-tab-namer`, cloned to `~/Projects/session-tab-namer`.
- Copied skill into `skills/session-tab-namer/`, wrote production README, Makefile (`install` / `uninstall` / `test` / `clean`), `.gitignore`, `.editorconfig`, MIT LICENSE.

**Decisions made (and why)**
- **Use `> /dev/tty` for the OSC escape, not plain stdout.** Claude Code captures Bash stdout for the model's context; if the escape goes into captured stdout it never reaches the terminal's window manager. Verified by reproducing the failure case before fixing.
- **No fixed prefix vocabulary.** User asked for flexibility, and a closed taxonomy would only overfit to my current imagination. The skill lists common prefixes as examples and tells Claude to pick the single word that best fits the session's dominant activity.
- **Ship the hook alongside the skill, not as a separate plugin.** The skill is useless without the fallback name — users shouldn't have to install two things. The `install.sh` is a one-liner behind `make install`.
- **Emit `additionalContext` back to Claude from the hook.** Without this, the model has no idea the tab already has a fallback name and sometimes forgets to rename it. The envelope tells Claude explicitly "there's a fallback here, replace it when the objective is clear." This was the biggest single reliability win in the eval.
- **Validate JSON before *and* after editing `settings.json`.** `settings.json` may have been hand-edited; clobbering it on a jq error is unacceptable for a skill that edits global config. Two `jq empty` guards plus a timestamped backup plus a trap-cleaned tmp file.
- **Plain `claude` fallback when session_id is missing or empty.** First draft produced `claude:unknow` (truncated "unknown") which looked like a bug. Fixed to produce `claude` when the id is absent.

**Issues encountered**
- Initial hook leaked `/dev/tty: Device not configured` on stderr in non-TTY contexts because shell redirection errors fire before the command's own stderr redirect takes effect.
- skill-creator's `aggregate_benchmark.py` first returned all zeros because the directory layout didn't match what it expected (`run-*` subdirs inside each config + a `summary` key in `grading.json`).
- `generate_review.py` choked on system `python3` (3.9.6) because it uses 3.10+ union syntax (`dict | None`).
- First run with jq extracting session_id from empty stdin produced `claude:` (stray colon) instead of `claude`, because `jq -r '.session_id // "unknown"'` on empty input returns empty string, not "unknown".

**Troubleshooting / resolution**
- Stderr leak: wrapped the OSC printf in a group `{ ... ; } 2>/dev/null || true` so the redirect-failure stderr is captured at the group level, not just on the command inside.
- Aggregator mismatch: reshaped the workspace into `iteration-1/eval-N/<config>/run-1/{outputs,grading.json,timing.json}` and updated grader output schema to include the `summary` object. Grading scripts written to be programmatic, not eyeballed.
- Python version: invoked `generate_review.py` explicitly with `/opt/homebrew/bin/python3.14`. Noted for future: skill tooling assumes modern Python.
- Stray colon: changed the fallback check from `[[ "$session_id" == "unknown" ]]` to `[[ -z "$session_id" || "$session_id" == "unknown" ]]`. Smoke-tested all three cases (valid id, `{}`, empty stdin) before shipping.

**Lessons learned**
- **Captured stdout is a stealth failure mode.** Any Claude Code skill that interacts with the host environment (terminal, clipboard, window manager) needs to route around Bash stdout capture. `/dev/tty` is the obvious escape hatch; clipboard utilities would need similar thinking.
- **Formal evals catch things live-testing misses.** The without-skill baseline *sometimes* renamed correctly — so I would've concluded "works fine" from a couple of live runs. The 48% pass rate only shows up across 21 repetitions. Worth the +8s overhead.
- **Hook envelopes are not optional.** Returning structured JSON from a hook so the model knows what the hook did is a massive reliability upgrade over fire-and-forget side effects. The model's theory-of-mind about the terminal state isn't there without it.
- **The ugly parts of settings.json editing matter.** Two JSON validation guards, a backup, and a trap — feels like overkill for a 20-line script, but this script runs as part of someone else's install flow on their personal config.

**Usability observations**
- Skill-creator's benchmark aggregator has an unstated directory schema. I had to reverse-engineer it from the script, which cost ~10 minutes. A one-paragraph "expected layout" in the aggregator's docstring would have paid for itself.
- System Python on macOS (3.9) shadowing the Homebrew Python (3.14) made `generate_review.py` fail with a cryptic `TypeError` at import time instead of a clear "requires Python 3.10+" message. Tooling that requires modern syntax should gate with an explicit version check at the top of the file.
- Claude Code's Bash stdout capture is not documented where a skill author would naturally look. I only figured out the capture behavior by writing an OSC escape, seeing it not work, and hypothesizing. A one-sentence note in the hook docs ("Bash stdout is captured; escape to `/dev/tty` for terminal control sequences") would have saved an hour.
- The hook input contract (`session_id` lives on the top-level JSON object) is clear, but there's no way to tell from inside the hook whether this is *actually* a user-visible session vs. a subagent or daemon spawn. That's fine for this skill — renaming is harmless — but could matter for hooks that do more expensive work.

**Open questions / next steps**
- Live-test on cmux and iTerm2 across real sessions to confirm behavior matches the eval.
- Decide whether to submit to the Claude marketplace or leave as a clone-and-install.
- Consider a second iteration if live-test surfaces anything the formal eval missed.
