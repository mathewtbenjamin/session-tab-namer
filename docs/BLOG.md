# Name Your Tabs: Building a Claude Code Skill That Actually Remembers What It's For

*Draft — 2026-04-14*

I have twelve terminal tabs open right now. Nine of them say `claude`. One says `zsh`. Two say `node`. If I want to resume the JWT-rotation research I was doing this morning, my only option is to alt-tab through every single one and read the scrollback until I find the right one. This is stupid, and it's been stupid for the entire two years I've been using Claude Code.

So I fixed it. This is the story of how — and more interestingly, what I learned about building Claude Code skills when the work involved crossing the boundary between the model and the host operating system.

## The idea in one sentence

A Claude Code skill that auto-names every terminal tab based on what the session is actually for: `build:embabel-multi-agent`, `research:jwt-rotation`, `debug:pytest-flaky`, `write:cortex-q2-prd`. No manual renaming. No fixed vocabulary. Works across iTerm2, Terminal.app, cmux, WezTerm, tmux — anywhere that speaks the OSC 0 escape sequence, which is everywhere.

## Why a skill and not a shell alias

My first instinct was: write a zsh function, bind it to a keybinding, done. But the whole point is that I don't want to *remember* to rename the tab. I want the tab to know what I'm doing because *Claude* knows what I'm doing — Claude already has my objective in context the moment I state it. A shell alias would mean me typing `rename-tab research:jwt-rotation` every time, which is exactly the friction I was trying to eliminate.

So the skill has to observe what I'm doing and rename the tab without being asked. That means it runs inside the model's loop, not outside it.

## The two-piece architecture

It turned into two cooperating pieces:

1. **A `SessionStart` hook** that fires the instant a new Claude Code session opens, before I've typed anything. It sets a fallback name like `claude:a3f2c1` using the first six characters of the session ID, so the tab is never blank.
2. **A skill** (a Markdown file with YAML frontmatter, the Claude Code primitive for bundling instructions) that tells the model: "as soon as the user's objective is clear, replace the fallback with a semantic name like `build:*` or `research:*`."

Split like this because they solve different problems. The hook solves "the tab is unnamed before Claude has anything to work with." The skill solves "the model needs explicit instructions to rename the tab instead of just answering the question and moving on." Neither is sufficient alone.

## The trap: captured stdout

Here's where it got interesting. Renaming a terminal tab is trivial — every mainstream terminal emulator honors the OSC 0 escape sequence:

```bash
printf '\033]0;build:embabel-multi-agent\007'
```

That's it. That's the mechanism. I wrote the skill, told it to run exactly that command, and... nothing happened. The tab didn't change.

It took me longer than I'd like to admit to figure out why: **Claude Code captures Bash stdout for the model's context window.** Every byte I printed went into the next token of the model's input, not onto the terminal. The escape sequence was being *read by the model* instead of being interpreted by the terminal emulator.

The fix is one character:

```bash
printf '\033]0;build:embabel-multi-agent\007' > /dev/tty
```

Redirecting to `/dev/tty` bypasses Claude Code's stdout capture and writes directly to the controlling terminal. The escape reaches the window manager. The tab renames. Magic.

This is the single most important thing I learned building the skill, and it generalizes: **any Claude Code skill that interacts with the host environment — terminal, clipboard, window manager, notifications — needs to route around stdout capture.** `/dev/tty` is the obvious escape hatch for TTY things; I'd bet other side-channels (`pbcopy`, `osascript`, `notify-send`) work fine because they don't rely on stdout reaching any particular place.

## The hook, and why it talks back to Claude

The `SessionStart` hook is about 30 lines of Bash. It reads a JSON blob from stdin (Claude Code passes session metadata this way), extracts `session_id`, writes the OSC escape to `/dev/tty`, and then — this is the important part — emits a JSON envelope back to Claude:

```json
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "Terminal tab was auto-named 'claude:a3f2c1'. Invoke the session-tab-namer skill to replace the fallback with a semantic name as soon as the objective is clear."
  }
}
```

