# -----------------------------------------------------------------------------
# Yazi file picker integration
# -----------------------------------------------------------------------------

yazi_choose() {
  (( $+commands[yazi] )) || return 127

  local chooser_file yazi_status
  local -a selections

  chooser_file=$(mktemp -t yazi-chooser.XXXXXX) || return 1
  yazi --chooser-file="$chooser_file" > /dev/tty
  yazi_status=$?

  if [[ -s $chooser_file ]]; then
    selections=("${(@f)$(<"$chooser_file")}")
    LBUFFER+="${LBUFFER:+ }${(j: :)${(q)selections}}"
  fi

  rm -f -- "$chooser_file"
  zle redisplay
  return $yazi_status
}
zle -N yazi_choose

yazi_cd() {
  (( $+commands[yazi] )) || return 127

  local cwd_file cwd yazi_status

  cwd_file=$(mktemp -t yazi-cwd.XXXXXX) || return 1
  yazi --cwd-file="$cwd_file" > /dev/tty
  yazi_status=$?

  if [[ -s $cwd_file ]]; then
    IFS= read -r cwd < "$cwd_file"
    if [[ -d $cwd ]]; then
      builtin cd -- "$cwd" || yazi_status=$?
    fi
  fi

  rm -f -- "$cwd_file"
  zle reset-prompt
  return $yazi_status
}
zle -N yazi_cd
