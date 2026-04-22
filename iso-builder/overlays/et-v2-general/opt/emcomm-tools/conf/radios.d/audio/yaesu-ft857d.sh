#
# Author  : Gaston Gonzalez!/bin/bash
#
# Author  : Gaston Gonzalez
#
# Author  : Gaston Gonzalez Date    : 14 October 2025
#
# Author  : Gaston Gonzalez Purpose : Audio settings specific to the Yaesu FT-857D via DigiRig Mobile
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
# Author  : Gaston Gonzalez Unmute Speaker a set volume. Adjust if remote station can't decode you. Your TX controls.
amixer -q -c ${AUDIO_CARD} sset Speaker Playback Switch 42% unmute

#
# Author  : Gaston Gonzalez Unmute Mic
amixer -q -c ${AUDIO_CARD} sset Mic Playback Switch 52% unmute

#
# Author  : Gaston Gonzalez Set "L/R Capture" to 19. Adjust if you can't decode received audio. Your RX controls.
amixer -q -c ${AUDIO_CARD} sset Mic Capture Switch 25% unmute

#
# Author  : Gaston Gonzalez Disable Auto Gain Control
amixer -q -c ${AUDIO_CARD} sset 'Auto Gain Control' mute

et-log "Applied amixer settings for audio card ${AUDIO_CARD} on device ${ET_DEVICE_NAME}"
