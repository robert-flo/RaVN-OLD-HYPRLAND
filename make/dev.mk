# ═══════════════════════════════════════════════════════════════
# 🔬 DEVELOPMENT TOOLS - Package search and analysis
# ═══════════════════════════════════════════════════════════════
# 📚 Documentation: docs/src/content/docs/makefile/08-dev.mdx
# 🎯 Purpose: Host listing, package search, REPL, shell, VM and closure analysis
# ──── Overview: 7 targets for development and inspection tasks ────
#
# 🧪 Dry Run (preview without executing):
#    make dev-repl       DRY_RUN=1   · skip launching repl
#    make dev-shell      DRY_RUN=1   · skip entering shell
#    make dev-vm         DRY_RUN=1   · skip running vm
#    make dev-vm-persist DRY_RUN=1   · skip running persistent vm
#    make dev-vm-clean   DRY_RUN=1   · skip cleaning cache
#    make dev-vm-setup   DRY_RUN=1   · skip setup steps
#    (dev-hosts, dev-search, dev-search-inst, dev-size, dev-vm-list, dev-vm-size are read-only)
#
# 💡 Usage Examples:
#    make dev-vm                     · run vm on current active branch
#    make dev-vm REF=dev             · run vm on specific branch 'dev'
#    make dev-vm REF=500c083         · run vm on specific commit hash '500c083'
#    make dev-vm-persist REF=dev     · run vm with persistent changes on 'dev'
#    make dev-vm VM_MEMORY=8G        · run vm overriding memory allocation (8G)
#    make dev-vm VM_CPUS=4           · run vm overriding CPU cores allocation (4)
#    make dev-vm VM_EXTRA_ARGS="..." · run vm with extra QEMU arguments
#    make dev-vm-list                · list available snapshots
#    make dev-vm-clean               · clean all VM cache and snapshots
#    make dev-vm-setup               · verify and install VM dependencies
#    make dev-vm-size                · check VM disk usage and free space

.PHONY: dev-hosts dev-search dev-search-inst dev-repl dev-shell dev-vm dev-size dev-vm-persist dev-vm-list dev-vm-clean dev-vm-setup dev-vm-size

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
# 🖥️  DEV-VM - Virtual Machine commands using ravnvm
# ═══════════════════════════════════════════════════════════════

# ──── VM Configuration: Default resources and branch/commit ───
REF ?= $(shell git rev-parse --abbrev-ref HEAD 2>/dev/null || echo master)
VM_MEMORY ?= 4G
VM_CPUS ?= 2

# ──── VM: Run Arch-based VM for RaVN testing ──────────────────
dev-vm: ## Run Arch-based VM for RaVN testing (REF=branch/commit, VM_MEMORY=4G, VM_CPUS=2)
ifndef EMBEDDED
	@printf "\n"
	@printf "$(CYAN)🖥️  dev-vm · run ravn vm (ref: $(REF))$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
endif
	@if [ "$$DRY_RUN" = "1" ]; then \
		printf "  ▶ [dry-run] VM_MEMORY=$(VM_MEMORY) VM_CPUS=$(VM_CPUS) VM_EXTRA_ARGS=\"$(VM_EXTRA_ARGS)\" VM_QEMU_OVERRIDE=\"$(VM_QEMU_OVERRIDE)\" Scripts/ravnvm/ravnvm.sh $(REF)\n"; \
	else \
		VM_MEMORY=$(VM_MEMORY) VM_CPUS=$(VM_CPUS) VM_EXTRA_ARGS="$(VM_EXTRA_ARGS)" VM_QEMU_OVERRIDE="$(VM_QEMU_OVERRIDE)" Scripts/ravnvm/ravnvm.sh $(REF); \
	fi
ifndef EMBEDDED
	@printf "\n$(GREEN)  ✓ session ended$(NC)\n"
endif
	@printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"
	@printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  • list cached vm snapshots: $(BLUE)make dev-vm-list$(NC)\n"
	@printf "  • run vm with persistence:  $(BLUE)make dev-vm-persist REF=$(REF)$(NC)\n\n"

# ──── VM: Run VM with persistent changes ──────────────────────
dev-vm-persist: ## Run VM with persistent changes (REF=branch/commit, VM_MEMORY=4G, VM_CPUS=2)
ifndef EMBEDDED
	@printf "\n"
	@printf "$(CYAN)🖥️  dev-vm-persist · run persistent ravn vm (ref: $(REF))$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
endif
	@if [ "$$DRY_RUN" = "1" ]; then \
		printf "  ▶ [dry-run] VM_MEMORY=$(VM_MEMORY) VM_CPUS=$(VM_CPUS) VM_EXTRA_ARGS=\"$(VM_EXTRA_ARGS)\" VM_QEMU_OVERRIDE=\"$(VM_QEMU_OVERRIDE)\" Scripts/ravnvm/ravnvm.sh --persist $(REF)\n"; \
	else \
		VM_MEMORY=$(VM_MEMORY) VM_CPUS=$(VM_CPUS) VM_EXTRA_ARGS="$(VM_EXTRA_ARGS)" VM_QEMU_OVERRIDE="$(VM_QEMU_OVERRIDE)" Scripts/ravnvm/ravnvm.sh --persist $(REF); \
	fi
ifndef EMBEDDED
	@printf "\n$(GREEN)  ✓ session ended$(NC)\n"
endif
	@printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"
	@printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  • run vm without persistence: $(BLUE)make dev-vm REF=$(REF)$(NC)\n\n"

