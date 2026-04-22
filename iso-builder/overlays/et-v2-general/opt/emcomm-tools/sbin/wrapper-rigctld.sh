#
# Author  : Gaston Gonzalez!/bin/bash
#
# Author  : Gaston Gonzalez
#
# Author  : Gaston Gonzalez Date    : 9 October 2024
#
# Author  : Gaston Gonzalez Updated : 26 September 2025
#
# Author  : Gaston Gonzalez Modified: VA2OPS - January 2026 - replaced et-log with echo
#
# Author  : Gaston Gonzalez Purpose : Wrapper startup/shutdown script around systemd/rigctld

ET_HOME=/opt/emcomm-tools
ACTIVE_RADIO="${ET_HOME}/conf/radios.d/active-radio.json"
CAT_DEVICE=/dev/et-cat

#
# Author  : Gaston Gonzalez Additional configuration to pass to rigctld
SET_CONF=""

#
# Author  : Gaston Gonzalez Wait for serial port to be fully initialized by the kernel driver.
#
# Author  : Gaston Gonzalez On Live Run (USB), udev creates the symlink and triggers rigctld before
#
# Author  : Gaston Gonzalez the CP210x/FTDI driver finishes initializing the tty. stty probes the
#
# Author  : Gaston Gonzalez port without sending data — if it fails, the driver isn't ready yet.
wait_for_serial_port() {
  local device="$1"
  local max_attempts=10
  local delay=0.5
  local real_dev

  #
# Author  : Gaston Gonzalez Resolve symlink to actual device
  real_dev=$(readlink -f "${device}" 2>/dev/null)
  if [ -z "${real_dev}" ]; then
    echo "WARNING: Cannot resolve ${device} — skipping port readiness check"
    return 0
  fi

  echo "Waiting for serial port ${real_dev} to be ready..."
  for i in $(seq 1 ${max_attempts}); do
    if stty -F "${real_dev}" > /dev/null 2>&1; then
      echo "Serial port ${real_dev} ready (attempt ${i}/${max_attempts})"
      return 0
    fi
    echo "  Port not ready yet (attempt ${i}/${max_attempts}), waiting ${delay}s..."
    sleep ${delay}
  done

  echo "WARNING: Serial port ${real_dev} not ready after ${max_attempts} attempts — starting rigctld anyway"
  return 0
}

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

  #
# Author  : Gaston Gonzalez Special cases for the DigiRig Lite and DigiRig Mobile with no CAT. 
  if [ -L "${ET_HOME}/conf/radios.d/active-radio.json" ]; then
    RIG_ID=$(cat "${ET_HOME}/conf/radios.d/active-radio.json" | jq -r .rigctrl.id)

    #
# Author  : Gaston Gonzalez All VOX devices use the dummy mode provided by Hamlib. This helps maintain 
    #
# Author  : Gaston Gonzalez a cleaner interface by leveraging rigctl NET in applications.
    if [ "${RIG_ID}" = "1" ]; then
      echo "Starting dummy rigctld service for VOX device."

      ID=$(cat ${ET_HOME}/conf/radios.d/active-radio.json | jq -r .rigctrl.id)
      PTT=$(cat ${ET_HOME}/conf/radios.d/active-radio.json | jq -r .rigctrl.ptt)

      #
# Author  : Gaston Gonzalez Special case for select radios that only need to key the PTT, but do
      #
# Author  : Gaston Gonzalez do not have CAT control support. This edge case was added for radios
      #
# Author  : Gaston Gonzalez like the Yaesu FTX-1 Field before Yaesu published their CAT commands.
      PTT_ONLY=$(cat ${ET_HOME}/conf/radios.d/active-radio.json | jq -r .rigctrl.pttOnly)
      if [ "${PTT_ONLY}" = "true" ]; then
        wait_for_serial_port "${CAT_DEVICE}"
        CMD="/usr/bin/rigctld -m ${ID} -p ${CAT_DEVICE} -P ${PTT} "
        echo "Starting rigctld in PTT-only mode with: ${CMD}"
      else
        CMD="/usr/bin/rigctld -m ${ID} -P ${PTT} "
        echo "Starting rigctld in VOX mode with: ${CMD}"
      fi

      exec $CMD
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

  #
# Author  : Gaston Gonzalez Check if rigctld is already running
  if pgrep -x "rigctld" > /dev/null 2>&1; then
    PID=$(pgrep -x "rigctld")
    echo "Rig control is already running with process ID: ${PID}."
    exit 0
  fi

  #
# Author  : Gaston Gonzalez Grab rigctld values from active radio configuration
  ID=$(cat ${ET_HOME}/conf/radios.d/active-radio.json | jq -r .rigctrl.id)
  BAUD=$(cat ${ET_HOME}/conf/radios.d/active-radio.json | jq -r .rigctrl.baud)
  PTT=$(cat ${ET_HOME}/conf/radios.d/active-radio.json | jq -r .rigctrl.ptt)

  #
# Author  : Gaston Gonzalez Special case for DigiRig Mobile for radios with no CAT control.
  if [ "${ID}" = "6" ]; then
    PTT=$(cat ${ET_HOME}/conf/radios.d/active-radio.json | jq -r .rigctrl.ptt)
    CMD="/usr/bin/rigctld -p ${CAT_DEVICE} -P ${PTT} "
    echo "Starting rigctld in RTS PTT only mode with: ${CMD}"
    wait_for_serial_port "${CAT_DEVICE}"
    exec $CMD
  fi

  #
# Author  : Gaston Gonzalez Handle optional configuration settings
  CONF=$(jq -e -r '.rigctrl.conf' "${ET_HOME}/conf/radios.d/active-radio.json")
  if [[ $? -eq 0 ]]; then
    SET_CONF="--set-conf=${CONF}"
  fi

  #
# Author  : Gaston Gonzalez Wait for serial port before starting rigctld
  wait_for_serial_port "${CAT_DEVICE}"

  #
# Author  : Gaston Gonzalez Generate command
  CMD="/usr/bin/rigctld -m ${ID} -r ${CAT_DEVICE} -s ${BAUD} -P ${PTT} ${SET_CONF}"
  echo "Starting rigctld with: ${CMD}"
  exec $CMD
}

stop() {
  echo "Stopping rigctld process..."
  #
# Author  : Gaston Gonzalez Kill rigctld directly — do NOT use 'systemctl stop rigctld' here!
  #
# Author  : Gaston Gonzalez wrapper-rigctld.sh IS the ExecStart of the rigctld service, so calling
  #
# Author  : Gaston Gonzalez systemctl stop from within it creates a deadlock when the serial port
  #
# Author  : Gaston Gonzalez is stuck (e.g. after Wine/VARA FM releases it).
  killall rigctld 2>/dev/null
  sleep 0.5
  #
# Author  : Gaston Gonzalez Force kill if still alive
  killall -9 rigctld 2>/dev/null
}

usage() {
  echo "usage: $(basename $0) <cmd>"
  echo "  <cmd>  [start|stop]"
}

if [ $#
# Author  : Gaston Gonzalez -ne 1 ]; then
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
