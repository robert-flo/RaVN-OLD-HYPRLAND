# ═══════════════════════════════════════════════════════════════
# 🖥️  RAVNVM DEVELOPMENT - Isolated VM testing
# ═══════════════════════════════════════════════════════════════
# 📚 Documentation: Scripts/ravnvm/README.md
# 🎯 Purpose: Run, inspect and manage isolated RaVN development VMs
# ──── Overview: 9 targets for the complete RavnVM workflow ───
#
# 📎 Aliases & Targets:
#    ALIAS  TARGET                         DESCRIPTION
#    vm     dev-vm                        Run an ephemeral VM for REF
#    —      dev-vm-persist                Run a persistent VM for REF
#    —      dev-vm-list                   List cached revision snapshots
#    —      dev-vm-clean                  Clean snapshots and temporary data
#    —      dev-vm-setup                  Check or install host dependencies
#    —      dev-vm-storage                Show cache and filesystem usage
#    —      dev-vm-size                   Alias for dev-vm-storage
#    —      dev-vm-ssh                    Connect to the running VM via SSH
#    —      dev-vm-install-ssh-alias      Install the ssh ravnvm host alias
#    —      dev-vm-external               Run an external repository
#
# 🧪 Dry Run (preview without executing RavnVM):
#    make dev-vm                    DRY_RUN=1   · preview an ephemeral VM
#    make dev-vm-persist            DRY_RUN=1   · preview a persistent VM
#    make dev-vm-clean              DRY_RUN=1   · skip cache cleanup
#    make dev-vm-setup              DRY_RUN=1   · skip dependency changes
#    make dev-vm-ssh                DRY_RUN=1   · skip the SSH connection
#    make dev-vm-install-ssh-alias  DRY_RUN=1   · skip SSH alias installation
#    (help, list and storage targets are read-only and always execute)
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

RAVNVM ?= $(SCRIPTS_DIR)/ravnvm/ravnvm.sh
GIT ?= git
REF ?= $(shell ref=$$($(GIT) branch --show-current 2>/dev/null); \
	if [ -n "$$ref" ]; then printf '%s' "$$ref"; \
	else $(GIT) rev-parse HEAD 2>/dev/null || printf 'master'; fi)
VM_MEMORY ?= 4G
VM_CPUS ?= 2
VM_EXTRA_ARGS ?=
VM_QEMU_OVERRIDE ?=
DRY_RUN ?= 0

RAVNVM_TARGETS := dev-vm dev-vm-persist dev-vm-list dev-vm-clean dev-vm-setup \
	dev-vm-storage dev-vm-size dev-vm-ssh dev-vm-install-ssh-alias dev-vm-external

.PHONY: help-ravnvm $(RAVNVM_TARGETS) dev-setup

