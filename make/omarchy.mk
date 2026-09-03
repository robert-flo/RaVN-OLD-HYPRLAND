# ═══════════════════════════════════════════════════════════════
# 🖥️  OMARCHYVM - Unattended Omarchy installer and VM runner
# ═══════════════════════════════════════════════════════════════
# 📚 Documentation: Scripts/omarchyvm/README.md
# 🎯 Purpose: Install Omarchy unattended (ISO + cidata) and run it in QEMU
# ──── Overview: targets for the complete OmarchyVM workflow ───
#
# 📎 Targets:
#    dev-omarchy                  Run the installed system (ephemeral)
#    dev-omarchy-persist          Run the installed system (persistent)
#    dev-omarchy-rebuild          (Re)install Omarchy unattended, cache the base
#    dev-omarchy-list             List cached snapshots
#    dev-omarchy-clean            Clean snapshots and temporary data (keeps ISO)
#    dev-omarchy-setup            Check or install host dependencies
#    dev-omarchy-storage          Show cache and filesystem usage
#    dev-omarchy-ssh              Connect to the running VM via SSH
#    dev-omarchy-install-ssh-alias  Install the ssh omarchyvm host alias
#
# 🧪 Dry Run (preview without executing):
#    make dev-omarchy             DRY_RUN=1   · preview the run
#    make dev-omarchy-rebuild     DRY_RUN=1   · preview the rebuild
#    (list and storage targets are read-only and always execute)
# 💡 Usage Examples:
#    make dev-omarchy                    · run the installed system
#    make dev-omarchy-persist            · run with persistent changes
#    make dev-omarchy-rebuild            · fresh unattended install
#    make dev-omarchy-rebuild OMARCHY_ISO_VERSION=4.0.2
#    make dev-omarchy OMARCHY_VM_MEMORY=16G OMARCHY_VM_CPUS=8
#    make dev-omarchy-ssh                · SSH into the running VM

