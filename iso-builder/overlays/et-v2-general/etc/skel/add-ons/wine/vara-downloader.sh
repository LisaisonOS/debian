#!/bin/bash
# Author  : Gaston Gonzalez
# Date    : 28 February 2025
# Purpose : Download utility for VARA applications

BASE_HTML_FILE="vara-index.html"

cleanup() {
  [[ -f "$BASE_HTML_FILE" ]] && rm "${BASE_HTML_FILE}"
}

trap cleanup EXIT

function usage() {
  echo "Usage: $(basename $0) <pattern>"
  echo "  pattern - VARA filename substring pattern to match on" 
}

if [ $# -ne 1 ]; then
  usage
  exit 1
fi

FILENAME_PATTERN="$1"
BASE_URL="https://downloads.winlink.org"
INDEX_URL="${BASE_URL}/VARA%20Products/"

# 1. Fetch main VARA download page as HTML
curl -s -f -L -o ${BASE_HTML_FILE} ${INDEX_URL}
[[ $? -ne 0 ]] && et-log "Error fetching VARA index page: ${BASE_URL}" && exit 1

# 2. Extract all links from index page
VARA_FILE_PATH=$(cat ${BASE_HTML_FILE} | pup 'a attr{href}' | grep "${FILENAME_PATTERN}")
[[ $? -ne 0 ]] && et-log "Error finding VARA file matching specified pattern" && exit 1


#3. Check for multiple matches
if [[ "${VARA_FILE_PATH}" =~ [[:space:]] ]]; then
 echo -e "\n${VARA_FILE_PATH}\n"
 et-log "Multiple files matched. Try again with a more specific pattern."
 exit 1
fi

FULL_URL="${BASE_URL}${VARA_FILE_PATH}"
et-log "Found ${VARA_FILE_PATH}"
et-log "Downloading: ${FULL_URL}"

curl -s -f -L -O "${FULL_URL}"
exit $?
