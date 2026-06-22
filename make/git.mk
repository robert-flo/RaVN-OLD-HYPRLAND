# ═══════════════════════════════════════════════════════════════
# 🔀 GIT OPERATIONS - Version control and backup
# ═══════════════════════════════════════════════════════════════
# 📚 Documentation: docs/src/content/docs/makefile/06-git.mdx
# 🎯 Purpose: Stage, commit, push and inspect git repository state
# ──── Overview: 7 targets for the full git commit/push cycle ─
#
# 🧪 Dry Run (preview without executing):
#    make git-add     DRY_RUN=1   · skip git add
#    make git-commit  DRY_RUN=1   · skip git commit
#    make git-push    DRY_RUN=1   · skip git push
#    (git-status, git-diff, git-log are read-only)

DRY_RUN ?= 0
export DRY_RUN
ifeq ($(DRY_RUN),1)
  EXEC = echo "  ▶ [dry-run]"
else
  EXEC =
endif

RAVN_WTS_DIR ?= $(abspath $(RAVN_DIR)/..)

.PHONY: git-add git-commit git-add-commit git-push git-status git-diff git-log git-setup git-sync git-diff-dev git-diff-rc git-diff-here

# ═══════════════════════════════════════════════════════════════
# 💾 GIT-ADD - Stage all modified/new files for commit
# ═══════════════════════════════════════════════════════════════
# ──── Stage: Adds all modified/new files to the git index ────
git-add: ## Stage all changes for git
ifndef EMBEDDED
	@printf "\n"
	@printf "$(CYAN)💾 git-add · staging all changes$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
endif
	@CHANGED=$$(git status --short | wc -l); \
	if [ $$CHANGED -gt 0 ]; then \
		printf "  adding $$CHANGED file(s) to staging area...\n"; \
		$(EXEC) git add .; \
		printf "$(GREEN)  ✓ staged $$CHANGED file(s)$(NC)\n\n"; \
		git status --short | sed 's/^/  /'; \
	else \
		printf "$(GREEN)  ✓  nothing to stage — working tree is clean$(NC)\n"; \
	fi
ifndef EMBEDDED
	@printf "\n$(GREEN)  ✓ done$(NC)\n"
	@printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"
	@printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  • commit staged changes: $(BLUE)make git-commit$(NC)\n"
	@printf "  • stage and commit in one step: $(BLUE)make git-add-commit$(NC)\n"
	@printf "  • inspect what changed: $(BLUE)make git-diff$(NC)\n\n"
endif

# ═══════════════════════════════════════════════════════════════
# 📝 GIT-COMMIT - Create a timestamped commit from staged changes
# ═══════════════════════════════════════════════════════════════
# ──── Commit: Stages all and creates commit with timestamp ───
git-commit: ## Quick commit with timestamp
ifndef EMBEDDED
	@printf "\n"
	@printf "$(CYAN)📝 git-commit · timestamped snapshot$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
endif
	@if [ -n "$$(git status --porcelain)" ]; then \
		printf "  staging changes...\n"; \
		$(EXEC) git add .; \
		COMMIT_MSG="config: update $$(date '+%Y-%m-%d %H:%M:%S')"; \
		printf "  commit: $(GREEN)$$COMMIT_MSG$(NC)\n\n"; \
		$(EXEC) git commit -m "$$COMMIT_MSG" || exit 1; \
		COMMIT_HASH=$$(git rev-parse --short HEAD); \
		BRANCH=$$(git branch --show-current); \
		printf "$(GREEN)  ✓ $(NC)$(DIM)$$COMMIT_HASH$(NC)  $$BRANCH\n"; \
	else \
		printf "$(GREEN)  ✓  nothing to commit — working tree is clean$(NC)\n"; \
	fi
ifndef EMBEDDED
	@printf "\n$(GREEN)  ✓ done$(NC)\n"
	@printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"
	@printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  • push to remote: $(BLUE)make git-push$(NC)\n"
	@printf "  • view recent history: $(BLUE)make git-log$(NC)\n"
	@printf "  • check repo state:     $(BLUE)make git-status$(NC)\n\n"
endif

# ═══════════════════════════════════════════════════════════════
# 🔗 GIT-ADD-COMMIT - Stage and commit all changes in one step
# ═══════════════════════════════════════════════════════════════
# ──── Composite: Calls git-add then git-commit with EMBEDDED=1 ─
git-add-commit: ## Stage and commit all changes together
	@$(MAKE) -s git-add EMBEDDED=1
	@$(MAKE) -s git-commit EMBEDDED=1
