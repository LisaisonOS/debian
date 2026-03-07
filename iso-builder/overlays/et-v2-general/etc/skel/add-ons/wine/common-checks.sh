#!/bin/bash
# Author  : Gaston Gonzalez
# Date    : 1 February 2025
# Updated : 18 March 2025
# Purpose : Performs various checks to ensure that changes can be made
#           to a user's local WINE installation.

source /opt/emcomm-tools/bin/et-common

WINE_OUT=$(which winetricks)
if [[ $? -ne 0 ]]; then
  echo -e "${RED}Wine is not installed. As root, first run: ${WHITE}/root/emcomm-tools-os-community/scripts/install-wine.sh${NC}"
  exit 1
fi

if [[ "${EUID}" -eq 0 ]]; then
  echo -e "${RED}This script must not be run as root. Run it as your normal user.${NC}"
  exit 1
fi

if [[ -z "${WINEARCH}" ]]; then
  echo -e "The WINEARCH environment variable is not set. Setting it for you."
  export WINEARCH="win64"
fi

if [[ -z "${WINEPREFIX}" ]]; then
  echo -e "The WINEPREFIX environment variable is not set. Setting it for you."
  export WINEPREFIX="${HOME}/.wine32"
fi

if [[ -z "${DISPLAY}" && -z "${WAYLAND_DISPLAY}" ]]; then
  echo -e "${RED}No graphical environment detected. Run this command from a desktop session.${NC}"
  echo -e "${RED}This can't be run from within Cubic.${NC}"
  exit 1
fi
