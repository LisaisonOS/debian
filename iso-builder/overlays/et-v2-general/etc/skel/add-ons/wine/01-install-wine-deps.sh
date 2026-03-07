#!/bin/bash
# Author  : Gaston Gonzalez
# Date    : 20 January 2025
# Updated : 1 February 2025
# Purpose : Install wine dependencies to support VARA install
set -e

source ./common-checks.sh

if [[ ! -e ${WINEPREFIX} ]]; then
  winetricks \
    --unattended \
    --force \
    winxp \
    sound=alsa \
    dotnet35sp1 \
    vb6run

    if [[ $? -ne 0 ]]; then
      show-err-dialog "Failed to instaill WINE dependencies."
      exit 1
    fi 
else
  echo -e  "${WINEPREFIX} already exists. Skipping WINE dependency installation.\n"
fi

echo -e "${YELLOW}Run ${WHITE}./02-install-vara-hf.sh${YELLOW} to install VARA HF.${NC}"