ifndef EMBEDDED
	@printf "\n$(GREEN)  ✓ done$(NC)\n"
	@printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"
	@printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  • push to remote: $(BLUE)make git-push$(NC)\n"
	@printf "  • check repo state:     $(BLUE)make git-status$(NC)\n"
	@printf "  • view recent history: $(BLUE)make git-log$(NC)\n\n"
endif

# ═══════════════════════════════════════════════════════════════
# ☁️  GIT-PUSH - Sync local commits to remote repository
# ═══════════════════════════════════════════════════════════════
# ──── Push: Sends unpushed commits to origin via git push ────
git-push: ## Push to remote
ifndef EMBEDDED
	@printf "\n"
	@printf "$(CYAN)☁️  git-push · sync to remote$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
endif
	@BRANCH=$$(git branch --show-current); \
	REMOTE=$$(git remote get-url origin 2>/dev/null | sed -E 's|.*github.com[:/]([^/]+/[^/]+)(\.git)?$$|\1|' | sed 's|\.git$$||'); \
	printf "  $(DIM)branch:$(NC) $$BRANCH  $(DIM)remote:$(NC) $$REMOTE\n"; \
	if git rev-parse --verify --quiet refs/remotes/origin/$$BRANCH >/dev/null 2>&1; then \
		UNPUSHED=$$(git log origin/$$BRANCH..HEAD --oneline 2>/dev/null | wc -l); \
		if [ $$UNPUSHED -gt 0 ]; then \
			printf "\n  pushing $$UNPUSHED commit(s)...\n"; \
			$(EXEC) git push || exit 1; \
			printf "$(GREEN)  ✓ pushed to remote$(NC)\n"; \
		else \
			printf "$(GREEN)  ✓  everything up-to-date$(NC)\n"; \
		fi; \
	else \
		printf "\n  pushing new branch $$BRANCH to remote...\n"; \
		$(EXEC) git push || exit 1; \
		printf "$(GREEN)  ✓ pushed to remote$(NC)\n"; \
	fi
ifndef EMBEDDED
	@printf "\n$(GREEN)  ✓ done$(NC)\n"
	@printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"
	@printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  • verify remote history: $(BLUE)make git-log$(NC)\n"
	@printf "  • check repo state: $(BLUE)make git-status$(NC)\n"
	@printf "  • apply system after push: $(BLUE)make sys-apply$(NC)\n\n"
endif

# ═══════════════════════════════════════════════════════════════
# 📊 GIT-STATUS - Show repository state and recent commits
# ═══════════════════════════════════════════════════════════════
# ──── Status: Branch, remote, local changes, last 3 commits ─
git-status: ## Show current repository state
ifndef EMBEDDED
	@printf "\n"
	@printf "$(CYAN)📊 git-status · repository overview$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
