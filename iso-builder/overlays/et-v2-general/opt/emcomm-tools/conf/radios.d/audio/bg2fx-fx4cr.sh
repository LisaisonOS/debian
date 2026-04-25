#!/bin/bash
#
# Author  : Gaston Gonzalez
# Date    : 13 October 2025
# Purpose : Audio settings specific to the FX-4CR
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

# Unmute the PCM and set the volume to 21% to get the full output power. This value is
# dependent on the settings defined for the FX-4CR in the et-radio notes. 
amixer -q -c ${AUDIO_CARD} sset 'PCM' 31% unmute

# Set "L/R Capture" to 55%. Adjust if you can't decode received audio.
amixer -q -c ${AUDIO_CARD} sset 'Mic' 67% unmute

# Disable Auto Gain Control
amixer -q -c ${AUDIO_CARD} sset 'Auto Gain Control' mute

et-log "Applied amixer settings for audio card ${AUDIO_CARD} on device ${ET_DEVICE_NAME}"
