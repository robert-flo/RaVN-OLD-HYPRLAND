# ═══════════════════════════════════════════════════════════════
# 🎨 FORMAT & LINT - Shell script formatting and linting
# ═══════════════════════════════════════════════════════════════
# 📚 Documentation: docs/src/content/docs/makefile/09-format.mdx
# 🎯 Purpose: Format, lint, and visualize project files and configurations
# ──── Overview: 6 targets for code quality, structure, and diffs ──
#
# 📎 Aliases & Targets:
#    ALIAS           TARGET                   DESCRIPTION
#    f      / fmt-f  fmt                      Format shell scripts in-place using shfmt
#    format / fmt-c  fmt-check                Check formatting of shell scripts
#    lint   / fmt-l  fmt-lint                 Lint shell scripts using shellcheck
#    fr     / fmt-r  fmt-report               Generate shell quality report
#    tree            fmt-tree                 Show project structure tree
#    diff-config     fmt-diff                 Show diff between local and repository configs
#
# 🧪 Dry Run (preview without executing):
#    (fmt performs in-place formatting and does not support DRY_RUN)
#    (fmt-check, fmt-lint, fmt-report, fmt-tree, fmt-diff are read-only)

DRY_RUN ?= 0
export DRY_RUN
ifeq ($(DRY_RUN),1)
  EXEC = echo "  ▶ [dry-run]"
else
  EXEC =
endif

.PHONY: fmt fmt-check fmt-lint fmt-report fmt-tree fmt-diff

# Active shell scripts in development (Scripts folder and root setup)
SHELL_FILES := $(shell find Scripts -type f -name "*.sh" 2>/dev/null) git-setup.sh

# ═══════════════════════════════════════════════════════════════
# 🎨 FMT - Format shell scripts in-place using shfmt
# ═══════════════════════════════════════════════════════════════
# ──── Format: Applies shfmt code formatting to shell scripts ───
fmt: ## Format shell scripts in-place using shfmt
ifndef EMBEDDED
	@printf "\n"
	@printf "$(CYAN)🎨 fmt · format shell scripts$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
endif
	@if command -v shfmt >/dev/null 2>&1; then \
		printf "  formatting shell scripts...  "; \
		if [ "$(DRY_RUN)" = "1" ]; then \
			printf "\n  ▶ [dry-run] shfmt -i 2 -sr -kp -ci -w <files>\n"; \
		else \
			shfmt -i 2 -sr -kp -ci -w $(SHELL_FILES) >/dev/null 2>&1 && printf "$(GREEN)✓$(NC)\n" || printf "$(RED)✗$(NC)\n"; \
		fi; \
	else \
		printf "  $(YELLOW)⚠ shfmt not installed$(NC)\n"; \
	fi
ifndef EMBEDDED
	@printf "\n$(GREEN)  ✓ done$(NC)\n"
endif
	@printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"
	@printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  • check formatting:  $(BLUE)make fmt-check$(NC)\n"
	@printf "  • lint for issues:   $(BLUE)make fmt-lint$(NC)\n\n"

# ═══════════════════════════════════════════════════════════════
# 🔍 FMT-CHECK - Check formatting of shell scripts
# ═══════════════════════════════════════════════════════════════
# ──── Check: Validates shell script formatting without changes ──
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
	@printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"
	@printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  • format files:      $(BLUE)make fmt$(NC)\n"
	@printf "  • lint for issues:   $(BLUE)make fmt-lint$(NC)\n\n"

# ═══════════════════════════════════════════════════════════════
# 🔎 FMT-LINT - Lint shell scripts using shellcheck
# ═══════════════════════════════════════════════════════════════
# ──── Lint: Runs shellcheck static analysis on shell scripts ───
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
	@printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"
	@printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  • format files:      $(BLUE)make fmt$(NC)\n"
	@printf "  • generate report:   $(BLUE)make fmt-report$(NC)\n\n"

# ═══════════════════════════════════════════════════════════════
# 📋 FMT-REPORT - Generate shell quality report
# ═══════════════════════════════════════════════════════════════
# ──── Report: Generates detailed shellcheck and shfmt report ───
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
	@printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"
	@printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  • format files:      $(BLUE)make fmt$(NC)\n"
	@printf "  • lint for issues:   $(BLUE)make fmt-lint$(NC)\n\n"

# ═══════════════════════════════════════════════════════════════
# 📂 FMT-TREE - Show project structure tree
# ═══════════════════════════════════════════════════════════════
# ──── Structure: Excludes result*, node_modules, .git ─────────
fmt-tree: ## Show project structure tree
ifndef EMBEDDED
	@printf "\n"
	@printf "$(CYAN)📂 fmt-tree · project structure$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
endif
	@if command -v tree >/dev/null 2>&1; then \
		tree -C -L 3 --gitignore; \
	elif command -v lsd >/dev/null 2>&1; then \
		lsd --tree --depth 3 -I "result*" -I "node_modules" -I ".git" -I "dist" -I "cache" -I ".astro" -I ".vscode"; \
	else \
		find . -maxdepth 3 -not -path '*/.*' -not -path './result*' -not -path './docs/node_modules*'; \
	fi
ifndef EMBEDDED
	@printf "\n$(GREEN)  ✓ done$(NC)\n"
endif
	@printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"
	@printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  • check config differences: $(BLUE)make fmt-diff$(NC)\n\n"

# ═══════════════════════════════════════════════════════════════
# 📉 FMT-DIFF - Show diff between local and repository configs
# ═══════════════════════════════════════════════════════════════
# ──── Compares active files in $$HOME against Configs/ templates ─
fmt-diff: ## Show diff between local active configs and repository templates
ifndef EMBEDDED
	@printf "\n"
	@printf "$(CYAN)📉 fmt-diff · local configs vs templates$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
endif
	@if [ -f "Scripts/diff_cfg.sh" ]; then \
		bash Scripts/diff_cfg.sh; \
	else \
		printf "$(RED)  ❌ Scripts/diff_cfg.sh not found$(NC)\n"; \
	fi
ifndef EMBEDDED
	@printf "\n$(GREEN)  ✓ done$(NC)\n"
endif
	@printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"
	@printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  • check formatting: $(BLUE)make fmt-check$(NC)\n\n"
