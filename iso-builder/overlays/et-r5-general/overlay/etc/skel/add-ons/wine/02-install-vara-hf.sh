#!/bin/bash
#
# Author  : Gaston Gonzalez
# Date    : 20 January 2025
# Updated : 28 February 2025
# Purpose : Install VARA HF

source ./common-checks.sh

VARA_HOME="${HOME}/.wine32/drive_c/VARA"
VARA_PATTERN="VARA%20HF"

./vara-downloader.sh "${VARA_PATTERN}"
[[ $? -ne 0 ]] && et-log "Error downloading VARA HF" && exit 1

DOWNLOAD_FILE=$(ls *.zip | grep "${VARA_PATTERN}")
[[ ! -e "${DOWNLOAD_FILE}" ]] && et-log "VARA download file not found" && exit 1

unzip -o ${DOWNLOAD_FILE}

wine 'VARA setup (Run as Administrator).exe'

if [ ! -e "${VARA_HOME}/nt4pdhdll.exe" ]; then
  et-log "Install missing DLL..."

  CWD=$(pwd)

  cd ${VARA_HOME}
  curl -s -f -L -O \
    http://download.microsoft.com/download/winntsrv40/update/5.0.2195.2668/nt4/en-us/nt4pdhdll.exe && unzip nt4pdhdll.exe
  cd ${CWD}
fi

echo -e "${YELLOW}Run ${WHITE}./03-install-vara-fm.sh${YELLOW} to install VARA FM.${NC}"
