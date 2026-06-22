# ═══════════════════════════════════════════════════════════════
# 🧹 CLEANUP AND OPTIMIZATION - Arch Linux System & Cache Cleanup
# ═══════════════════════════════════════════════════════════════
# 📚 Documentation: docs/src/content/docs/makefile/03-cleanup.mdx
# 🎯 Purpose: Clean package caches, system logs, Flatpaks, and VM states
# ──── Overview: 5 targets for system maintenance ────────────────
#
# 📎 Aliases & Targets:
#    ALIAS          TARGET                   DESCRIPTION
#    clean          sys-purge                Deep clean all system and user caches
#    scvm           sys-clean-vm             Clean VM cache and snapshots
#    sdr            sys-disk-repo            Analyze repository space (ncdu)
#    sdh            sys-disk-home            Analyze home directory space (ncdu)
#
# 🧪 Dry Run (preview without executing):
#    make sys-purge        DRY_RUN=1         · skip system packages & cache purge
#    make sys-clean-vm     DRY_RUN=1         · skip VM cache and snapshot deletion
#    (sys-disk-repo, sys-disk-home are read-only)

.PHONY: sys-purge sys-clean-vm sys-disk-repo sys-disk-home

# ──── Dry Run: make <target> DRY_RUN=1 to preview without executing ─
DRY_RUN ?= 0
export DRY_RUN
ifeq ($(DRY_RUN),1)
  EXEC = echo "  ▶ [dry-run]"
else
  EXEC =
endif

# === Maintenance and Optimization ===




# ═══════════════════════════════════════════════════════════════
# 🗑️  SYS-PURGE - Deep clean all system caches (IRREVERSIBLE)
# ═══════════════════════════════════════════════════════════════
# ──── Deep Purge: Requires typed confirmation; no rollback possible ─
sys-purge: ## Aggressive cleanup (removes ALL old packages and caches)
ifndef EMBEDDED
	@printf "\n"
	@printf "$(RED)🗑️  sys-purge · irreversible$(NC)\n"
	@printf "$(RED)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
