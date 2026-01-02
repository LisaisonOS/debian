#!/bin/bash
# Author  : Gaston Gonzalez
# Date    : 16 August 2025
# Purpose : Fetch SSNs for VOACAP prediction

source /opt/emcomm-tools/bin/et-common

FILE="ssn.txt"
URL="https://www.sidc.be/silso/FORECASTS/prediML.txt"
curl -s -f -L -o ${FILE} ${URL}

if [[ $? -ne 0 ]]; then
  echo -e "${RED}Failed to update ${FILE} from: ${URL}."
  exit 1
fi
