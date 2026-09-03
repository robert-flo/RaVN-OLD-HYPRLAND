# ═══════════════════════════════════════════════════════════════
# 🔧 RAVN MANAGEMENT MAKEFILE - SYSTEM AUTOMATION TOOLKIT
# ═══════════════════════════════════════════════════════════════
# 📚 Documentation: docs/makefile/
# 🎯 Purpose: Provide comprehensive management commands for RaVN
# 🔄 Workflow: Format/Lint → Test in RavnVM → Deploy / Restore Configurations
# Place this in the root of your RaVN worktree
# ----------------------------------------------------------------------------

# ═══════════════════════════════════════════════════════════════
# 🎯 DEFAULT TARGET - Show help when no target specified
# ═══════════════════════════════════════════════════════════════

.DEFAULT_GOAL := help

# ═══════════════════════════════════════════════════════════════
# ⚙️ CONFIGURATION - Root of the RaVN workspace
# ═══════════════════════════════════════════════════════════════

# ──── RaVN Directory: Root of the repository ──────────────────
RAVN_DIR := .
SCRIPTS_DIR := $(RAVN_DIR)/Scripts
CONFIGS_DIR := $(RAVN_DIR)/Configs

# ═══════════════════════════════════════════════════════════════
# 🚀 PERFORMANCE OPTIONS - Optimized options
# ═══════════════════════════════════════════════════════════════

# Keep these in case some nix/virtualization commands need them
NIX_OPTS := \
	--option download-buffer-size 5245245245 \
	--option http-connections 16 \
	--option cores 0 \
	--option max-jobs auto

# ═══════════════════════════════════════════════════════════════
# 🎨 OUTPUT FORMATTING - ANSI color codes for visual feedback
# ═══════════════════════════════════════════════════════════════

RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[0;33m
BLUE := \033[0;34m
PURPLE := \033[0;35m
CYAN := \033[0;36m
DIM := \033[2m
BOLD := \033[1m
NC := \033[0m # No Color

# ═══════════════════════════════════════════════════════════════
# 📦 INCLUDE ORDER - Critical for dependency resolution
# ═══════════════════════════════════════════════════════════════

include make/docs.mk
include make/system.mk
include make/cleanup.mk
include make/updates.mk
include make/generations.mk
include make/git.mk
include make/logs.mk
include make/dev.mk
include make/omarchy.mk
include make/format.mk
include make/aliases.mk
