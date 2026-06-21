# ═══════════════════════════════════════════════════════════════
# 🎨 FORMAT & LINT - Shell script formatting and linting
# ═══════════════════════════════════════════════════════════════
# 📚 Documentation: docs/makefile/format.md
# 🎯 Purpose: Format and lint shell scripts via shfmt and shellcheck
# ──── Overview: 4 targets for code formatting and analysis ────

.PHONY: fmt fmt-check fmt-lint fmt-report

# Active shell scripts in development (Scripts folder and root setup)
SHELL_FILES := $(shell find Scripts -type f -name "*.sh" 2>/dev/null) git-setup.sh

fmt: ## Format shell scripts in-place using shfmt
ifndef EMBEDDED
	@printf "\n"
	@printf "$(CYAN)🎨 fmt · format shell scripts$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
endif
	@if command -v shfmt >/dev/null 2>&1; then \
		printf "  formatting shell scripts...  "; \
		shfmt -i 2 -sr -kp -ci -w $(SHELL_FILES) >/dev/null 2>&1 && printf "$(GREEN)✓$(NC)\n" || printf "$(RED)✗$(NC)\n"; \
	else \
		printf "  $(YELLOW)⚠ shfmt not installed$(NC)\n"; \
	fi
ifndef EMBEDDED
	@printf "\n$(GREEN)  ✓ done$(NC)\n"
endif

fmt-check: ## Check formatting of shell scripts
ifndef EMBEDDED
	@printf "\n"
	@printf "$(CYAN)🔍 fmt-check · check shell formatting$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
endif
	@if command -v shfmt >/dev/null 2>&1; then \
		printf "  checking formatting...       "; \
		shfmt -i 2 -sr -kp -ci -d $(SHELL_FILES) >/dev/null 2>&1 && printf "$(GREEN)✓$(NC)\n" || (printf "$(RED)✗ diff found$(NC)\n" && exit 1); \
	else \
		printf "  $(YELLOW)⚠ shfmt not installed$(NC)\n"; \
	fi
ifndef EMBEDDED
	@printf "\n$(GREEN)  ✓ done$(NC)\n"
endif

fmt-lint: ## Lint shell scripts using shellcheck
ifndef EMBEDDED
	@printf "\n"
	@printf "$(CYAN)🔎 fmt-lint · lint shell scripts$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
endif
	@if command -v shellcheck >/dev/null 2>&1; then \
		printf "  linting shell scripts...     \n"; \
		shellcheck $(SHELL_FILES) && printf "\n$(GREEN)  ✓ all checks passed$(NC)\n" || (printf "\n$(RED)  ✗ shellcheck warnings found$(NC)\n" && exit 1); \
	else \
		printf "  $(YELLOW)⚠ shellcheck not installed$(NC)\n"; \
	fi
ifndef EMBEDDED
	@printf "\n$(GREEN)  ✓ done$(NC)\n"
endif

fmt-report: ## Generate shell quality report
ifndef EMBEDDED
	@printf "\n"
	@printf "$(CYAN)📋 fmt-report · shell quality report$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
endif
	@mkdir -p logs
	@LOG_FILE="logs/shellcheck-report-manual.log"; \
	printf "  generating report to...      $$LOG_FILE\n"; \
	{ \
		echo "═══════════════════════════════════════════════════════════════"; \
		echo "  SHELL QUALITY REPORT — $$(date '+%Y-%m-%d %H:%M:%S')"; \
		echo "  Repo: $$(git remote get-url origin 2>/dev/null || echo 'local')"; \
		echo "  Branch: $$(git branch --show-current 2>/dev/null || echo 'unknown')"; \
		echo "═══════════════════════════════════════════════════════════════"; \
		echo ""; \
		echo "──── Shell files checked ───────────────────────────────────────"; \
		for file in $(SHELL_FILES); do echo "  - $$file"; done; \
		echo ""; \
		echo "──── Shellcheck warnings ───────────────────────────────────────"; \
		if command -v shellcheck >/dev/null 2>&1; then \
			shellcheck $(SHELL_FILES) 2>&1 || true; \
		else \
			echo "shellcheck not installed"; \
		fi; \
	} > "$$LOG_FILE"; \
	printf "  shfmt check...               "; \
	if command -v shfmt >/dev/null 2>&1; then \
		shfmt -i 2 -sr -kp -ci -d $(SHELL_FILES) >/dev/null 2>&1 && printf "$(GREEN)✓$(NC)\n" || printf "$(YELLOW)⚠ diff found$(NC)\n"; \
	else \
		printf "$(YELLOW)⊘ not installed$(NC)\n"; \
	fi; \
	printf "  shellcheck check...          "; \
	if command -v shellcheck >/dev/null 2>&1; then \
		shellcheck $(SHELL_FILES) >/dev/null 2>&1 && printf "$(GREEN)✓$(NC)\n" || printf "$(RED)✗ warnings found$(NC)\n"; \
	else \
		printf "$(YELLOW)⊘ not installed$(NC)\n"; \
	fi
ifndef EMBEDDED
	@printf "\n$(GREEN)  ✓ done$(NC)\n"
endif
