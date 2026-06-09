#!/usr/bin/env sh
# Export Omarchy path for UWSM graphical session
export OMARCHY_PATH="$HOME/.local/share/omarchy"
case ":$PATH:" in
    *":$OMARCHY_PATH/bin:"*) ;;
    *) export PATH="$OMARCHY_PATH/bin:$PATH" ;;
esac
