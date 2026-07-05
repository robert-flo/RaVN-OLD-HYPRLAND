#!/usr/bin/env bash
# ─── RaVN Task: Emacs Paths ───────────────────────────────────────────────────
# Creates the on-disk files and directories that the Studium Emacs configuration
# expects to exist (~/org/, ~/$HOME/.local/share/gnus/, etc.) so that
# build-on-demand elisp (org-roam, universal-launcher bookmark parser,
# mail/mu4e, gnus) does not error out the first time a feature is used.

# shellcheck disable=SC2034
PACKAGE="emacs-paths"
DESCRIPTION="Bootstrap filesystem paths expected by Studium Emacs"
CATEGORY="system"
DEPENDS=()
INTERACTIVE=false

# Paths used by Studium Emacs. Keep in sync with ~/.config/emacs/lisp/**/*.el.
EMACS_PATHS=(
  "${HOME}/org"
  "${HOME}/org/roam"
  "${HOME}/org/bookmarks.org"
  "${HOME}/org/inbox.org"
  "${HOME}/org/calendar.org"
  "${HOME}/org/contacts.org"
  "${HOME}/org/notes.org"
  "${HOME}/org/caldav-inbox.org"
  "${HOME}/Library"
  "${HOME}/.local/share/gnus"
  "${HOME}/.config/age"
  "${HOME}/.config/scripts"
)

check() {
  local p
  for p in "${EMACS_PATHS[@]}"; do
    if [[ ! -e $p ]]; then
      return 1
    fi
  done
  return 0
}

install() {
  if ((flg_DryRun == 1)); then
    info "Simulación: Saltando creación de paths de Emacs."
    return 0
  fi

  info "Creando paths esperados por Studium Emacs..."

  local p dir
  for p in "${EMACS_PATHS[@]}"; do
    if [[ -e $p ]]; then
      continue
    fi

    # Heuristic: trailing 4 chars ".org" → file; everything else → directory.
    if [[ ${p: -4} == ".org" ]]; then
      dir="$(dirname "$p")"
      mkdir -p "$dir"
      : > "$p"
      success "Archivo creado: $p"
    else
      mkdir -p "$p"
      success "Directorio creado: $p"
    fi
  done

  # Seed bookmarks.org with an empty heading so org-element-map is happy
  # the first time the universal-launcher bookmark parser runs.
  if [[ -s ${HOME}/org/bookmarks.org ]]; then
    return 0
  fi
  cat <<'EOF' >"${HOME}/org/bookmarks.org"
* Bookmarks
EOF
  success "Seed inicial agregado a ~/org/bookmarks.org"
}
