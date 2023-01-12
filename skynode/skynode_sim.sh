#!/usr/bin/env bash

# Constants
TARGET_USER="root"
TARGET_PASSWORD="auterion"
TARGET_IP="10.223.0.69"
SSH_OPTS="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o ConnectTimeout=2 -o LogLevel=ERROR"

wait_for_connected () {
	until connect ; do
		echo "Waiting to discover device..."
		sleep 3
	done
}

connect () {
	yes | sshpass -p ${TARGET_PASSWORD} ssh $SSH_OPTS ${TARGET_USER}@${TARGET_IP} > /dev/null 2>&1 echo ""
	result=$?
	if [ "$result" == "0" ]; then
	    echo "Connected to $TARGET_USER@$TARGET_IP"
	fi

	return $result
}

run_on_target() {
	sshpass -p ${TARGET_PASSWORD} ssh $SSH_OPTS ${TARGET_USER}@${TARGET_IP} $1
}

#__________________ Main _________________ #

wait_for_connected

SIM_REPORT=$(run_on_target "mmcli -i 0")

ICCID=$(echo ${SIM_REPORT} | grep -oP "(?<=iccid\:\s)\d*")
echo "ICCID: $ICCID"
