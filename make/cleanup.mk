# ═══════════════════════════════════════════════════════════════
# 🧹 CLEANUP AND OPTIMIZATION - Arch Linux System & Cache Cleanup
# ═══════════════════════════════════════════════════════════════
# 📚 Documentation: docs/src/content/docs/makefile/03-cleanup.mdx
# 🎯 Purpose: Clean package caches, system logs, Flatpaks, and VM states
# ──── Overview: 5 targets for system maintenance ────────────────
#
# 📎 Aliases & Targets:
#    ALIAS          TARGET                   DESCRIPTION
#    clean          sys-gc                   Clean system caches and logs (DAYS=30)
#    deep-clean     sys-purge                Aggressive cleanup (irreversible)
#    clean-vm       sys-clean-vm             Clean VM cache and snapshots
#    disk-repo      sys-disk-repo            Analyze repository space (ncdu)
#    disk-home      sys-disk-home            Analyze home directory space (ncdu)
#
# 🧪 Dry Run (preview without executing):
#    make sys-gc           DRY_RUN=1         · skip journalctl vacuum & paccache
#    make sys-purge        DRY_RUN=1         · skip system packages & cache purge
#    make sys-clean-vm     DRY_RUN=1         · skip VM cache and snapshot deletion
#    (sys-disk-repo, sys-disk-home are read-only)

.PHONY: sys-gc sys-purge sys-clean-vm sys-disk-repo sys-disk-home

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
# 🗑️ SYS-GC - Clean system logs and package caches (older than N days)
# ═══════════════════════════════════════════════════════════════
# ──── Flexible cleanup: DAYS=n (default 30) ───────────────────
# Usage: make sys-gc [DAYS=n]
DAYS ?= 30
sys-gc: ## Clean system caches and logs older than specified days
ifndef EMBEDDED
	@printf "\n"
	@if [ "$(DAYS)" -eq 7 ]; then \
		printf "$(CYAN)🧹 sys-gc · weekly (7 days)$(NC)\n"; \
	elif [ "$(DAYS)" -eq 30 ]; then \
		printf "$(CYAN)🧹 sys-gc · 30 days$(NC)\n"; \
	elif [ "$(DAYS)" -eq 90 ]; then \
		printf "$(CYAN)🧹 sys-gc · conservative (90 days)$(NC)\n"; \
	else \
		printf "$(CYAN)🧹 sys-gc · $(DAYS) days$(NC)\n"; \
	fi
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
endif
	@if [ "$(DAYS)" -lt 15 ]; then \
		printf "$(YELLOW)  ⚠  keeping only $(DAYS) days of history$(NC)\n"; \
	else \
		printf "  removing artifacts and logs older than $(DAYS) days...\n"; \
	fi
	@printf "\n"
	@printf "  [Arch Linux] cleaning system journal logs...\n"
	@$(EXEC) sudo journalctl --vacuum-time=$(DAYS)d
	@if command -v paccache >/dev/null 2>&1; then \
		printf "  [Arch Linux] cleaning pacman cache (keeping last 3 versions)...\n"; \
		$(EXEC) sudo paccache -r; \
	fi
ifndef EMBEDDED
	@printf "\n$(GREEN)  ✓ done$(NC)\n"
endif
	@printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"
	@printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  • analyze repository space: $(BLUE)make sys-disk-repo$(NC)\n"
	@printf "  • analyze home directory:   $(BLUE)make sys-disk-home$(NC)\n\n"


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
	@printf "    · all unused flatpak runtimes\n"
	@printf "    · systemd journal logs older than 3 days$(NC)\n"
	@printf "\n"
	@printf "$(RED)  type 'yes' to continue: $(NC)"; \
	read -r REPLY; \
	if [ "$$REPLY" = "yes" ]; then \
		if [ "$$DRY_RUN" = "1" ]; then \
			printf "\n$(YELLOW)  ▶ [dry-run] Would execute:$(NC)\n"; \
			printf "$(DIM)      sudo pacman -Scc\n"; \
			printf "      sudo pacman -Rns \$$(pacman -Qtdq)\n"; \
			printf "      sudo journalctl --vacuum-time=3d\n"; \
			if command -v yay >/dev/null 2>&1; then printf "      yay -Scc\n"; fi; \
			if command -v flatpak >/dev/null 2>&1; then printf "      flatpak uninstall --unused\n"; fi; \
			printf "      df -h /$(NC)\n"; \
		else \
			printf "\n  purging Arch Linux system caches...\n\n"; \
			sudo pacman -Scc --noconfirm; \
			if [ -n "$$(pacman -Qtdq)" ]; then \
				sudo pacman -Rns $$(pacman -Qtdq) --noconfirm || true; \
			fi; \
			if command -v yay >/dev/null 2>&1; then \
				yay -Scc --noconfirm; \
			elif command -v paru >/dev/null 2>&1; then \
				paru -Scc --noconfirm; \
			fi; \
			if command -v flatpak >/dev/null 2>&1; then \
				flatpak uninstall --unused -y; \
			fi; \
			sudo journalctl --vacuum-time=3d; \
			printf "\n  disk space summary:\n"; \
			df -h / | sed 's/^/  /'; \
			printf "\n$(GREEN)  ✓ done$(NC)\n"; \
		fi; \
		printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"; \
		printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"; \
		printf "  • check freed disk space: $(BLUE)make sys-disk-home$(NC)\n\n"; \
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
	@printf "  • clean pacman cache:     $(BLUE)make sys-gc$(NC)\n\n"


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
	@printf "  • clean system caches:    $(BLUE)make sys-gc$(NC)\n\n"
