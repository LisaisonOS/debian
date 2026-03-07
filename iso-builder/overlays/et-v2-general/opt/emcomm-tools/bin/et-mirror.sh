#!/bin/bash
# Author   : Gaston Gonzalez
# Date     : 29 December 2024
# Purpose  : Mirrors a website for offline browsing

ET_OFFLINE_WWW_DIR="${HOME}/offline-www"

if [ $# -ne 1 ]; then
    echo "$(basename $) Usage: $0 <start-url>"
    exit 1
fi

if [ ! -e ${ET_OFFLINE_WWW_DIR} ]; then
  et-log "Creating offline web directory: ${ET_OFFLINE_WWW_DIR}"
  mkdir -v ${ET_OFFLINE_WWW_DIR}
fi

START_URL=$1

# Validate the URL format
if ! [[ $START_URL =~ ^https?:// ]]; then
    echo "Invalid URL. Provide a valid URL that starts with http:// or https://"
    exit 1
fi

DOMAIN_NAME=$(echo "$START_URL" | awk -F[/:] '{print $4}')

echo "Starting website mirroring..."

wget --mirror \
     --convert-links \
     --adjust-extension \
     --page-requisites \
     --no-parent \
     --directory-prefix="${ET_OFFLINE_WWW_DIR}" \
     "${START_URL}"

if [ $? -eq 0 ]; then
    echo "Website mirroring completed successfully."
    echo "Domain: ${DOMAIN_NAME}"
    echo "URL: ${START_URL}"
    echo "Output Directory: ${ET_OFFLINE_WWW_DIR}"
else
    echo "An error occurred while mirroring the website."
    exit 1
fi
