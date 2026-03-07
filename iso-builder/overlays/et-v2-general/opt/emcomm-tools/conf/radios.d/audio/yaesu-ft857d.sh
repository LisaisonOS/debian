#!/bin/bash
#
# Author  : Gaston Gonzalez
# Date    : 14 October 2025
# Purpose : Audio settings specific to the Yaesu FT-857D via DigiRig Mobile
#
# Preconditions
# 1. Supported audio interface is connected and properly detected
#
# Postconditions
# 1. ALSA settings set on ET audio device

usage() {
  echo "usage: $(basename $0) <ET audio card> <ET device name>"
}

if [[ $# -ne 2 ]]; then
  usage
  exit 1
fi

AUDIO_CARD=$1
ET_DEVICE_NAME=$2

# Unmute Speaker a set volume. Adjust if remote station can't decode you. Your TX controls.
amixer -q -c ${AUDIO_CARD} sset Speaker Playback Switch 42% unmute

# Unmute Mic
amixer -q -c ${AUDIO_CARD} sset Mic Playback Switch 52% unmute

# Set "L/R Capture" to 19. Adjust if you can't decode received audio. Your RX controls.
amixer -q -c ${AUDIO_CARD} sset Mic Capture Switch 25% unmute

# Disable Auto Gain Control
amixer -q -c ${AUDIO_CARD} sset 'Auto Gain Control' mute

et-log "Applied amixer settings for audio card ${AUDIO_CARD} on device ${ET_DEVICE_NAME}"
