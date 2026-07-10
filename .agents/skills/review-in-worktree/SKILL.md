---
name: review-in-worktree
description: Review and prepare existing repository changes for a production PR. Use when invoked from dev with uncommitted work that must move to a temporary worktree, or from an existing topic branch that needs a strict review, atomic commits, push, and an approved PR to dev.
---

# Review Existing Changes in a Worktree

Read the root `AGENTS.md` and every applicable nested `AGENTS.md` before inspecting or changing files. Follow their repository-specific rules throughout.

Preserve all changes. Never reset, discard, overwrite, squash, or delete user work, commits, stashes, branches, or worktrees.

## Establish the review scope

1. Inspect the current branch, worktree status, untracked files, and the diff against `origin/dev`.
2. If there are no local changes and the current branch contributes no commits beyond `origin/dev`, report that there are no changes to review. Do not create a branch, worktree, commit, push, or PR.
3. If the current branch is not `dev`, stay in the current worktree. Review the complete PR diff against `origin/dev`, including existing commits and uncommitted changes.
4. If the current branch is `dev`, move the work to a new temporary worktree:
   1. Fetch `origin` so `origin/dev` is current.
   2. Save all tracked and untracked changes in a recoverable stash. Do not include ignored files.
   3. Derive a short, meaningful worktree name from the detected changes without asking the user to name it.
   4. Create the worktree with `$HOME/.local/bin/git-create-worktree`, based on `origin/dev`, using `-B origin/dev -N` so it does not publish an empty branch.
   5. Restore the stash in the new worktree.
   6. Once restoration succeeds, leave the original `dev` worktree clean.

If restoring the stash conflicts, fails, or leaves ambiguity, stop. Preserve the stash and all worktrees, report the exact state and affected files, and wait for the user to resolve it manually. Do not commit, push, or create a PR.

## Production review

Apply this criterion explicitly:

> Review this repository as if you are blocking or approving a production PR.

Review the complete change set and its surrounding code for correctness, regressions, security risks, architectural violations, missing tests, weak error handling, maintainability problems, and inconsistencies with repository conventions.

Run the relevant tests, linters, formatters, type checks, builds, and repository-specific validation tools. Apply only mechanical, deterministic corrections produced by those tools, such as formatter output. Re-run the relevant checks after each correction.

Do not make functional, architectural, dependency, configuration, or test-design changes without first presenting the finding and waiting for the user's direction. Do not introduce unrelated refactors.

If a finding requires the user's direction, report it with evidence, emit `REQUEST CHANGES`, and stop. Preserve the branch and worktree so the user can continue there and invoke this skill again.

## Commit gate

When the review findings are resolved and validations are satisfactory, propose an atomic commit plan. Include the files in each commit, the purpose of the commit, and the validation that applies to it.

Wait for the user's explicit approval before staging or creating commits.

After approval, create atomic commits. Each commit must:

- Represent one coherent and independently understandable change.
- Include directly required tests or documentation.
- Avoid mixing unrelated refactors, fixes, tests, documentation, or formatting.
- Use a clear, imperative, focused message.
- Leave the repository in a valid and reviewable state whenever reasonably possible.

Before every commit:

1. Inspect the staged diff.
2. Confirm that only files for that atomic change are staged.
3. Run the relevant validation.
4. Commit only when the staged change is internally consistent.

## Final verdict and publication

Inspect the final branch diff and commit history, then re-run the relevant validations.

- Emit `APPROVE` only when all relevant validations pass and no unresolved findings remain.
- Emit `REQUEST CHANGES` when further work is needed and requires the user's direction.
- Emit `BLOCK` when an external dependency, required access, or high-risk unresolved issue prevents safe completion.

For `REQUEST CHANGES` or `BLOCK`, do not push or create a PR. Preserve the branch and worktree, explain what the user must do next, and wait for a later invocation.

For `APPROVE`, push the branch and create a non-draft PR to `dev` with `gh`. Derive a concise title from the primary change. Write a detailed PR body containing:

- Functional summary.
- Affected files or areas.
- Atomic commits included.
- Validations executed and their results.
- Production-review verdict.
- Risks or follow-up work, when any exist.

If the push or PR creation fails, preserve all work, report the exact failure, and emit `BLOCK`. Do not rewrite history or retry aggressively.

## Final report

Report the worktree path, branch name, files changed, atomic commits with hashes and messages, validations and results, unresolved risks or follow-up work, PR URL when created, and the final verdict.
