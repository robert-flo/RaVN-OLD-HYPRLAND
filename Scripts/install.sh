#!/usr/bin/env bash
# shellcheck disable=SC2154
#|---/ /+--------------------------+---/ /|#
#|--/ /-| Main installation script |--/ /-|#
#|-/ /--| Roberto Flores           |-/ /--|#
#|/ /---+--------------------------+/ /---|#

cat <<"EOF"

-----------------------------------------------------------
        .
       / \       _     ___   __ _ __   __ _   _ 
      /^  \    _| |_  | _ \ / _` |\ \ / /| \ | |
     /  _  \  |_   _| ||  /| (_| | \ V / |  \| |
    /  | | ~\   |_|   |_|_\ \__,_|  \_/  |_| \_|
   /.-'   '-.\

-----------------------------------------------------------

EOF

#--------------------------------#
# import variables and functions #
#--------------------------------#
scrDir="$(dirname "$(realpath "$0")")"
# shellcheck disable=SC1091
if ! source "${scrDir}/global_fn.sh"; then
	echo "Error: unable to source global_fn.sh..."
	exit 1
fi
