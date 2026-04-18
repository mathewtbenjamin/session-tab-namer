SKILL_NAME := session-tab-namer
SKILL_SRC  := skills/$(SKILL_NAME)
SKILL_DEST := $(HOME)/.claude/skills/$(SKILL_NAME)

.PHONY: help install uninstall test test-integration lint clean

help:
	@echo "session-tab-namer"
	@echo ""
	@echo "  make install          Copy skill to ~/.claude/skills/ and register SessionStart hook"
	@echo "  make uninstall        Remove the SessionStart hook (leaves skill files in place)"
	@echo "  make test             Run hook smoke-test and installer integration test"
	@echo "  make test-integration Run only the installer integration test (tmp HOME, safe)"
	@echo "  make lint             Run shellcheck on all shell scripts"
	@echo "  make clean            Remove ~/.claude/skills/$(SKILL_NAME)/ entirely"

install:
	@command -v jq >/dev/null 2>&1 || { echo "Error: jq is required. Install with 'brew install jq' or 'apt-get install jq'."; exit 1; }
	mkdir -p "$(SKILL_DEST)"
	cp -R $(SKILL_SRC)/. "$(SKILL_DEST)/"
	chmod +x "$(SKILL_DEST)"/scripts/*.sh
	bash "$(SKILL_DEST)/scripts/install.sh"

uninstall:
	@if [ -f "$(SKILL_DEST)/scripts/uninstall.sh" ]; then \
		bash "$(SKILL_DEST)/scripts/uninstall.sh"; \
	else \
		bash $(SKILL_SRC)/scripts/uninstall.sh; \
	fi

test: test-smoke test-integration

test-smoke:
	@echo "Smoke-testing the hook script with a fake session_id..."
	@printf '{"session_id":"abcdef1234567890"}' | bash $(SKILL_SRC)/scripts/session_start_hook.sh | jq -e '.hookSpecificOutput.hookEventName == "SessionStart"' >/dev/null && echo "OK: hook emits valid envelope"
	@printf '' | bash $(SKILL_SRC)/scripts/session_start_hook.sh | jq -e '.hookSpecificOutput.additionalContext | test("claude")' >/dev/null && echo "OK: hook handles empty input"

test-integration:
	@echo "Running installer integration test (safe: uses tmp HOME)..."
	@bash tests/install_test.sh

lint:
	@command -v shellcheck >/dev/null 2>&1 || { echo "Error: shellcheck is required. Install with 'brew install shellcheck' or 'apt-get install shellcheck'."; exit 1; }
	@shellcheck \
		$(SKILL_SRC)/scripts/install.sh \
		$(SKILL_SRC)/scripts/uninstall.sh \
		$(SKILL_SRC)/scripts/session_start_hook.sh \
		tests/install_test.sh
	@echo "OK: shellcheck clean on all scripts"

clean:
	rm -rf "$(SKILL_DEST)"
	@echo "Removed $(SKILL_DEST)"
