#!/usr/bin/env bash

# Constants
TARGET_USER="pi"
TARGET_IP=""

# Argument options
PROP_ID=""
DATE_OF_ASM=$(date +'%m/%d/%Y')
MOT_ASM_VER=""
PROP_NAME=""
TECH=""
SERIAL_NUM=""

# Pi password: dronesarehard123!

print_help() {
    echo "Provision all 4 eeproms"
    echo "Parameters:"
    echo "- propulsion ID number (-i): 1 is quad, 2 is x8, etc"
    echo "- motor assembly version (-m)"
    echo "- propeller name (-p)"
    echo "- technician initials (-t)"
    echo "- serial number (-s): will increment to N+3"
    echo
    echo "e.g:  ./provision_eeproms.sh -i 1 -m 1 -p FA28 -t JD -s 1"
}

check_opts() {
  if [ -z "$PROP_ID" ]; then
    print_help
    echo
    echo "Propulsion ID required"
    exit
  elif [ -z "$MOT_ASM_VER" ]; then
    print_help
    echo
    echo "Motor assmebly version required"
    exit
  elif [ -z "$PROP_NAME"  ]; then
    print_help
    echo
    echo "Propeller name required"
    exit
  elif [ -z "$TECH" ]; then
    print_help
    echo
    echo "Tech initials required"
    exit
  elif [ -z "$SERIAL_NUM" ]; then
    print_help
    echo
    echo "Serial number required"
    exit
  fi
}

get_target_ip() {
   TARGET_IP=$(ping -c1 raspberrypi | sed -nE 's/^PING[^(]+\(([^)]+)\).*/\1/p')
}

add_target() {
  yes | ssh ${TARGET_USER}@${TARGET_IP} "echo Adding target"
}

run_on_target() {
  if [ -z "$2" ]; then
    ssh ${TARGET_USER}@${TARGET_IP} $1
  else
    ssh ${TARGET_USER}@${TARGET_IP} "$1 > /dev/null 2>&1"
  fi
}

    #__________________ Main _________________ #
# set arguments to options
while getopts :i:m:p:t:s: option; do
  case "${option}" in
  i)
    PROP_ID=${OPTARG}
    ;;
  m)
    MOT_ASM_VER=${OPTARG}
    ;;
  p)
    PROP_NAME=${OPTARG}
    ;;
  t)
    TECH=${OPTARG}
    ;;
  s)
    SERIAL_NUM=${OPTARG}
    ;;
  \?)
    print_help
    exit 1
    ;;
  esac
done

check_opts
get_target_ip
add_target

# Run our provisioning commands
run_on_target "sudo systemctl stop prism_os.service"
# Page index 0 is propulsion ID
run_on_target "~/prism_os/tests/eeprom_test 1 write 0 ${PROP_ID}"
run_on_target "~/prism_os/tests/eeprom_test 2 write 0 ${PROP_ID}"
run_on_target "~/prism_os/tests/eeprom_test 3 write 0 ${PROP_ID}"
run_on_target "~/prism_os/tests/eeprom_test 4 write 0 ${PROP_ID}"
# Page index 1 is location
run_on_target "~/prism_os/tests/eeprom_test 1 write 1 FR"
run_on_target "~/prism_os/tests/eeprom_test 2 write 1 BR"
run_on_target "~/prism_os/tests/eeprom_test 3 write 1 BL"
run_on_target "~/prism_os/tests/eeprom_test 4 write 1 FL"
# Page index 2 is date
run_on_target "~/prism_os/tests/eeprom_test 1 write 2 ${DATE_OF_ASM}"
run_on_target "~/prism_os/tests/eeprom_test 2 write 2 ${DATE_OF_ASM}"
run_on_target "~/prism_os/tests/eeprom_test 3 write 2 ${DATE_OF_ASM}"
run_on_target "~/prism_os/tests/eeprom_test 4 write 2 ${DATE_OF_ASM}"
# Page index 3 is motor assemlby version
run_on_target "~/prism_os/tests/eeprom_test 1 write 3 ${MOT_ASM_VER}"
run_on_target "~/prism_os/tests/eeprom_test 2 write 3 ${MOT_ASM_VER}"
run_on_target "~/prism_os/tests/eeprom_test 3 write 3 ${MOT_ASM_VER}"
run_on_target "~/prism_os/tests/eeprom_test 4 write 3 ${MOT_ASM_VER}"
# Page index 4 is Propeller name
run_on_target "~/prism_os/tests/eeprom_test 1 write 4 ${PROP_NAME}"
run_on_target "~/prism_os/tests/eeprom_test 2 write 4 ${PROP_NAME}"
run_on_target "~/prism_os/tests/eeprom_test 3 write 4 ${PROP_NAME}"
run_on_target "~/prism_os/tests/eeprom_test 4 write 4 ${PROP_NAME}"
# Page index 5 is technician name
run_on_target "~/prism_os/tests/eeprom_test 1 write 5 ${TECH}"
run_on_target "~/prism_os/tests/eeprom_test 2 write 5 ${TECH}"
run_on_target "~/prism_os/tests/eeprom_test 3 write 5 ${TECH}"
run_on_target "~/prism_os/tests/eeprom_test 4 write 5 ${TECH}"
# Page index 6 is serial number
run_on_target "~/prism_os/tests/eeprom_test 1 write 6 ${SERIAL_NUM}"
SERIAL_NUM=$((SERIAL_NUM+1))
run_on_target "~/prism_os/tests/eeprom_test 2 write 6 ${SERIAL_NUM}"
SERIAL_NUM=$((SERIAL_NUM+1))
run_on_target "~/prism_os/tests/eeprom_test 3 write 6 ${SERIAL_NUM}"
SERIAL_NUM=$((SERIAL_NUM+1))
run_on_target "~/prism_os/tests/eeprom_test 4 write 6 ${SERIAL_NUM}"

# Page index 31 is flight time
run_on_target "~/prism_os/tests/eeprom_test 1 write 31 0"
run_on_target "~/prism_os/tests/eeprom_test 2 write 31 0"
run_on_target "~/prism_os/tests/eeprom_test 3 write 31 0"
run_on_target "~/prism_os/tests/eeprom_test 4 write 31 0"

run_on_target "sudo systemctl start prism_os.service"
