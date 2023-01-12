#!/bin/bash
TARGET_USER="root"
TARGET_PASSWORD="auterion"
TARGET_IP="10.41.2.1"
MY_PATH=$(dirname "$0")
ARTIFACT_PATH="$MY_PATH/../../images/1.3-ai.auterionos"
SERIAL=""
SSH_OPTS="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o ConnectTimeout=2 -o LogLevel=ERROR"

RedText=$'\e[1;31m'
GreenText=$'\e[1;32m'

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

update () {
	python3 $MY_PATH/../tools/update.py --artifact $ARTIFACT_PATH --device-ip $TARGET_IP
}

run_on_target() {
	sshpass -p ${TARGET_PASSWORD} ssh $SSH_OPTS ${TARGET_USER}@${TARGET_IP} $1
}

check_docker_containers () {
	output=$(run_on_target "docker ps -a")
	if ! [[ $output == *"lando"* ]]; then
		echo "Containers failed to install!"
		fail
	fi
	echo "Docker Containers installed successfully"
}

check_eth0_ip () {
	output=$(run_on_target "ip addr show eth0 | grep inet | awk '{print $2}' | cut -d/ -f1")
	ip=$(echo $output | awk '{print $2}')
	if ! [[ $ip == "10.223.0.70" ]]; then
		echo "eth0 IP $ip update failed!"
		fail
	fi
	echo "eth0 IP $ip updated successfully"
}

check_default_gateway () {
	output=$(run_on_target "ip route")
	if ! [[ $output == *"10.223.0.0/16"* ]]; then
		echo "Default gateway update failed!"
		fail
	fi
	echo "Default gateway updated successfully"
}

fail () {
	echo "${RedText}Failed!"
	exit 1
}

#__________________ Main _________________ #
wait_for_connected

update

# Post update steps
wait_for_connected

check_docker_containers
check_eth0_ip
check_default_gateway

echo "${GreenText}Success"

# Post build steps
# TODO: check if camera is visible
