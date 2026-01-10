#!/bin/bash
#
# Author  : Gaston Gonzalez
# Date    : 9 October 2024
# Updated : 26 September 2025
# Modified: VA2OPS - January 2026 - replaced et-log with echo
# Purpose : Wrapper startup/shutdown script around systemd/rigctld

ET_HOME=/opt/emcomm-tools
ACTIVE_RADIO="${ET_HOME}/conf/radios.d/active-radio.json"
CAT_DEVICE=/dev/et-cat

# Additional configuration to pass to rigctld
SET_CONF=""

do_full_auto() {
  echo "Found ET_DEVICE='${ET_DEVICE}'"

  case "$1" in
    IC-705)
      echo "Automatically configuring $1..."
      if [ -L ${ACTIVE_RADIO} ]; then
        rm -v  ${ACTIVE_RADIO}
      fi
      ln -v -s ${ET_HOME}/conf/radios.d/icom-ic705.json ${ACTIVE_RADIO}
    ;;
  *)
    echo "Full auto configuration not available for ET_DEVICE=$1"
    ;;
  esac
}

start() {

  # Special cases for the DigiRig Lite and DigiRig Mobile with no CAT. 
  if [ -L "${ET_HOME}/conf/radios.d/active-radio.json" ]; then
    RIG_ID=$(cat "${ET_HOME}/conf/radios.d/active-radio.json" | jq -r .rigctrl.id)

    # All VOX devices use the dummy mode provided by Hamlib. This helps maintain 
    # a cleaner interface by leveraging rigctl NET in applications.
    if [ "${RIG_ID}" = "1" ]; then
      echo "Starting dummy rigctld service for VOX device."

      ID=$(cat ${ET_HOME}/conf/radios.d/active-radio.json | jq -r .rigctrl.id)
      PTT=$(cat ${ET_HOME}/conf/radios.d/active-radio.json | jq -r .rigctrl.ptt)

      # Special case for select radios that only need to key the PTT, but do
      # do not have CAT control support. This edge case was added for radios
      # like the Yaesu FTX-1 Field before Yaesu published their CAT commands.
      PTT_ONLY=$(cat ${ET_HOME}/conf/radios.d/active-radio.json | jq -r .rigctrl.pttOnly)
      if [ "${PTT_ONLY}" = "true" ]; then
        CMD="/usr/bin/rigctld -m ${ID} -p ${CAT_DEVICE} -P ${PTT} "
        echo "Starting rigctld in PTT-only mode with: ${CMD}"
      else
        CMD="/usr/bin/rigctld -m ${ID} -P ${PTT} "
        echo "Starting rigctld in VOX mode with: ${CMD}"
      fi

      $CMD
      exit 0
    fi
  fi

  if [ ! -e ${CAT_DEVICE} ]; then
    echo "No CAT device found. ${CAT_DEVICE} symlink is missing."
    exit 1
  fi

  if [ ! -L ${ACTIVE_RADIO} ]; then
    echo "No active radio defined. ${ACTIVE_RADIO} symlink is missing."
    exit 1
  fi

  # Check if rigctld is already running
  if pgrep -x "rigctld" > /dev/null 2>&1; then
    PID=$(pgrep -x "rigctld")
    echo "Rig control is already running with process ID: ${PID}."
    exit 0
  fi

  # Grab rigctld values from active radio configuration
  ID=$(cat ${ET_HOME}/conf/radios.d/active-radio.json | jq -r .rigctrl.id)
  BAUD=$(cat ${ET_HOME}/conf/radios.d/active-radio.json | jq -r .rigctrl.baud)
  PTT=$(cat ${ET_HOME}/conf/radios.d/active-radio.json | jq -r .rigctrl.ptt)

  # Special case for DigiRig Mobile for radios with no CAT control.
  if [ "${ID}" = "6" ]; then
    echo "Starting rigctld in RTS PTT only mode with: ${CMD}"
    PTT=$(cat ${ET_HOME}/conf/radios.d/active-radio.json | jq -r .rigctrl.ptt)
    CMD="/usr/bin/rigctld -p ${CAT_DEVICE} -P ${PTT} "
    echo "Starting rigctld in RTS PTT only mode with: ${CMD}"
    $CMD
    exit 0
  fi

  # Handle optional configuration settings
  CONF=$(jq -e -r '.rigctrl.conf' "${ET_HOME}/conf/radios.d/active-radio.json")
  if [[ $? -eq 0 ]]; then
    SET_CONF="--set-conf=${CONF}"
  fi

  # Generate command
  CMD="/usr/bin/rigctld -m ${ID} -r ${CAT_DEVICE} -s ${BAUD} -P ${PTT} ${SET_CONF}"
  echo "Starting rigctld with: ${CMD}"
  $CMD
}

stop() {
  echo "Stopping rigctld service..."
  systemctl stop rigctld

  if [ -L /dev/et-cat ]; then
    echo "Removing stale /dev/et-cat symlink"
    rm -f /dev/et-cat
  fi
}

usage() {
  echo "usage: $(basename $0) <cmd>"
  echo "  <cmd>  [start|stop]"
}

if [ $# -ne 1 ]; then
  usage
  exit 1
fi

case $1 in
  start)
    start
    ;;
  stop)
    stop
    ;;
  *)
    usage
  ;;
esac
