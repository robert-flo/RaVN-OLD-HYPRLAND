# ═══════════════════════════════════════════════════════════════
# 🔃 UPDATES - System & Developer Package Updates
# ═══════════════════════════════════════════════════════════════
# 📚 Documentation: docs/src/content/docs/makefile/04-updates.mdx
# 🎯 Purpose: Update core system, AUR helper, Flatpak, snaps, global NPM, and Mise packages
# ──── Overview: 7 targets for system package updates ──────────
#
# 📎 Aliases & Targets:
#    ALIAS           TARGET                  DESCRIPTION
#    update-all      upd-all                 Update all package managers in sequence
#    update-core     upd-core                Update Arch Linux core packages (pacman)
#    update-aur      upd-aur                 Update AUR packages using yay or paru
#    update-flatpak  upd-flatpak             Update Flatpak packages and runtimes
#    update-snaps    upd-snaps               Update snap packages
#    update-npm      upd-npm                 Update global NPM packages
#    update-mise     upd-mise                Update mise self-update & managed tools
#
# 🧪 Dry Run (preview without executing):
#    make upd-all            DRY_RUN=1       · skip execution of all updates
#    make upd-core           DRY_RUN=1       · skip system upgrade
#    make upd-aur            DRY_RUN=1       · skip AUR package upgrade
#    make upd-flatpak        DRY_RUN=1       · skip Flatpak upgrade
#    make upd-snaps          DRY_RUN=1       · skip snap package upgrade
#    make upd-npm            DRY_RUN=1       · skip global npm package upgrade
#    make upd-mise           DRY_RUN=1       · skip mise self-update & tool upgrades

.PHONY: upd-all upd-core upd-aur upd-flatpak upd-snaps upd-npm upd-mise

# ──── Dry Run: make <target> DRY_RUN=1 to preview without executing ─
DRY_RUN ?= 0
export DRY_RUN
ifeq ($(DRY_RUN),1)
  EXEC = echo "  ▶ [dry-run]"
else
  EXEC =
endif

# === System and Package Updates ===

# ═══════════════════════════════════════════════════════════════
# 🔄 UPD-ALL - Update all package managers in sequence
# ═══════════════════════════════════════════════════════════════
# ──── Run: sequential invocation of all sub-updates ───────────
upd-all: ## Update all packages (Core, AUR, Flatpak, Snaps, NPM, Mise)
ifndef EMBEDDED
	@printf "\n"
	@printf "$(CYAN)🔄 upd-all · update all packages$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
endif
	@$(MAKE) --no-print-directory EMBEDDED=1 upd-core
	@$(MAKE) --no-print-directory EMBEDDED=1 upd-aur
	@$(MAKE) --no-print-directory EMBEDDED=1 upd-flatpak
	@$(MAKE) --no-print-directory EMBEDDED=1 upd-snaps
	@$(MAKE) --no-print-directory EMBEDDED=1 upd-npm
	@$(MAKE) --no-print-directory EMBEDDED=1 upd-mise
ifndef EMBEDDED
	@printf "\n$(GREEN)  ✓ done$(NC)\n"
endif
	@printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"
	@printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  • clean system caches: $(BLUE)make clean$(NC)\n\n"

# ═══════════════════════════════════════════════════════════════
# 📦 UPD-CORE - Update Arch Linux core packages (pacman)
# ═══════════════════════════════════════════════════════════════
# ──── Core: Run pacman system upgrade ─────────────────────────
upd-core: ## Update Arch Linux core packages (pacman)
ifndef EMBEDDED
	@printf "\n"
	@printf "$(CYAN)📦 upd-core · update core system packages$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
endif
	@printf "  updating system repositories and upgrading packages...\n"
	@$(EXEC) sudo pacman -Syu --noconfirm
ifndef EMBEDDED
	@printf "\n$(GREEN)  ✓ done$(NC)\n"
endif
	@printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"
	@printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  • update aur packages: $(BLUE)make upd-aur$(NC)\n"
	@printf "  • clean system caches:  $(BLUE)make clean$(NC)\n\n"

# ═══════════════════════════════════════════════════════════════
# 📦 UPD-AUR - Update AUR packages using yay or paru
# ═══════════════════════════════════════════════════════════════
# ──── AUR: Run AUR helper upgrade ─────────────────────────────
upd-aur: ## Update AUR packages using yay or paru
ifndef EMBEDDED
	@printf "\n"
	@printf "$(CYAN)📦 upd-aur · update aur packages$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
