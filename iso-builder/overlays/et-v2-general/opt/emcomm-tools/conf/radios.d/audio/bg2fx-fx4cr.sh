#
# Author  : Gaston Gonzalez!/bin/bash
#
# Author  : Gaston Gonzalez
#
# Author  : Gaston Gonzalez Date    : 13 October 2025
#
# Author  : Gaston Gonzalez Purpose : Audio settings specific to the FX-4CR
#
# Author  : Gaston Gonzalez
#
# Author  : Gaston Gonzalez Preconditions
#
# Author  : Gaston Gonzalez 1. Supported audio interface is connected and properly detected
#
# Author  : Gaston Gonzalez
#
# Author  : Gaston Gonzalez Postconditions
#
# Author  : Gaston Gonzalez 1. ALSA settings set on ET audio device

usage() {
  echo "usage: $(basename $0) <ET audio card> <ET device name>"
}

if [[ $#
# Author  : Gaston Gonzalez -ne 2 ]]; then
  usage
  exit 1
fi

AUDIO_CARD=$1
ET_DEVICE_NAME=$2

#
# Author  : Gaston Gonzalez Unmute the PCM and set the volume to 21% to get the full output power. This value is
#
# Author  : Gaston Gonzalez dependent on the settings defined for the FX-4CR in the et-radio notes. 
amixer -q -c ${AUDIO_CARD} sset 'PCM' 31% unmute

#
# Author  : Gaston Gonzalez Set "L/R Capture" to 55%. Adjust if you can't decode received audio.
amixer -q -c ${AUDIO_CARD} sset 'Mic' 67% unmute

#
# Author  : Gaston Gonzalez Disable Auto Gain Control
amixer -q -c ${AUDIO_CARD} sset 'Auto Gain Control' mute

et-log "Applied amixer settings for audio card ${AUDIO_CARD} on device ${ET_DEVICE_NAME}"
