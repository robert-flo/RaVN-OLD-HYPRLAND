# ═══════════════════════════════════════════════════════════════
# 🔬 DEVELOPMENT TOOLS - Package search and analysis
# ═══════════════════════════════════════════════════════════════
# 📚 Documentation: docs/src/content/docs/makefile/08-dev.mdx
# 🎯 Purpose: Host listing, package search, REPL, shell, VM and closure analysis
# ──── Overview: 7 targets for development and inspection tasks ────
#
# 🧪 Dry Run (preview without executing):
#    make dev-repl   DRY_RUN=1   · skip launching repl
#    make dev-shell  DRY_RUN=1   · skip entering shell
#    make dev-vm     DRY_RUN=1   · skip build and run
#    (dev-hosts, dev-search, dev-search-inst, dev-size are read-only)

.PHONY: dev-hosts dev-search dev-search-inst dev-repl dev-shell dev-vm dev-size

# ──── Dry Run: make <target> DRY_RUN=1 to preview without executing ─
DRY_RUN ?= 0
export DRY_RUN
ifeq ($(DRY_RUN),1)
  EXEC = echo "  ▶ [dry-run]"
else
  EXEC =
endif

# === Analysis and Development ===

# ═══════════════════════════════════════════════════════════════
# 🔧 DEV-SETUP - Wire git hooks and prepare dev environment
# ═══════════════════════════════════════════════════════════════
# ──── Setup: activates .git-hooks/pre-commit for quality gates ───
dev-setup: ## Wire git hooks and prepare local dev environment
	@printf "\n"
	@printf "$(CYAN)🔧 dev-setup · configure dev environment$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  git hooks path...            "
	@git config core.hooksPath .git-hooks && printf "$(GREEN)✓$(NC)\n" || printf "$(RED)✗$(NC)\n"
	@printf "  pre-commit executable...     "
	@if [ -x ".git-hooks/pre-commit" ]; then \
		printf "$(GREEN)✓$(NC)\n"; \
	else \
		chmod +x .git-hooks/pre-commit 2>/dev/null && printf "$(YELLOW)✎ fixed$(NC)\n" || printf "$(RED)✗ not found$(NC)\n"; \
	fi
	@printf "  shfmt...                    "
	@command -v shfmt >/dev/null 2>&1 && printf "$(GREEN)✓$(NC)\n" || printf "$(YELLOW)⚠  not installed$(NC)\n"
	@printf "  shellcheck...               "
	@command -v shellcheck >/dev/null 2>&1 && printf "$(GREEN)✓$(NC)\n" || printf "$(YELLOW)⚠  not installed$(NC)\n"
	@printf "  logs/ dir...                "
	@mkdir -p logs && printf "$(GREEN)✓$(NC)\n"
	@printf "\n$(GREEN)  ✓ done$(NC)\n"
	@printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"
	@printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  • test the hook: $(BLUE)git commit --allow-empty -m 'test'$(NC)\n"
	@printf "  • run report manually: $(BLUE)make fmt-report$(NC)\n"
	@printf "  • skip hook (emergency): $(BLUE)SKIP_HOOKS=1 git commit$(NC)\n\n"