endif
	@printf "  $(DIM)host:$(NC)  $(HOSTNAME)  $(DIM)flake:$(NC) $(PWD)\n"
	@printf "  $(DIM)nixos:$(NC) $$(nixos-version 2>/dev/null | cut -d' ' -f1 || echo 'N/A')\n\n"
	@if git rev-parse --git-dir > /dev/null 2>&1; then \
		REMOTE_URL=$$(git remote get-url origin 2>/dev/null); \
		REPO_NAME=$$(echo "$$REMOTE_URL" | sed -E 's|.*github.com[:/]([^/]+/[^/]+)(\.git)?$$|\1|' | sed 's|\.git$$||'); \
		BRANCH=$$(git branch --show-current); \
		AHEAD=$$(git rev-list --count @{u}..HEAD 2>/dev/null || echo 0); \
		BEHIND=$$(git rev-list --count HEAD..@{u} 2>/dev/null || echo 0); \
		STAGED=$$(git diff --cached --name-only 2>/dev/null | wc -l | tr -d ' '); \
		UNSTAGED=$$(git diff --name-only 2>/dev/null | wc -l | tr -d ' '); \
		UNTRACKED=$$(git ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' '); \
		printf "  $(DIM)repo:$(NC)   $$REPO_NAME\n"; \
		printf "  $(DIM)branch:$(NC) $$BRANCH"; \
		if [ "$$AHEAD" -gt 0 ] && [ "$$BEHIND" -gt 0 ]; then \
			printf "  $(YELLOW)⇕ ↑$$AHEAD ↓$$BEHIND$(NC)"; \
		elif [ "$$AHEAD" -gt 0 ]; then \
			printf "  $(YELLOW)↑ $$AHEAD ahead$(NC)"; \
		elif [ "$$BEHIND" -gt 0 ]; then \
			printf "  $(RED)↓ $$BEHIND behind$(NC)"; \
		fi; \
		printf "\n\n"; \
		if [ "$$STAGED" -eq 0 ] && [ "$$UNSTAGED" -eq 0 ] && [ "$$UNTRACKED" -eq 0 ]; then \
			printf "  $(GREEN)✓ nothing to commit — working tree clean$(NC)\n"; \
			printf "\n"; \
		else \
			if [ "$$STAGED" -gt 0 ]; then \
				printf "  $(GREEN)staged:$(NC)    $$STAGED file(s)\n"; \
				git diff --cached --name-only 2>/dev/null | while IFS= read -r f; do printf "    $(GREEN)+$(NC) $$f\n"; done; \
				printf "\n"; \
			fi; \
			if [ "$$UNSTAGED" -gt 0 ]; then \
				printf "  $(YELLOW)modified:$(NC)  $$UNSTAGED file(s)\n"; \
				git diff --name-only 2>/dev/null | while IFS= read -r f; do printf "    $(YELLOW)~$(NC) $$f\n"; done; \
				printf "\n"; \
			fi; \
			if [ "$$UNTRACKED" -gt 0 ]; then \
				printf "  $(DIM)untracked:$(NC) $$UNTRACKED file(s)\n"; \
				git ls-files --others --exclude-standard 2>/dev/null | while IFS= read -r f; do printf "    $(DIM)?$(NC) $$f\n"; done; \
				printf "\n"; \
			fi; \
		fi; \
		printf "  $(DIM)recent commits:$(NC)\n"; \
		git --no-pager log --max-count=5 --pretty=format:"  %C(green)%h%C(reset)  %<(50,trunc)%s  %C(dim)%<(15)%ar%C(reset)" 2>/dev/null; \
		printf "\n"; \
	else \
		printf "$(YELLOW)  ⚠  not a git repository$(NC)\n"; \
	fi
ifndef EMBEDDED
	@printf "\n$(GREEN)  ✓ done$(NC)\n"
	@printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"
	@printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  • stage and commit: $(BLUE)make git-add-commit$(NC)\n"
	@printf "  • push changes:     $(BLUE)make git-push$(NC)\n"
	@printf "  • full history:     $(BLUE)make git-log$(NC)\n\n"
endif

# ═══════════════════════════════════════════════════════════════
# 🔄 GIT-DIFF - Show uncommitted changes in the repository
# ═══════════════════════════════════════════════════════════════
# ──── Diff: All repository files — summary and full detail ────
git-diff: ## Show uncommitted changes in the repository
ifndef EMBEDDED
	@printf "\n"
	@printf "$(CYAN)🔄 git-diff · repository changes$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
endif
	@if git diff --quiet 2>/dev/null; then \
		printf "$(GREEN)  ✓ no uncommitted changes in repository$(NC)\n"; \
	else \
		if command -v hunk >/dev/null 2>&1; then \
			hunk diff; \
		else \
			git diff --color=always 2>/dev/null || git diff; \
		fi; \
		printf "\n"; \
		CHANGED_FILES=$$(git diff --name-only 2>/dev/null | wc -l); \
		ADDED_LINES=$$(git diff --numstat 2>/dev/null | awk '{sum+=$$1} END {print sum+0}'); \
		DELETED_LINES=$$(git diff --numstat 2>/dev/null | awk '{sum+=$$2} END {print sum+0}'); \
		printf "  $(DIM)files:$(NC) $$CHANGED_FILES  $(GREEN)+$$ADDED_LINES$(NC)  $(RED)-$$DELETED_LINES$(NC)\n\n"; \
		git --no-pager diff --stat --color=always 2>/dev/null || git --no-pager diff --stat; \
		printf "\n"; \
	fi
ifndef EMBEDDED
	@printf "\n$(GREEN)  ✓ done$(NC)\n"
	@printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"
	@printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  • stage and commit: $(BLUE)make git-add-commit$(NC)\n"
	@printf "  • validate scripts: $(BLUE)make fmt-lint$(NC)\n"
	@printf "  • test in RavnVM:   $(BLUE)make dev-vm$(NC)\n\n"
endif

