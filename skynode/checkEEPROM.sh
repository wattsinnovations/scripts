#!/usr/bin/env bash

TARGET_USER="root"
TARGET_PASSWORD="auterion"
TARGET_IP=""
MY_PATH=$(dirname "$0")
LOC=$1

print_eeprom () {
	$MY_PATH/px4_shell_command.py -p "udp:$HOST_IP:14550" "m95040df -S -b 1 -c $LOC info"
}

main () {
     print_eeprom
}

main