# ──── VM: List cached snapshots ───────────────────────────────
dev-vm-list: ## List available VM snapshots
ifndef EMBEDDED
	@printf "\n"
	@printf "$(CYAN)🖥️  dev-vm-list · list available snapshots$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
endif
	@Scripts/ravnvm/ravnvm.sh --list
ifndef EMBEDDED
	@printf "\n$(GREEN)  ✓ done$(NC)\n"
endif
	@printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"
	@printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  • run vm on current branch: $(BLUE)make dev-vm$(NC)\n\n"

# ──── VM: Clean cached images and snapshots ───────────────────
dev-vm-clean: ## Clean VM cache and snapshots
ifndef EMBEDDED
	@printf "\n"
	@printf "$(CYAN)🖥️  dev-vm-clean · remove all vm cache and snapshots$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
endif
	@if [ "$$DRY_RUN" = "1" ]; then \
		printf "  ▶ [dry-run] Scripts/ravnvm/ravnvm.sh --clean\n"; \
	else \
		Scripts/ravnvm/ravnvm.sh --clean; \
	fi
ifndef EMBEDDED
	@printf "\n$(GREEN)  ✓ done$(NC)\n"
endif
	@printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"
	@printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  • check and setup deps: $(BLUE)make dev-vm-setup$(NC)\n\n"

# ──── VM: Verify and install dependencies ─────────────────────
dev-vm-setup: ## Check and install VM dependencies
ifndef EMBEDDED
	@printf "\n"
	@printf "$(CYAN)🖥️  dev-vm-setup · verify and install vm dependencies$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
endif
	@printf "  checking dependencies...\n"
	@if [ "$$DRY_RUN" = "1" ]; then \
		printf "  ▶ [dry-run] Scripts/ravnvm/ravnvm.sh --check-deps\n"; \
		printf "  ▶ [dry-run] Scripts/ravnvm/ravnvm.sh --install-deps\n"; \
	else \
		if Scripts/ravnvm/ravnvm.sh --check-deps; then \
			printf "$(GREEN)  ✓ dependencies satisfied$(NC)\n"; \
		else \
			printf "$(YELLOW)  ⚠ dependencies missing, attempting installation...$(NC)\n"; \
			Scripts/ravnvm/ravnvm.sh --install-deps; \
		fi \
	fi
ifndef EMBEDDED
	@printf "\n$(GREEN)  ✓ done$(NC)\n"
endif
	@printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"
	@printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  • run vm on current branch: $(BLUE)make dev-vm$(NC)\n\n"

# ──── VM: Show VM disk space usage and partition availability ──
dev-vm-size: ## Show disk space usage for VMs and partition availability
ifndef EMBEDDED
	@printf "\n"
	@printf "$(CYAN)🖥️  dev-vm-size · vm disk space usage$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
endif
	@VM_DIR="$${XDG_CACHE_HOME:-$$HOME/.cache}/ravnvm"; \
	if [ -d "$$VM_DIR" ]; then \
		printf "  VM storage path:             $$VM_DIR\n"; \
		size_total=$$(du -sh "$$VM_DIR" 2>/dev/null | awk '{print $$1}'); \
		size_snapshots=$$(du -sh "$$VM_DIR/snapshots" 2>/dev/null | awk '{print $$1}' || echo "0"); \
		printf "  total cache size:            $(BOLD)$$size_total$(NC)\n"; \
		printf "  snapshots size:              $(BOLD)$$size_snapshots$(NC)\n"; \
		free_space=$$(df -h "$$VM_DIR" 2>/dev/null | tail -n 1 | awk '{print $$4}'); \
		printf "  available disk space:        $(GREEN)$$free_space$(NC)\n"; \
	else \
		printf "  VM storage path:             $$VM_DIR\n"; \
		printf "  $(YELLOW)⚠  storage path does not exist yet (no VMs created)$(NC)\n"; \
		free_space=$$(df -h "$$HOME" 2>/dev/null | tail -n 1 | awk '{print $$4}'); \
		printf "  available disk space:        $(GREEN)$$free_space$(NC)\n"; \
	fi
ifndef EMBEDDED
	@printf "\n$(GREEN)  ✓ done$(NC)\n"
endif
	@printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"
	@printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  • list cached vm snapshots: $(BLUE)make dev-vm-list$(NC)\n"
	@printf "  • clean vm cached images:   $(BLUE)make dev-vm-clean$(NC)\n\n"

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
	@printf "  workspace .vscode...        "
	@if [ -d "../.git" ] || [ -f "../.git" ]; then \
		if [ ! -d "../.vscode" ]; then \
			cp -r .vscode .. && printf "$(GREEN)✓$(NC)\n"; \
		else \
			printf "$(GREEN)✓ (already exists)$(NC)\n"; \
		fi \
	else \
		printf "$(DIM)skipped (not in sub-workspace)$(NC)\n"; \
	fi
	@printf "  logs/ dir...                "
	@mkdir -p logs && printf "$(GREEN)✓$(NC)\n"
	@printf "\n$(GREEN)  ✓ done$(NC)\n"
	@printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"
	@printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  • test the hook: $(BLUE)git commit --allow-empty -m 'test'$(NC)\n"
	@printf "  • run report manually: $(BLUE)make fmt-report$(NC)\n"
	@printf "  • skip hook (emergency): $(BLUE)SKIP_HOOKS=1 git commit$(NC)\n\n"