define check-ravnvm
	if case '$(RAVNVM)' in */*) [ -x '$(RAVNVM)' ];; *) command -v '$(RAVNVM)' >/dev/null 2>&1;; esac; then \
		:; \
	else \
		printf "$(RED)  ✗ RavnVM executable not found or not executable:$(NC) %s\n" '$(RAVNVM)' >&2; \
		printf "  set RAVNVM=/path/to/ravnvm.sh or define SCRIPTS_DIR correctly\n" >&2; \
		printf "  expected default: %s/ravnvm/ravnvm.sh\n" '$(SCRIPTS_DIR)' >&2; \
		exit 127; \
	fi
endef

define run-ravnvm
	@if [ "$(DRY_RUN)" = "1" ]; then \
		printf "  ▶ [dry-run] VM_MEMORY='%s' VM_CPUS='%s' VM_EXTRA_ARGS='%s' VM_QEMU_OVERRIDE='%s' %s%s\n" \
			'$(VM_MEMORY)' '$(VM_CPUS)' '$(value VM_EXTRA_ARGS)' '$(value VM_QEMU_OVERRIDE)' '$(RAVNVM)' ' $(1)'; \
		printf "$(GREEN)  ✓ dry-run complete$(NC)\n"; \
	else \
		$(check-ravnvm); \
		if VM_MEMORY='$(VM_MEMORY)' VM_CPUS='$(VM_CPUS)' \
		VM_EXTRA_ARGS='$(value VM_EXTRA_ARGS)' VM_QEMU_OVERRIDE='$(value VM_QEMU_OVERRIDE)' \
		'$(RAVNVM)' $(1); then \
			printf "$(GREEN)  ✓ RavnVM operation completed$(NC)\n"; \
		else \
			status=$$?; \
			printf "$(RED)  ✗ RavnVM operation failed (exit $$status)$(NC)\n" >&2; \
			exit $$status; \
		fi; \
	fi; \
	printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"; \
	printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"; \
	printf "  • inspect repository:    $(BLUE)make git-status$(NC)\n"; \
	printf "  • list cached snapshots: $(BLUE)make dev-vm-list$(NC)\n"; \
	printf "  • check VM dependencies: $(BLUE)make dev-vm-setup$(NC)\n\n"
endef

define run-ravnvm-readonly
	@$(check-ravnvm); \
	if VM_MEMORY='$(VM_MEMORY)' VM_CPUS='$(VM_CPUS)' \
		VM_EXTRA_ARGS='$(value VM_EXTRA_ARGS)' VM_QEMU_OVERRIDE='$(value VM_QEMU_OVERRIDE)' \
		'$(RAVNVM)' $(1); then \
		printf "$(GREEN)  ✓ RavnVM query completed$(NC)\n"; \
	else \
		status=$$?; \
		printf "$(RED)  ✗ RavnVM query failed (exit $$status)$(NC)\n" >&2; \
		exit $$status; \
	fi; \
	printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"; \
	printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"; \
	printf "  • run an ephemeral VM:  $(BLUE)make dev-vm$(NC)\n"; \
	printf "  • clean snapshots:    $(BLUE)make dev-vm-clean$(NC)\n"; \
	printf "  • check dependencies:  $(BLUE)make dev-vm-setup$(NC)\n\n"
endef

define run-ravnvm-clean
	@$(check-ravnvm); \
	CACHE_DIR="$${XDG_CACHE_HOME:-$$HOME/.cache}/ravnvm"; \
	TMP=$$(mktemp); trap 'rm -f "$$TMP"' EXIT; \
	if [ -d "$$CACHE_DIR" ]; then \
		find "$$CACHE_DIR" -mindepth 1 -maxdepth 1 ! -name archbase.qcow2 ! -name session.lock -print > "$$TMP"; \
	fi; \
	printf "$(YELLOW)  cache cleanup preview:$(NC) $$CACHE_DIR\n"; \
	if [ -s "$$TMP" ]; then \
		while IFS= read -r item; do \
			printf "  $(RED)-$(NC) %s  $(DIM)(%s)$(NC)\n" "$$item" "$$(du -sh "$$item" 2>/dev/null | awk '{print $$1}' || printf '?')"; \
		done < "$$TMP"; \
		TOTAL=$$(du -ch $$(cat "$$TMP") 2>/dev/null | tail -n 1 | awk '{print $$1}'); \
		printf "  $(DIM)total: %s$(NC)\n" "$$TOTAL"; \
	else \
		printf "  $(GREEN)✓ nothing to clean$(NC)\n"; \
	fi; \
	if [ "$(DRY_RUN)" = "1" ]; then \
		printf "  ▶ [dry-run] cache cleanup skipped\n"; \
	else \
		printf "\n  Remove the listed cache data? [y/N] "; read -r answer; \
		case "$$answer" in y|Y|yes|YES) \
			if VM_MEMORY='$(VM_MEMORY)' VM_CPUS='$(VM_CPUS)' \
				VM_EXTRA_ARGS='$(value VM_EXTRA_ARGS)' VM_QEMU_OVERRIDE='$(value VM_QEMU_OVERRIDE)' \
				'$(RAVNVM)' --clean; then \
				printf "$(GREEN)  ✓ RavnVM cache cleaned$(NC)\n"; \
			else \
				status=$$?; printf "$(RED)  ✗ RavnVM cache cleanup failed (exit $$status)$(NC)\n" >&2; exit $$status; \
			fi ;; \
		*) printf "  cleanup cancelled; no changes made\n" ;; esac; \
	fi; \
	printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"; \
	printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"; \
	printf "  • list snapshots: $(BLUE)make dev-vm-list$(NC)\n"; \
	printf "  • inspect storage: $(BLUE)make dev-vm-storage$(NC)\n"; \
	printf "  • run an ephemeral VM:  $(BLUE)make dev-vm$(NC)\n\n"
endef

define run-ravnvm-setup
	@if [ "$(DRY_RUN)" = "1" ]; then \
		printf '  ▶ [dry-run] %s --check-deps\n' '$(RAVNVM)'; \
		printf '  ▶ [dry-run] %s --install-deps\n' '$(RAVNVM)'; \
		printf "$(GREEN)  ✓ dry-run complete$(NC)\n"; \
	else \
		$(check-ravnvm); \
		if '$(RAVNVM)' --check-deps; then \
			printf "$(GREEN)  ✓ VM dependencies are ready$(NC)\n"; \
		else \
			printf "  dependencies missing; attempting installation...\n"; \
			if '$(RAVNVM)' --install-deps; then \
				printf "  verifying installed dependencies...\n"; \
				if '$(RAVNVM)' --check-deps; then \
					printf "$(GREEN)  ✓ VM dependencies installed and verified$(NC)\n"; \
				else \
					printf "$(RED)  ✗ dependency installation completed but verification failed$(NC)\n" >&2; \
					exit 1; \
				fi; \
			else \
				status=$$?; \
				printf "$(RED)  ✗ VM dependency setup failed (exit $$status)$(NC)\n" >&2; \
				exit $$status; \
			fi; \
		fi; \
	fi; \
	printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"; \
	printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"; \
	printf "  • run an ephemeral VM:  $(BLUE)make dev-vm$(NC)\n"; \
	printf "  • inspect VM storage:  $(BLUE)make dev-vm-storage$(NC)\n"; \
	printf "  • list cached snapshots: $(BLUE)make dev-vm-list$(NC)\n\n"

endef

help-ravnvm: ## Show the RavnVM development targets
	@printf '$(CYAN)RavnVM development targets$(NC)\n'
	@printf '  make dev-vm             Run an ephemeral VM (REF, VM_MEMORY, VM_CPUS)\n'
	@printf '  make dev-vm-persist     Run a persistent VM\n'
	@printf '  make dev-vm-list        List cached snapshots\n'
	@printf '  make dev-vm-clean       Clean snapshots and temporary cache data\n'
	@printf '  make dev-vm-setup       Check or install VM dependencies\n'
	@printf '  make dev-vm-storage     Show RavnVM storage usage\n'
	@printf '  make dev-vm-size        Alias for dev-vm-storage\n'
	@printf '  make dev-vm-ssh         Connect to the running VM via SSH\n'
	@printf '  make dev-vm-install-ssh-alias  Install the ssh ravnvm host alias\n'
	@printf '  make dev-vm-external REPO=owner/name REF=master\n'
	@printf '                              Run an external repository (ephemeral)\n'
	@printf '\nSet DRY_RUN=1 to print commands without executing RavnVM.\n'

dev-vm: ## Run an ephemeral VM
	$(call run-ravnvm,$(REF))

dev-vm-persist: ## Run a persistent VM
	$(call run-ravnvm,--persist $(REF))

dev-vm-list: ## List cached snapshots
	$(call run-ravnvm-readonly,--list)

dev-vm-clean: ## Clean snapshots and temporary cache data
	$(call run-ravnvm-clean)

dev-vm-storage: ## Show RavnVM storage usage
	$(call run-ravnvm-readonly,--storage)

dev-vm-size: dev-vm-storage ## Compatibility alias for storage usage

dev-vm-ssh: ## Connect to the running VM via SSH
	$(call run-ravnvm,--ssh)

dev-vm-install-ssh-alias: ## Install the ssh ravnvm host alias
	$(call run-ravnvm,--install-ssh-alias)

dev-vm-external: ## Run an external repository (REPO=owner/name, REF=master)
	@printf "\n$(CYAN)🌐 dev-vm-external · external repository VM$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@if [ -z "$(REPO)" ] || [ "$(REPO)" = "RaVN" ]; then \
		printf "$(RED)  ✗ missing or invalid required argument$(NC)\n\n"; \
		printf "  usage:  $(BLUE)make dev-vm-external REPO=robert-flo/Valhalla REF=master$(NC)\n\n"; \
		printf "  REPO accepts owner/name or an HTTPS .git URL.\n\n"; \
		exit 2; \
	fi; \
	REPO_NAME=$$(basename "$(REPO)" .git); \
	printf "  $(BLUE)repository:$(NC) %s\n" "$(REPO)"; \
	printf "  $(BLUE)clone directory:$(NC) /home/arch/%s\n" "$$REPO_NAME"; \
	if [ "$(DRY_RUN)" = "1" ]; then \
		printf "  ▶ [dry-run] $(RAVNVM) --repo $(REPO) $(REF)\n"; \
	else \
		$(check-ravnvm); \
		if VM_MEMORY='$(VM_MEMORY)' VM_CPUS='$(VM_CPUS)' \
		VM_EXTRA_ARGS='$(value VM_EXTRA_ARGS)' VM_QEMU_OVERRIDE='$(value VM_QEMU_OVERRIDE)' \
		'$(RAVNVM)' --repo '$(REPO)' '$(REF)'; then \
			printf "$(GREEN)  ✓ external repository VM completed$(NC)\n"; \
		else \
			status=$$?; printf "$(RED)  ✗ external repository VM failed (exit $$status)$(NC)\n" >&2; exit $$status; \
		fi; \
	fi
	@printf "\n$(GREEN)  ✓ done$(NC)\n"
	@printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"
	@printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  • run default RaVN VM: $(BLUE)make dev-vm$(NC)\n"
	@printf "  • list snapshots:      $(BLUE)make dev-vm-list$(NC)\n\n"

dev-vm-setup: ## Check or install VM dependencies
	$(run-ravnvm-setup)

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
