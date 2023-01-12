#!/bin/bash

TARGET_USER="root"
TARGET_PASSWORD="auterion"
TARGET_IP="10.223.0.70"
MY_IP="10.41.1.2"
# TARGET_IP="10.223.0.69"
# MY_IP="10.223.100.50"
MY_PATH=$(dirname "$0")
SSH_OPTS="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o ConnectTimeout=2 -o LogLevel=ERROR"

run_on_target() {
	sshpass -p ${TARGET_PASSWORD} ssh $SSH_OPTS ${TARGET_USER}@${TARGET_IP} $1
}

check_usb_cam() {
	output=$(run_on_target "ls /dev/v4l/by-id")
	echo $output
}

check_usb_cam
