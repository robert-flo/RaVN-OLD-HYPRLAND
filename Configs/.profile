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

# SSH Agent Environment
export SSH_AUTH_SOCK="${XDG_RUNTIME_DIR}/ssh-agent.socket"