That `additionalContext` field turned out to be load-bearing. Without it, the model has no idea the hook just set a fallback name, so it doesn't know to rename it later. *With* it, the model's next turn starts with "ah, the tab says `claude:a3f2c1`, and once the user tells me what they want I should upgrade it." The rename becomes automatic.

The lesson: **hooks that do side effects should tell the model they did side effects.** Fire-and-forget is leaving value on the table. The model has good theory of mind when you hand it the relevant facts; without them it's guessing.

## The part I almost skipped: a real eval

I wanted to live-test the skill and call it done. I live-tested, it worked, I called it done. Then I forced myself to run a formal eval anyway — three prompts (build a multi-agent app, research JWT rotation, debug a flaky pytest suite) against both the skill and a no-skill baseline, three runs each. The results are in the README:

|            | With skill     | Without skill  |
| ---------- | -------------- | -------------- |
| Pass rate  | **100%** (21/21) | **48%** (10/21)  |
| Time       | 28.0s          | 19.8s          |
| Tokens     | 20,657         | 17,398         |

The interesting number is 48%, not 100%. The baseline — Claude Code *without* the skill — renamed the tab correctly slightly less than half the time. Sometimes it forgot. Sometimes it wrote the escape to captured stdout and never realized it had silently failed. Sometimes it renamed to something generic like `build:stuff`. My live test had hit two successful runs back to back and told me "works fine." It didn't.

**Live-testing a few times lies to you.** If I hadn't run the eval I would've shipped something that worked when I was watching and broke when I wasn't.

The +8s and +3k-tokens overhead is the cost of making this reliable — one extra tool call's worth of work at session start, basically. For a once-per-session behavior it's cheap.

## Production-izing for GitHub

After the eval, I packaged it for public release:

- An idempotent `install.sh` that registers the hook in `~/.claude/settings.json` via `jq`, with JSON-validity guards before *and* after editing and a timestamped backup.
- A matching `uninstall.sh` that removes only the entries referencing this hook, preserving any unrelated hooks the user has installed.
- A `Makefile` with `install` / `uninstall` / `test` / `clean` targets, because the audience is Claude Code users and they like making their install steps one command.
- An MIT license because I want people to fork it and add their own naming conventions.

The installer's double-JSON-guard felt like overkill when I wrote it. Then I remembered it's running against *someone else's* personal config file, which may have been hand-edited, and which is the beating heart of their Claude Code setup. Clobbering that file on a jq error is the kind of bug that would cost someone an hour of their day and turn a cute little skill into a liability.

## What I'd tell someone building their first skill

Three things.

**One: figure out the model's I/O boundaries early.** Claude Code wraps Bash commands in stdout capture. It probably does similar things to other tools. Before you build anything that interacts with the host environment, sanity-check that your side effects are actually reaching their destination. Don't assume `printf` prints.

**Two: hooks are a communication channel, not just a trigger.** The most valuable thing the `SessionStart` hook does isn't renaming the tab — it's telling the model, in plain text, what state the world is in. Every hook should consider whether it has useful context to feed back into the conversation.

**Three: evals catch the 52%.** If I had shipped this from live-test alone, I'd have shipped a skill that worked half the time. The formal eval took about twenty minutes and caught a failure mode I was systematically blind to. Every skill that has an objective outcome — "did the tab get renamed?", "did the file get created?", "did the PR get opened?" — should get an eval, even a three-prompt one.

## What's next

- Live-testing across a week of real sessions in iTerm2 and cmux. If any failure modes show up that the eval missed, iteration 2 and another eval round.
- Possibly a marketplace submission once the live-test confirms it behaves.
- A second skill using the same pattern for a different host-side concern — clipboard history labeling, maybe, or auto-naming saved terminal layouts. The OSC-0-via-`/dev/tty` pattern wants to be reused.

The repo is at [github.com/mathewtbenjamin/session-tab-namer](https://github.com/mathewtbenjamin/session-tab-namer). The skill is MIT-licensed. If you install it and name your tabs something weird, I want to hear about it.