endif
	@if command -v yay >/dev/null 2>&1; then \
		printf "  updating AUR packages using yay...\n"; \
		$(EXEC) yay -Sua --noconfirm; \
	elif command -v paru >/dev/null 2>&1; then \
		printf "  updating AUR packages using paru...\n"; \
		$(EXEC) paru -Sua --noconfirm; \
	else \
		printf "$(YELLOW)  ⚠  neither yay nor paru is installed. skipping AUR updates.$(NC)\n"; \
	fi
ifndef EMBEDDED
	@printf "\n$(GREEN)  ✓ done$(NC)\n"
endif
	@printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"
	@printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  • update core packages: $(BLUE)make upd-core$(NC)\n"
	@printf "  • clean system caches:  $(BLUE)make clean$(NC)\n\n"

# ═══════════════════════════════════════════════════════════════
# 📦 UPD-FLATPAK - Update Flatpak packages and runtimes
# ═══════════════════════════════════════════════════════════════
# ──── Flatpak: Run flatpak update ─────────────────────────────
upd-flatpak: ## Update Flatpak packages and runtimes
ifndef EMBEDDED
	@printf "\n"
	@printf "$(CYAN)📦 upd-flatpak · update flatpak packages$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
endif
	@if command -v flatpak >/dev/null 2>&1; then \
		printf "  updating Flatpak packages and runtimes...\n"; \
		$(EXEC) flatpak update -y; \
	else \
		printf "$(DIM)  flatpak is not installed. skipping flatpak updates.$(NC)\n"; \
	fi
ifndef EMBEDDED
	@printf "\n$(GREEN)  ✓ done$(NC)\n"
endif
	@printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"
	@printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  • clean flatpak cache: $(BLUE)make clean$(NC)\n\n"

# ═══════════════════════════════════════════════════════════════
# 📦 UPD-SNAPS - Update snap packages
# ═══════════════════════════════════════════════════════════════
# ──── Snaps: Run snap refresh ─────────────────────────────────
upd-snaps: ## Update snap packages
ifndef EMBEDDED
	@printf "\n"
	@printf "$(CYAN)📦 upd-snaps · update snap packages$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
endif
	@if command -v snap >/dev/null 2>&1; then \
		printf "  refreshing snap packages...\n"; \
		$(EXEC) sudo snap refresh; \
	else \
		printf "$(DIM)  snap is not installed. skipping snap updates.$(NC)\n"; \
	fi
ifndef EMBEDDED
	@printf "\n$(GREEN)  ✓ done$(NC)\n"
endif
	@printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"
	@printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  • check snap list: $(BLUE)snap list$(NC)\n\n"

# ═══════════════════════════════════════════════════════════════
# 📦 UPD-NPM - Update global npm packages
# ═══════════════════════════════════════════════════════════════
# ──── NPM: Run npm update -g ──────────────────────────────────
upd-npm: ## Update global npm packages
ifndef EMBEDDED
	@printf "\n"
	@printf "$(CYAN)📦 upd-npm · update global npm packages$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
endif
	@if command -v npm >/dev/null 2>&1; then \
		printf "  updating global npm packages...\n"; \
		$(EXEC) npm update -g; \
	else \
		printf "$(DIM)  npm is not installed. skipping npm updates.$(NC)\n"; \
	fi
ifndef EMBEDDED
	@printf "\n$(GREEN)  ✓ done$(NC)\n"
endif
	@printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"
	@printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  • list global npm packages: $(BLUE)npm list -g --depth=0$(NC)\n\n"

# ═══════════════════════════════════════════════════════════════
# 📦 UPD-MISE - Update mise and managed tools
# ═══════════════════════════════════════════════════════════════
# ──── Mise: Run self-update and upgrade tools ──────────────────
upd-mise: ## Update mise and its managed tools
ifndef EMBEDDED
	@printf "\n"
	@printf "$(CYAN)📦 upd-mise · update mise and managed tools$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
endif
	@if command -v mise >/dev/null 2>&1; then \
		printf "  self-updating mise...\n"; \
		$(EXEC) mise self-update -y || true; \
		printf "  upgrading mise managed tools...\n"; \
		$(EXEC) mise upgrade; \
	else \
		printf "$(DIM)  mise is not installed. skipping mise updates.$(NC)\n"; \
	fi
ifndef EMBEDDED
	@printf "\n$(GREEN)  ✓ done$(NC)\n"
endif
	@printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"
	@printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  • check mise status: $(BLUE)mise doctor$(NC)\n\n"
