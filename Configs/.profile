# ~/.profile
# Shared environment configuration for bash and zsh

export OMARCHY_PATH="$HOME/.local/share/omarchy"

# Añadir a PATH solo si no está presente para evitar duplicados
case ":$PATH:" in
    *":$OMARCHY_PATH/bin:"*) ;;
    *) export PATH="$OMARCHY_PATH/bin:$PATH" ;;
esac

case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) export PATH="$HOME/.local/bin:$PATH" ;;
esac

# SSH Agent Environment Integration
if [ -z "${SSH_AUTH_SOCK}" ]; then
  # 1. Prefer systemd-managed user socket if active or enabled
  if systemctl --user is-active --quiet ssh-agent.socket 2>/dev/null || systemctl --user is-enabled --quiet ssh-agent.socket 2>/dev/null; then
    export SSH_AUTH_SOCK="${XDG_RUNTIME_DIR}/ssh-agent.socket"
  # 2. Check if a traditional ssh-agent is already running for this user
  elif pgrep -u "$USER" -x ssh-agent >/dev/null 2>&1; then
    _agent_socket=$(find /tmp -type s -user "$USER" -name "agent.*" 2>/dev/null | head -n 1)
    if [ -n "$_agent_socket" ]; then
      export SSH_AUTH_SOCK="$_agent_socket"
    else
      eval "$(ssh-agent -s)" >/dev/null
    fi
    unset _agent_socket
  # 3. Spawn a new agent if none is running
  else
    eval "$(ssh-agent -s)" >/dev/null
  fi
fi
