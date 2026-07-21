#!/usr/bin/env bash
# ─── RaVN Task: Emacs Paths ─────────────────────────────────────────────────
# Bootstraps filesystem paths expected by Studium Emacs so that
# build-on-demand elisp (org-roam, universal-launcher, mu4e, gnus)
# does not error the first time a feature is used.

# shellcheck disable=SC2034
ADMIN_TASK_ID="emacs-paths"
# shellcheck disable=SC2034
ADMIN_TASK_FAMILY="system-config"
# shellcheck disable=SC2034
ADMIN_EXECUTION_PROFILE="user-config"
# shellcheck disable=SC2034
ADMIN_REQUIRES_PRIVILEGE=false
# shellcheck disable=SC2034
ADMIN_OWNED_RESOURCES=("${HOME}/org/" "${HOME}/org/roam/" "${HOME}/org/bookmarks.org" "${HOME}/org/inbox.org" "${HOME}/org/calendar.org" "${HOME}/org/contacts.org" "${HOME}/org/notes.org" "${HOME}/org/caldav-inbox.org" "${HOME}/Library" "${HOME}/.local/share/gnus" "${HOME}/.config/age" "${HOME}/.config/scripts")
# shellcheck disable=SC2034
ADMIN_RESOURCE_CONFLICTS=()
# shellcheck disable=SC2034
ADMIN_REVERSIBILITY="reversible"
# shellcheck disable=SC2034
ADMIN_ACTIVATION_BOUNDARY="next Emacs session"
# shellcheck disable=SC2034
ADMIN_TEST_LEVEL="isolated,docker"

readonly EMACS_ORG_FILES=(
  "${HOME}/org/bookmarks.org"
  "${HOME}/org/inbox.org"
  "${HOME}/org/calendar.org"
  "${HOME}/org/contacts.org"
  "${HOME}/org/notes.org"
  "${HOME}/org/caldav-inbox.org"
)

readonly EMACS_DIRECTORIES=(
  "${HOME}/org"
  "${HOME}/org/roam"
  "${HOME}/Library"
  "${HOME}/.local/share/gnus"
  "${HOME}/.config/age"
  "${HOME}/.config/scripts"
)
EMACS_CREATED_FILES=()

_path_exists() {
  [[ -e $1 ]]
}

admin_plan() {
  ADMIN_PLAN_ACTIONS=(
    "create emacs directories"
    "create emacs seed org files"
    "seed bookmarks.org with empty heading"
  )
  return 0
}

admin_apply() {
  admin_plan || return 1

  for dir in "${EMACS_DIRECTORIES[@]}"; do
    _path_exists "$dir" || mkdir -p "$dir" || return 1
  done

  for org_file in "${EMACS_ORG_FILES[@]}"; do
    if ! _path_exists "$org_file"; then
      mkdir -p "$(dirname "$org_file")"
      : > "$org_file"
      EMACS_CREATED_FILES+=("$org_file")
    fi
  done

  if [[ ! -s ${HOME}/org/bookmarks.org ]]; then
    cat << 'EOF' > "${HOME}/org/bookmarks.org"
* Bookmarks
EOF
  fi
}

admin_verify() {
  for dir in "${EMACS_DIRECTORIES[@]}"; do
    _path_exists "$dir" || return 1
  done
  for org_file in "${EMACS_CREATED_FILES[@]}"; do
    _path_exists "$org_file" || return 1
  done
  [[ -s ${HOME}/org/bookmarks.org ]] || return 1
  return 0
}

admin_rollback() {
  admin_reset
}

admin_reset() {
  admin_plan || return 1

  for org_file in "${EMACS_ORG_FILES[@]}"; do
    _path_exists "$org_file" && rm -f "$org_file" || true
  done

  for dir in "${EMACS_DIRECTORIES[@]}"; do
    _path_exists "$dir" && rmdir --ignore-fail-on-non-empty "$dir" 2> /dev/null || true
  done

  return 0
}

admin_verify_reset() {
  for org_file in "${EMACS_CREATED_FILES[@]}"; do
    _path_exists "$org_file" && return 1
  done
  return 0
}

check() { admin_verify; }
install() { admin_apply; }
verify() { admin_verify; }
reset() { admin_reset; }
verify_reset() { admin_verify_reset; }
