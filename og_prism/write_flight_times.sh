#!/usr/bin/env bash

# Constants
TARGET_USER="pi"
TARGET_IP=""

# Argument options
FLIGHT_TIME=0

print_help() {
    echo "Set flight time on all 4 motors and the pi"
    echo "Parameters:"
    echo "- (t) flight time in minutes"
    echo
    echo "e.g:  ./write_flight_times.sh -t 25"
}

# check_opts() {
#   if [ ${FLIGHT_TIME} ]; then
#     print_help
#     echo
#     echo "Propulsion ID required"
#     exit
#   fi
# }

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
while getopts :t: option; do
  case "${option}" in
  t)
    FLIGHT_TIME=${OPTARG}
    # Convert from minutes to milliseconds
    FLIGHT_TIME=$(($FLIGHT_TIME * 1000 * 60))
    ;;
  \?)
    print_help
    exit 1
    ;;
  esac
done

# check_opts
get_target_ip
add_target

# Run our provisioning commands
run_on_target "sudo systemctl stop prism_os.service"

# Page index 31 is flight time
run_on_target "~/prism_os/tests/eeprom_test 1 write 31 ${FLIGHT_TIME}"
run_on_target "~/prism_os/tests/eeprom_test 2 write 31 ${FLIGHT_TIME}"
run_on_target "~/prism_os/tests/eeprom_test 3 write 31 ${FLIGHT_TIME}"
run_on_target "~/prism_os/tests/eeprom_test 4 write 31 ${FLIGHT_TIME}"

the_date=$(date +"%y_%m_%d")
run_on_target "echo \"${FLIGHT_TIME};$the_date\" > ~/prism_os/logs/flight_times.txt"

run_on_target "sudo systemctl start prism_os.service"