endif
	@printf "$(RED)  ⚠  deletes ALL cached packages and system logs — no rollback possible$(NC)\n"
	@printf "\n"
	@printf "$(YELLOW)  what gets deleted:$(NC)\n"
	@printf "$(DIM)    [Arch Linux]\n"
	@printf "    · all cached packages (pacman & AUR)\n"
	@printf "    · all unused orphan packages\n"
	@printf "    · all unused flatpak runtimes & flatpak user cache\n"
	@printf "    · AUR clone & build directories (yay/paru)\n"
	@printf "    · systemd journal logs & coredumps\n"
	@printf "    · user thumbnail cache & trash bin\n"
	@printf "    · developer package manager caches (npm, pip, go, cargo)$(NC)\n"
	@printf "\n"
	@printf "$(RED)  type 'yes' to continue: $(NC)"; \
	read -r REPLY; \
	if [ "$$REPLY" = "yes" ]; then \
		if [ "$$DRY_RUN" = "1" ]; then \
			printf "\n$(YELLOW)  ▶ [dry-run] Would execute:$(NC)\n"; \
			printf "$(DIM)      sudo pacman -Scc\n"; \
			printf "      sudo pacman -Rns \$$(pacman -Qtdq)\n"; \
			if command -v yay >/dev/null 2>&1; then printf "      yay -Scc\n"; fi; \
			if command -v paru >/dev/null 2>&1; then printf "      paru -Scc\n"; fi; \
			printf "      rm -rf ~/.cache/yay/* ~/.cache/paru/*\n"; \
			if command -v flatpak >/dev/null 2>&1; then printf "      flatpak uninstall --unused -y\n"; fi; \
			printf "      rm -rf ~/.cache/flatpak/* ~/.cache/thumbnails/* ~/.local/share/Trash/*\n"; \
			printf "      sudo journalctl --vacuum-time=3d\n"; \
			printf "      sudo rm -rf /var/lib/systemd/coredump/*\n"; \
			printf "      sudo find /var/log -type f -name \"*.gz\" -delete\n"; \
			printf "      sudo find /var/log -type f -name \"*.1\" -delete\n"; \
			printf "      rm -rf ~/.cache/pip/* ~/.npm/* ~/.cache/go-build/*\n"; \
			printf "      rm -rf ~/.cargo/registry/cache/* ~/.cargo/git/db/*\n"; \
			printf "      df -h /$(NC)\n"; \
		else \
			printf "\n  purging Arch Linux system caches...\n\n"; \
			START_FREE=$$(df -P / ~ | tail -n +2 | awk '{print $$1, $$4}' | sort -u | awk '{sum += $$2} END {print sum}'); \
			printf "  [pacman] cleaning package cache...\n"; \
			sudo pacman -Scc --noconfirm; \
			if [ -n "$$(pacman -Qtdq)" ]; then \
				printf "  [pacman] removing orphan packages...\n"; \
				sudo pacman -Rns $$(pacman -Qtdq) --noconfirm || true; \
			fi; \
			if command -v yay >/dev/null 2>&1; then \
				printf "  [yay] cleaning package cache...\n"; \
				yay -Scc --noconfirm || true; \
			fi; \
			if command -v paru >/dev/null 2>&1; then \
				printf "  [paru] cleaning package cache...\n"; \
				paru -Scc --noconfirm || true; \
			fi; \
			printf "  [AUR] removing build caches...\n"; \
			rm -rf ~/.cache/yay/* ~/.cache/paru/*; \
			if command -v flatpak >/dev/null 2>&1; then \
				printf "  [flatpak] removing unused runtimes & cache...\n"; \
				flatpak uninstall --unused -y || true; \
				rm -rf ~/.cache/flatpak/*; \
			fi; \
			printf "  [system] vacuuming journal logs and coredumps...\n"; \
			sudo journalctl --vacuum-time=3d || true; \
			sudo rm -rf /var/lib/systemd/coredump/*; \
			sudo find /var/log -type f -name "*.gz" -delete 2>/dev/null || true; \
			sudo find /var/log -type f -name "*.1" -delete 2>/dev/null || true; \
			printf "  [user] cleaning thumbnail cache & trash...\n"; \
			rm -rf ~/.cache/thumbnails/*; \
			rm -rf ~/.local/share/Trash/*; \
			printf "  [dev] cleaning package manager caches...\n"; \
			[ -d ~/.cache/pip ] && rm -rf ~/.cache/pip/*; \
			[ -d ~/.npm ] && rm -rf ~/.npm/*; \
			[ -d ~/.cache/go-build ] && rm -rf ~/.cache/go-build/*; \
			[ -d ~/.cargo ] && rm -rf ~/.cargo/registry/cache/* ~/.cargo/git/db/*; \
			[ -d ~/.cache/ccache ] && rm -rf ~/.cache/ccache/*; \
			END_FREE=$$(df -P / ~ | tail -n +2 | awk '{print $$1, $$4}' | sort -u | awk '{sum += $$2} END {print sum}'); \
			RECOVERED=$$(awk -v k=$$(($$END_FREE - $$START_FREE)) 'BEGIN { \
				if (k <= 0) { print "0 B"; exit } \
				if (k < 1024) { printf "%d KB\n", k; exit } \
				m = k / 1024; \
				if (m < 1024) { printf "%.2f MB\n", m; exit } \
				g = m / 1024; \
				printf "%.2f GB\n", g; \
			}'); \
			printf "\n$(GREEN)  ✓ done · recovered space: $$RECOVERED$(NC)\n"; \
		fi; \
		printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"; \
		printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"; \
		printf "  • check home directory space: $(BLUE)make sys-disk-home$(NC)\n\n"; \
	else \
		printf "\n$(DIM)  cancelled — no changes made$(NC)\n\n"; \
	fi


# ═══════════════════════════════════════════════════════════════
# 🧹 SYS-CLEAN-VM - Remove all VM cache and snapshots
# ═══════════════════════════════════════════════════════════════
# ──── Clean VM: Deletes ravnvm snapshots and images ──────────
sys-clean-vm: ## Clean VM cache and snapshots
ifndef EMBEDDED
	@printf "\n"
	@printf "$(CYAN)🧹 sys-clean-vm · remove all vm cache and snapshots$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
endif
	@if [ "$$DRY_RUN" = "1" ]; then \
		printf "  ▶ [dry-run] Scripts/ravnvm/ravnvm.sh --clean\n"; \
	else \
		if [ -f "Scripts/ravnvm/ravnvm.sh" ]; then \
			Scripts/ravnvm/ravnvm.sh --clean; \
		else \
			printf "$(RED)  ✗ Scripts/ravnvm/ravnvm.sh not found$(NC)\n"; \
		fi; \
	fi
ifndef EMBEDDED
	@printf "\n$(GREEN)  ✓ done$(NC)\n"
endif
	@printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"
	@printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  • check vm size:  $(BLUE)make dev-vm-size$(NC)\n"
	@printf "  • list vm status: $(BLUE)make dev-vm-list$(NC)\n\n"


# ═══════════════════════════════════════════════════════════════
# 🧹 SYS-DISK-REPO - Analyze repository disk usage with ncdu
# ═══════════════════════════════════════════════════════════════
# ──── Disk Repo: Interactive space analysis of this repository ────
sys-disk-repo: ## Analyze repository disk usage with ncdu
ifndef EMBEDDED
	@printf "\n"
	@printf "$(CYAN)🧹 sys-disk-repo · analyze repository space$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
endif
	@if command -v ncdu >/dev/null 2>&1; then \
		ncdu .; \
	else \
		printf "$(RED)  ✗ ncdu is not installed$(NC)\n"; \
		printf "  install it with: $(BLUE)sudo pacman -S ncdu$(NC)\n"; \
	fi
ifndef EMBEDDED
	@printf "\n$(GREEN)  ✓ done$(NC)\n"
endif
	@printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"
	@printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  • analyze home directory: $(BLUE)make sys-disk-home$(NC)\n"
	@printf "  • clean system caches:    $(BLUE)make clean$(NC)\n\n"


# ═══════════════════════════════════════════════════════════════
# 🧹 SYS-DISK-HOME - Analyze HOME directory disk usage with ncdu
# ═══════════════════════════════════════════════════════════════
# ──── Disk HOME: Interactive space analysis of the home folder ───
sys-disk-home: ## Analyze HOME directory disk usage with ncdu
ifndef EMBEDDED
	@printf "\n"
	@printf "$(CYAN)🧹 sys-disk-home · analyze home space$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
endif
	@if command -v ncdu >/dev/null 2>&1; then \
		ncdu -x ~; \
	else \
		printf "$(RED)  ✗ ncdu is not installed$(NC)\n"; \
		printf "  install it with: $(BLUE)sudo pacman -S ncdu$(NC)\n"; \
	fi
ifndef EMBEDDED
	@printf "\n$(GREEN)  ✓ done$(NC)\n"
endif
	@printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"
	@printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  • analyze repository:     $(BLUE)make sys-disk-repo$(NC)\n"
	@printf "  • clean system caches:    $(BLUE)make clean$(NC)\n\n"
