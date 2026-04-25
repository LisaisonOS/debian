#!/bin/bash
#
# Author  : Gaston Gonzalez
# Date    : 13 October 2025
# Purpose : Audio settings specific to the Xiegu X6100
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

# Unmute Speaker and set the volume to 27. Adjust if the remote station
# can't decode you or if there is no output power on TX.
amixer -q -c ${AUDIO_CARD} sset Speaker Playback Switch 42% unmute

# Unmute Mic
amixer -q -c ${AUDIO_CARD} sset Mic Playback Switch 52% unmute

# Set "L/R Capture" to 19. Adjust if you can't decode received audio.
amixer -q -c ${AUDIO_CARD} sset Mic Capture Switch 31% unmute

# Disable Auto Gain Control
amixer -q -c ${AUDIO_CARD} sset 'Auto Gain Control' mute

et-log "Applied amixer settings for audio card ${AUDIO_CARD} on device ${ET_DEVICE_NAME}"