OMARCHYVM ?= $(SCRIPTS_DIR)/omarchyvm/omarchyvm.sh
OMARCHY_ISO_VERSION ?= 4.0.2
OMARCHY_SSH_PORT ?= 2223
# NOTE: named OMARCHY_VM_* (not VM_*) — make/dev.mk already defines VM_MEMORY
# and VM_CPUS with `?=`, so reusing those names would silently keep ravnvm's
# 4G/2 defaults here. They are forwarded as VM_MEMORY/VM_CPUS to the script.
OMARCHY_VM_MEMORY ?= 8G
OMARCHY_VM_CPUS ?= 4
VM_EXTRA_ARGS ?=
DRY_RUN ?= 0
define check-omarchyvm
	if case '$(OMARCHYVM)' in */*) [ -x '$(OMARCHYVM)' ];; *) command -v '$(OMARCHYVM)' >/dev/null 2>&1;; esac; then \
		:; \
	else \
		printf "$(RED)  ✗ OmarchyVM executable not found or not executable:$(NC) %s\n" '$(OMARCHYVM)' >&2; \
		printf "  set OMARCHYVM=/path/to/omarchyvm.sh or define SCRIPTS_DIR correctly\n" >&2; \
		printf "  expected default: %s/omarchyvm/omarchyvm.sh\n" '$(SCRIPTS_DIR)' >&2; \
		exit 127; \
	fi
endef

define run-omarchyvm
	@if [ "$(DRY_RUN)" = "1" ]; then \
		printf "  ▶ [dry-run] OMARCHY_ISO_VERSION='%s' OMARCHY_SSH_PORT='%s' VM_MEMORY='%s' VM_CPUS='%s' %s%s\n" \
			'$(OMARCHY_ISO_VERSION)' '$(OMARCHY_SSH_PORT)' '$(OMARCHY_VM_MEMORY)' '$(OMARCHY_VM_CPUS)' '$(OMARCHYVM)' ' $(1)'; \
		printf "$(GREEN)  ✓ dry-run complete$(NC)\n"; \
	else \
		$(check-omarchyvm); \
		if OMARCHY_ISO_VERSION='$(OMARCHY_ISO_VERSION)' OMARCHY_SSH_PORT='$(OMARCHY_SSH_PORT)' \
		VM_MEMORY='$(OMARCHY_VM_MEMORY)' VM_CPUS='$(OMARCHY_VM_CPUS)' \
		VM_EXTRA_ARGS='$(value VM_EXTRA_ARGS)' \
		'$(OMARCHYVM)' $(1); then \
			printf "$(GREEN)  ✓ OmarchyVM operation completed$(NC)\n"; \
		else \
			status=$$?; \
			printf "$(RED)  ✗ OmarchyVM operation failed (exit $$status)$(NC)\n" >&2; \
			exit $$status; \
		fi; \
	fi; \
	printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"; \
	printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"; \
	printf "  • list snapshots: $(BLUE)make dev-omarchy-list$(NC)\n"; \
	printf "  • check VM dependencies: $(BLUE)make dev-omarchy-setup$(NC)\n\n"
endef

define run-omarchyvm-readonly
	@$(check-omarchyvm); \
	if OMARCHY_ISO_VERSION='$(OMARCHY_ISO_VERSION)' OMARCHY_SSH_PORT='$(OMARCHY_SSH_PORT)' \
	VM_MEMORY='$(OMARCHY_VM_MEMORY)' VM_CPUS='$(OMARCHY_VM_CPUS)' \
	'$(OMARCHYVM)' $(1); then \
		printf "$(GREEN)  ✓ OmarchyVM query completed$(NC)\n"; \
	else \
		status=$$?; \
		printf "$(RED)  ✗ OmarchyVM query failed (exit $$status)$(NC)\n" >&2; \
		exit $$status; \
	fi; \
	printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"; \
	printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"; \
	printf "  • run the installed system:  $(BLUE)make dev-omarchy$(NC)\n"; \
	printf "  • rebuild the base:    $(BLUE)make dev-omarchy-rebuild$(NC)\n\n"
endef

define run-omarchyvm-setup
	@if [ "$(DRY_RUN)" = "1" ]; then \
		printf '  ▶ [dry-run] %s --check-deps\n' '$(OMARCHYVM)'; \
		printf '  ▶ [dry-run] %s --install-deps\n' '$(OMARCHYVM)'; \
		printf "$(GREEN)  ✓ dry-run complete$(NC)\n"; \
	else \
		$(check-omarchyvm); \
		if '$(OMARCHYVM)' --check-deps; then \
			printf "$(GREEN)  ✓ VM dependencies are ready$(NC)\n"; \
		else \
			printf "  dependencies missing; attempting installation...\n"; \
			if '$(OMARCHYVM)' --install-deps; then \
				printf "  verifying installed dependencies...\n"; \
				if '$(OMARCHYVM)' --check-deps; then \
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
	printf "  • run the installed system:  $(BLUE)make dev-omarchy$(NC)\n"; \
	printf "  • rebuild the base:  $(BLUE)make dev-omarchy-rebuild$(NC)\n\n"

endef

help-omarchyvm: ## Show the OmarchyVM targets
	@printf '$(CYAN)OmarchyVM targets$(NC)\n'
	@printf '  make dev-omarchy            Run the installed system (ephemeral)\n'
	@printf '  make dev-omarchy-persist    Run with persistent changes\n'
	@printf '  make dev-omarchy-rebuild    Fresh unattended install, cache the base\n'
	@printf '  make dev-omarchy-list       List cached snapshots\n'
	@printf '  make dev-omarchy-clean      Clean snapshots and cache (keeps ISO)\n'
	@printf '  make dev-omarchy-setup      Check or install VM dependencies\n'
	@printf '  make dev-omarchy-storage    Show OmarchyVM storage usage\n'
	@printf '  make dev-omarchy-ssh        Connect to the running VM via SSH\n'
	@printf '  make dev-omarchy-install-ssh-alias  Install the ssh omarchyvm host alias\n'
	@printf '\nSet DRY_RUN=1 to print commands without executing OmarchyVM.\n'

dev-omarchy: ## Run the installed system (ephemeral)
	$(call run-omarchyvm,)

dev-omarchy-persist: ## Run the installed system (persistent)
	$(call run-omarchyvm,--persist)

dev-omarchy-rebuild: ## Fresh unattended install, cache the base
	$(call run-omarchyvm,--rebuild)

dev-omarchy-list: ## List cached snapshots
	$(call run-omarchyvm-readonly,--list)

dev-omarchy-storage: ## Show OmarchyVM storage usage
	$(call run-omarchyvm-readonly,--storage)

dev-omarchy-ssh: ## Connect to the running VM via SSH
	$(call run-omarchyvm,--ssh)

dev-omarchy-install-ssh-alias: ## Install the ssh omarchyvm host alias
	$(call run-omarchyvm,--install-ssh-alias)

dev-omarchy-clean: ## Clean snapshots and temporary cache data (keeps ISO)
	@$(check-omarchyvm); \
	CACHE_DIR="$${XDG_CACHE_HOME:-$$HOME/.cache}/omarchyvm"; \
	TMP=$$(mktemp); trap 'rm -f "$$TMP"' EXIT; \
	if [ -d "$$CACHE_DIR" ]; then \
		find "$$CACHE_DIR" -mindepth 1 -maxdepth 1 ! -name 'omarchy-*.iso' ! -name session.lock -print > "$$TMP"; \
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
			if '$(OMARCHYVM)' --clean; then \
				printf "$(GREEN)  ✓ OmarchyVM cache cleaned$(NC)\n"; \
			else \
				status=$$?; printf "$(RED)  ✗ OmarchyVM cache cleanup failed (exit $$status)$(NC)\n" >&2; exit $$status; \
			fi ;; \
		*) printf "  cleanup cancelled; no changes made\n" ;; esac; \
	fi; \
	printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"; \
	printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"; \
	printf "  • list snapshots: $(BLUE)make dev-omarchy-list$(NC)\n"; \
	printf "  • run the installed system: $(BLUE)make dev-omarchy$(NC)\n\n"

dev-omarchy-setup: ## Check or install VM dependencies
	$(run-omarchyvm-setup)