# ═══════════════════════════════════════════════════════════════
# 📜 GIT-LOG - Show recent commit history
# ═══════════════════════════════════════════════════════════════
# ──── Log: Last 15 commits — short hash, message, age ────────
git-log: ## Show recent commit history
ifndef EMBEDDED
	@printf "\n"
	@printf "$(CYAN)📜 git-log · recent history$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
endif
	@if git rev-parse --git-dir > /dev/null 2>&1; then \
		git --no-pager log --max-count=15 --pretty=format:"  %C(green)%h%C(reset)  %<(58,trunc)%s  %C(dim)%<(15)%ar%C(reset)" 2>/dev/null; \
	else \
		printf "$(YELLOW)  ⚠  not a git repository$(NC)\n"; \
	fi
	@printf "\n"

# ═══════════════════════════════════════════════════════════════
# 🚀 GIT-SETUP - Clone a repo and create all worktrees ready to push
# ═══════════════════════════════════════════════════════════════
# ──── Setup: bare clone + all worktrees + upstream tracking ──
# ──── Usage: make git-setup REPO=git@github.com:user/repo.git ─
#
# Locations (can be overridden via environment variables):
#   Bare objects:  $$BARE_HOME/<repo>       (default: ~/.local/share/git-bare/<repo>)
#   Worktrees:     $$WORKTREES_HOME/<repo>  (default: ~/Work/<repo>)
git-setup: ## Clone a repo as bare + create all worktrees with upstream (use REPO=url)
	@printf "\n"
	@printf "$(CYAN)🚀 git-setup · bare clone + worktrees$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@if [ -z "$(REPO)" ] || [ "$(REPO)" = "RaVN" ]; then \
		printf "$(RED)  ✗ missing or invalid required argument$(NC)\n\n"; \
		printf "  usage:  $(BLUE)make git-setup REPO=git@github.com:robert-flo/RaVN.git$(NC)\n\n"; \
		printf "  override locations:\n"; \
		printf "    $(DIM)BARE_HOME$(NC)       bare objects dir   (default: $(DIM)~/.local/share/git-bare$(NC))\n"; \
		printf "    $(DIM)WORKTREES_HOME$(NC)  worktrees base dir (default: $(DIM)~/Work$(NC))\n\n"; \
		exit 1; \
	fi; \
	if command -v git-bare-clone >/dev/null 2>&1; then \
		SCRIPT="git-bare-clone"; \
	elif [ -f "Configs/.local/bin/git-bare-clone" ]; then \
		SCRIPT="./Configs/.local/bin/git-bare-clone"; \
	else \
		SCRIPT=""; \
	fi; \
	if [ -z "$$SCRIPT" ]; then \
		printf "$(RED)  ✗ git-bare-clone not found$(NC)\n\n"; \
		printf "  It should be present at Configs/.local/bin/git-bare-clone\n"; \
		printf "  Ensure the file exists and is executable.\n\n"; \
		exit 1; \
	fi; \
	if [ "$$DRY_RUN" = "1" ]; then \
		printf "  ▶ [dry-run] $$SCRIPT $(REPO)\n"; \
	else \
		$$SCRIPT $(REPO); \
	fi
	@printf "\n$(GREEN)  ✓ done$(NC)\n"
	@REPO_NAME=$$(basename "$(REPO)" .git); \
	WTHOME=$${WORKTREES_HOME:-$$HOME/Work}; \
	printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"; \
	printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"; \
	printf "  • enter a worktree:  $(BLUE)cd $$WTHOME/$$REPO_NAME/<branch>$(NC)\n"; \
	printf "  • check git status:  $(BLUE)make git-status$(NC)\n\n"

