# Contributing

Thanks for thinking about contributing to `session-tab-namer`. This skill is deliberately small — a few shell scripts, a skill body, and a SessionStart hook — so contributions should stay small and focused. Issues and PRs are both welcome.

## Scope

The skill does one thing: name Claude Code tabs by session intent. PRs that expand that scope (telemetry, per-terminal APIs, cloud sync, background daemons, etc.) will be declined. PRs that make the one thing work better, in more places, or with fewer edge cases, are the sweet spot.

Good PRs:

- Support for an additional terminal emulator that honors a different title-setting escape
- Portability fixes for a specific shell or platform (zsh quirks, bash 3 vs 5, Alpine `sh`)
- Improvements to the idempotency or safety of `install.sh` / `uninstall.sh`
- Tightening the skill body so Claude picks better prefixes more consistently
- New evals that catch a previously-hidden failure mode
- Better troubleshooting docs with reproducible causes

Not good PRs:

- New subcommands, flags, or configuration knobs (the skill is intentionally minimal)
- Wrappers around third-party services
- Analytics or telemetry of any kind
- Anything that changes the user's shell environment beyond OSC 0

## Development setup

You need: `bash`, `jq`, and `shellcheck` (for lint). All three are available via `brew` or `apt-get`.

```bash
git clone https://github.com/mathewtbenjamin/session-tab-namer.git
cd session-tab-namer
make install       # installs into your local ~/.claude/ — easy to undo with make uninstall
bash tests/install_test.sh   # runs the installer integration test against a tmp HOME
shellcheck skills/session-tab-namer/scripts/*.sh tests/*.sh
```

The `make test` target runs the hook-smoke-test. `tests/install_test.sh` is the installer integration test — it uses a `mktemp -d` as `HOME` so it never touches your real config.

## Pull-request checklist

Before opening a PR:

1. `shellcheck` passes cleanly on every modified `.sh` file
2. `make test` passes
3. `bash tests/install_test.sh` passes
4. If your change affects the skill body (`skills/session-tab-namer/SKILL.md`), rerun the evals in `skills/session-tab-namer/evals/evals.json` by hand against at least one Claude model and note the before/after in your PR description
5. README reflects any user-visible change (install, troubleshooting, FAQ)
6. No telemetry, no network calls from install or hook scripts — this is a hard rule

## Commit style

Short imperative commit messages, lowercase subject, no period:

```
fix idempotency check in install.sh
add shellcheck to CI
update README benchmark narrative to match evals.json
```

One logical change per commit. Don't mix unrelated fixes.

## Running the evals

The three eval prompts are deliberately short and real (one build, one research, one debug). To rerun:

1. Open a fresh Claude Code session
2. Paste the prompt from `skills/session-tab-namer/evals/evals.json`
3. Observe whether the model emits a `printf '\033]0;<name>\007' > /dev/tty` command with a prefix matching the eval's expected prefix family

There is currently no automated eval runner in this repo — the harness lives in the maintainer's private workspace. If you want to run evals at scale, see the "Benchmark" section of the README for the methodology and open an issue to discuss before building a runner in-tree.

## Code of conduct

Be kind. Disagree with the work, not the person. No harassment, no discrimination, no personal attacks. Maintainers reserve the right to close or lock discussions that violate this.

## License

By contributing, you agree that your contributions will be licensed under the same MIT license as the project.
