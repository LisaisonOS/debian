#!/bin/bash
# Author   : Sylvain Deguire (VA2OPS)
# Date     : 4 December 2025
# Purpose  : Download Wikipedia ZIM files for offline use with Kiwix
#            Dynamically parses Kiwix repository for latest versions
# Requires : curl, dialog

set -e

URL="https://download.kiwix.org/zim/wikipedia/"
HTML_FILE="/tmp/kiwix-wikipedia-listing.html"
ZIM_DIR="${HOME}/wikipedia"

# Supported languages
LANGUAGES="en|fr"

# Ensure destination directory exists
mkdir -p "${ZIM_DIR}"

cleanup() {
    rm -f "${HTML_FILE}"
}
trap cleanup EXIT

echo "Fetching Wikipedia ZIM file listing..."
curl -s -L -f -o "${HTML_FILE}" "${URL}"

if [[ ! -s "${HTML_FILE}" ]]; then
    echo "Error: Could not download file listing from ${URL}"
    exit 1
fi

# Extract all .zim files for supported languages with their sizes
# Filter: wikipedia_en_* or wikipedia_fr_*
# Directory listing format: <a href="file.zim">file.zim</a>  date  size
declare -A FILE_SIZES

while IFS= read -r line; do
    if [[ "$line" =~ wikipedia_(${LANGUAGES})[^\"]*.zim ]]; then
        file=$(echo "$line" | grep -oE "wikipedia_(${LANGUAGES})[^\"]*\.zim" | head -1)
        # Extract size - typically last column, formats: 1.5G, 500M, 100K
        size=$(echo "$line" | grep -oE '[0-9]+(\.[0-9]+)?[KMGTP]' | tail -1)
        if [[ -n "$file" && -n "$size" ]]; then
            FILE_SIZES[$file]="$size"
        fi
    fi
done < "${HTML_FILE}"

if [[ ${#FILE_SIZES[@]} -eq 0 ]]; then
    echo "Error: No ZIM files found for languages: ${LANGUAGES}"
    exit 1
fi

# Deduplicate: keep only the newest version of each file
# Filename pattern: wikipedia_en_topic_variant_YYYY-MM.zim
declare -A NEWEST_FILES
declare -A NEWEST_DATES

for file in "${!FILE_SIZES[@]}"; do
    # Extract base name (everything before the date)
    base=$(echo "$file" | sed -E 's/_[0-9]{4}-[0-9]{2}\.zim$//')
    # Extract date (YYYY-MM)
    date=$(echo "$file" | sed -E 's/.*_([0-9]{4}-[0-9]{2})\.zim$/\1/')
    
    # Keep if no existing entry or if this date is newer
    if [[ -z "${NEWEST_DATES[$base]}" || "$date" > "${NEWEST_DATES[$base]}" ]]; then
        NEWEST_DATES[$base]="$date"
        NEWEST_FILES[$base]="$file"
    fi
done

# Build dialog checklist options
# Format: tag item status
OPTIONS=()
for base in $(echo "${!NEWEST_FILES[@]}" | tr ' ' '\n' | sort); do
    file="${NEWEST_FILES[$base]}"
    size="${FILE_SIZES[$file]:-???}"
    
    # Create readable description from filename
    # wikipedia_en_medicine_nopic_2025-06.zim -> [EN] medicine (nopic) - 2025-06 - 1.0G
    lang=$(echo "$file" | sed -E 's/wikipedia_([a-z]{2})_.*/\1/' | tr '[:lower:]' '[:upper:]')
    topic=$(echo "$file" | sed -E 's/wikipedia_[a-z]{2}_([^_]+)_.*/\1/')
    variant=$(echo "$file" | sed -E 's/wikipedia_[a-z]{2}_[^_]+_(.*)_[0-9]{4}-[0-9]{2}\.zim/\1/')
    date=$(echo "$file" | sed -E 's/.*_([0-9]{4}-[0-9]{2})\.zim$/\1/')
    
    # Check if already downloaded
    if [[ -e "${ZIM_DIR}/${file}" ]]; then
        status="on"
        desc="[${lang}] ${topic} (${variant}) ${date} - ${size} [INSTALLED]"
    else
        status="off"
        desc="[${lang}] ${topic} (${variant}) ${date} - ${size}"
    fi
    
    OPTIONS+=("$file" "$desc" "$status")
done

# Show checklist dialog
SELECTED=$(dialog --clear --backtitle "EmComm-Tools Wikipedia Downloader" \
    --title "Select Wikipedia ZIM Files" \
    --checklist "Use SPACE to select/deselect, ENTER to confirm.\nFiles will be downloaded to: ${ZIM_DIR}\n\nNote: 'maxi' versions include images, 'nopic' versions are text-only (smaller)." \
    30 90 20 \
    "${OPTIONS[@]}" \
    2>&1 >/dev/tty)

EXIT_STATUS=$?
tput sgr0 && clear

if [[ $EXIT_STATUS -ne 0 ]]; then
    echo "Download cancelled."
    exit 0
fi

if [[ -z "$SELECTED" ]]; then
    echo "No files selected."
    exit 0
fi

# Download selected files
echo "Starting downloads..."
echo ""

for file in $SELECTED; do
    # Remove quotes from dialog output
    file=$(echo "$file" | tr -d '"')
    
    if [[ -e "${ZIM_DIR}/${file}" ]]; then
        echo "✓ ${file} already exists, skipping..."
        continue
    fi
    
    download_url="${URL}${file}"
    echo "Downloading: ${file}"
    echo "From: ${download_url}"
    echo ""
    
    # Download with progress bar, resume support
    if curl -L -f -C - -o "${ZIM_DIR}/${file}.part" "${download_url}"; then
        mv "${ZIM_DIR}/${file}.part" "${ZIM_DIR}/${file}"
        echo "✓ Downloaded: ${file}"
    else
        echo "✗ Failed to download: ${file}"
        rm -f "${ZIM_DIR}/${file}.part"
    fi
    echo ""
done

echo ""
echo "Download complete!"
echo "Files are stored in: ${ZIM_DIR}"
echo ""
echo "To use with Kiwix, open Kiwix and add this folder to your library."