# ═══════════════════════════════════════════════════════════════
# 🔄 GIT-SYNC - Rebase all topic branches from dev
# ═══════════════════════════════════════════════════════════════
# ──── Sync: rebase each branch from origin/dev (local only) ───
# ──── Usage: make git-sync [REPO=name] ────────────────────────
#
# Branches synced: Dynamically detected from ~/Work/<repo>/
# Branches EXCLUDED: dev master rc (protected/base branches)
#
# Override worktrees location:
#   WORKTREES_HOME=~/Projects make git-sync REPO=RaVN
REPO ?= RaVN
git-sync: ## Update all topic branches from dev (local only, default REPO=RaVN)
	@printf "\n"
	@printf "$(CYAN)🔄 git-sync · update all topic branches from dev$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@if [ -z "$(REPO)" ]; then \
		printf "$(RED)  ✗ missing required argument$(NC)\n\n"; \
		printf "  usage:  $(BLUE)make git-sync REPO=RaVN$(NC)\n\n"; \
		printf "  override location:\n"; \
		printf "    $(DIM)WORKTREES_HOME$(NC)  worktrees base dir (default: $(DIM)~/Work$(NC))\n\n"; \
		exit 1; \
	fi
	@WTHOME=$${WORKTREES_HOME:-$$HOME/Work}; \
	REPO_DIR="$$WTHOME/$(REPO)"; \
	if [ ! -d "$$REPO_DIR" ]; then \
		printf "$(RED)  ✗ worktrees directory not found$(NC)\n\n"; \
		printf "  looked in:  $(DIM)$$REPO_DIR$(NC)\n\n"; \
		if [ -n "$$WORKTREES_HOME" ]; then \
			printf "  $(YELLOW)WORKTREES_HOME$(NC) is set to $(DIM)$$WORKTREES_HOME$(NC)\n"; \
			printf "  make sure $(BLUE)$(REPO)$(NC) worktrees exist there\n\n"; \
		else \
			printf "  $(DIM)WORKTREES_HOME$(NC) is not set — defaulting to $(DIM)~/Work$(NC)\n\n"; \
			printf "  if your worktrees are elsewhere, override:\n"; \
			printf "    $(BLUE)WORKTREES_HOME=<path> make git-sync REPO=$(REPO)$(NC)\n\n"; \
			printf "  if the repo is not cloned yet:\n"; \
			printf "    $(BLUE)make git-setup REPO=git@github.com:<user>/$(REPO).git$(NC)\n\n"; \
		fi; \
		exit 1; \
	fi; \
	FAILED=""; \
	for branch_dir in "$$REPO_DIR"/*; do \
		[ -d "$$branch_dir" ] || continue; \
		[ -e "$$branch_dir/.git" ] || continue; \
		branch=$$(basename "$$branch_dir"); \
		if [ "$$branch" = "dev" ] || [ "$$branch" = "master" ] || [ "$$branch" = "rc" ] || [ "$$branch" = "imgbot" ]; then \
			continue; \
		fi; \
		printf "  syncing $(BLUE)$$branch$(NC) ..."; \
		is_dirty=$$(git -C "$$branch_dir" status --porcelain 2>/dev/null); \
		err_log=$$(git -C "$$branch_dir" pull --rebase --autostash origin dev 2>&1); \
		if [ $$? -eq 0 ]; then \
			if [ -n "$$is_dirty" ]; then \
				printf " $(GREEN)✓$(NC) $(DIM)(autostashed)$(NC)\n"; \
			else \
				printf " $(GREEN)✓$(NC)\n"; \
			fi; \
		else \
			if echo "$$err_log" | grep -q "Conflict"; then \
				printf " $(RED)✗  rebase conflict$(NC)\n"; \
			else \
				printf " $(RED)✗  rebase failed: $$(echo "$$err_log" | head -n 1)$(NC)\n"; \
			fi; \
			git -C "$$branch_dir" rebase --abort > /dev/null 2>&1 || true; \
			FAILED="$$FAILED $$branch"; \
		fi; \
	done; \
	printf "\n$(DIM)  dev, master, rc, imgbot: skipped (protected/base branches)$(NC)\n"; \
	if [ -n "$$FAILED" ]; then \
		printf "\n$(RED)  ✗ failed:$$FAILED$(NC)\n"; \
		printf "  resolve conflicts manually with:\n"; \
		for f in $$FAILED; do \
			printf "  $(BLUE)git -C $$REPO_DIR/$$f pull --rebase origin dev$(NC)\n"; \
		done; \
		printf "\n"; \
	else \
		printf "\n$(GREEN)  ✓ all branches synced locally$(NC)\n"; \
	fi
	@printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"
	@printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  • verify status: $(BLUE)make git-status$(NC)\n"
	@printf "  • view history:  $(BLUE)make git-log$(NC)\n\n"

# ═══════════════════════════════════════════════════════════════
# 🔄 GIT-DIFF-DEV - Compare dev worktree against rc worktree
# ═══════════════════════════════════════════════════════════════
# ──── Diff: Compare dev against rc using hunk patch ──────────
git-diff-dev: ## Compare dev worktree against rc
ifndef EMBEDDED
	@printf "\n"
	@printf "$(CYAN)🔄 git-diff-dev · compare dev against rc$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
endif
	@if [ -d "$(RAVN_WTS_DIR)/rc" ] && [ -d "$(RAVN_WTS_DIR)/dev" ]; then \
		printf "  comparing dev against rc...\n"; \
		if command -v hunk >/dev/null 2>&1; then \
			git diff --no-index "$(RAVN_WTS_DIR)/rc/" "$(RAVN_WTS_DIR)/dev/" | hunk patch; \
		else \
			git diff --no-index --color=always "$(RAVN_WTS_DIR)/rc/" "$(RAVN_WTS_DIR)/dev/" 2>/dev/null || git diff --no-index "$(RAVN_WTS_DIR)/rc/" "$(RAVN_WTS_DIR)/dev/"; \
		fi; \
	else \
		printf "$(RED)  ✗ dev or rc worktree directory not found$(NC)\n"; \
		exit 1; \
	fi
ifndef EMBEDDED
	@printf "\n$(GREEN)  ✓ done$(NC)\n"
	@printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"
	@printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  • compare rc against master:            $(BLUE)make git-diff-rc$(NC)\n"
	@printf "  • compare current worktree against dev: $(BLUE)make git-diff-here$(NC)\n\n"
endif

# ═══════════════════════════════════════════════════════════════
# 🔄 GIT-DIFF-RC - Compare rc worktree against master worktree
# ═══════════════════════════════════════════════════════════════
# ──── Diff: Compare rc against master using hunk patch ────────
git-diff-rc: ## Compare rc worktree against master
ifndef EMBEDDED
	@printf "\n"
	@printf "$(CYAN)🔄 git-diff-rc · compare rc against master$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
endif
	@if [ -d "$(RAVN_WTS_DIR)/master" ] && [ -d "$(RAVN_WTS_DIR)/rc" ]; then \
		printf "  comparing rc against master...\n"; \
		if command -v hunk >/dev/null 2>&1; then \
			git diff --no-index "$(RAVN_WTS_DIR)/master/" "$(RAVN_WTS_DIR)/rc/" | hunk patch; \
		else \
			git diff --no-index --color=always "$(RAVN_WTS_DIR)/master/" "$(RAVN_WTS_DIR)/rc/" 2>/dev/null || git diff --no-index "$(RAVN_WTS_DIR)/master/" "$(RAVN_WTS_DIR)/rc/"; \
		fi; \
	else \
		printf "$(RED)  ✗ rc or master worktree directory not found$(NC)\n"; \
		exit 1; \
	fi
ifndef EMBEDDED
	@printf "\n$(GREEN)  ✓ done$(NC)\n"
	@printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"
	@printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  • compare dev against rc:               $(BLUE)make git-diff-dev$(NC)\n"
	@printf "  • compare current worktree against dev: $(BLUE)make git-diff-here$(NC)\n\n"
endif

# ═══════════════════════════════════════════════════════════════
# 🔄 GIT-DIFF-HERE - Compare current worktree against dev worktree
# ═══════════════════════════════════════════════════════════════
# ──── Diff: Compare current worktree against dev using hunk ───
git-diff-here: ## Compare current worktree against dev
ifndef EMBEDDED
	@printf "\n"
	@printf "$(CYAN)🔄 git-diff-here · compare current worktree against dev$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
endif
	@if [ -d "$(RAVN_WTS_DIR)/dev" ] && [ -d "$(abspath $(RAVN_DIR))" ]; then \
		printf "  comparing current worktree against dev...\n"; \
		if command -v hunk >/dev/null 2>&1; then \
			git diff --no-index "$(RAVN_WTS_DIR)/dev/" "$(abspath $(RAVN_DIR))/" | hunk patch; \
		else \
			git diff --no-index --color=always "$(RAVN_WTS_DIR)/dev/" "$(abspath $(RAVN_DIR))/" 2>/dev/null || git diff --no-index "$(RAVN_WTS_DIR)/dev/" "$(abspath $(RAVN_DIR))/"; \
		fi; \
	else \
		printf "$(RED)  ✗ dev or current worktree directory not found$(NC)\n"; \
		exit 1; \
	fi
ifndef EMBEDDED
	@printf "\n$(GREEN)  ✓ done$(NC)\n"
	@printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"
	@printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  • compare dev against rc:    $(BLUE)make git-diff-dev$(NC)\n"
	@printf "  • compare rc against master: $(BLUE)make git-diff-rc$(NC)\n\n"
endif
