#!/bin/bash
# Author  : Gaston Gonzalez
# Date    : 20 January 2025
# Updated : 4 February 2025
# Purpose : Run regedit
set -e

source ./common-checks.sh

echo -e "${YELLOW}"
echo -e "1. Expand HKEY_LOCAL_MACHINE > Software > Wine > Ports"
echo -e "2. In the main pain, right-click and select 'New' > 'String Value'"
echo -e "3. Set the name to ${WHITE}COM10${YELLOW} and the value to ${WHITE}/dev/et-cat${YELLOW}"
echo -e "4. Close the Registry Editor application"
echo -e "${NC}"

wine regedit
