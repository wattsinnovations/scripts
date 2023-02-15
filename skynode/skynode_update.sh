#!/bin/bash
TARGET_USER="root"
TARGET_PASSWORD="auterion"
TARGET_IP="10.41.1.1"
MY_IP="10.41.1.2"
#TARGET_IP="10.223.0.69"
#MY_IP="10.223.100.50"
MY_PATH=$(dirname "$0")
ARTIFACT_PATH="$MY_PATH/../../images/com.wattsinnovations.auterion_os_1.2.4.auterionos"
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

install_python_dependencies () {
	packages=$(pip freeze)
	if ! [[ $packages == *"tqdm"* ]]; then
		echo "Installing tqdm"
		pip3 install tqdm
	fi

	if ! [[ $packages == *"requests-toolbelt"* ]]; then
		echo "Installing requests-toolbelt"
		pip3 install requests-toolbelt
	fi

	if ! [[ $packages == *"pyserial"* ]]; then
		echo "Installing pyserial"
		pip3 install pyserial
	fi
}

update () {
	python3 $MY_PATH/../tools/update.py --artifact $ARTIFACT_PATH --device-ip $TARGET_IP
}

set_and_check_wifi_ssid () {
	skynode_ssid="PRISM Sky $SERIAL"
	# TODO: arg for MY_IP
	python3 $MY_PATH/set_ext_param.py --port $MY_IP:14550 --compid 191 --set WIFI_SSID="$skynode_ssid"

	echo "Waiting to discover skynode WiFi..."
	wifi_list=""
	until [[ $wifi_list == *$skynode_ssid* ]]; do
		wifi_list=$(nmcli dev wifi | grep $SERIAL)
		sleep 5
	done

	echo "SSID updated successfully"
}

run_on_target() {
	sshpass -p ${TARGET_PASSWORD} ssh $SSH_OPTS ${TARGET_USER}@${TARGET_IP} $1
}

check_docker_containers () {
	output=$(run_on_target "docker ps -a")
	if ! [[ $output == *"reel-winch"* && $output == *"reel-action"* ]]; then
		echo "Containers failed to install!"
		fail
	fi
	echo "Docker Containers installed successfully"
}

check_eth0_ip () {
	output=$(run_on_target "ip addr show eth0 | grep inet | awk '{print $2}' | cut -d/ -f1")
	ip=$(echo $output | awk '{print $2}')
	if ! [[ $ip == "10.223.0.69" ]]; then
		echo "eth0 IP $ip update failed!"
		fail
	fi
	echo "eth0 IP $ip updated successfully"
}

fail () {
	echo "${RedText}Failed!"
	exit 1
}

#__________________ Main _________________ #
if ! [ $1 ]; then
    echo "Usage: skynode_update.sh <serial>"
    echo "eg: ./skynode_update.sh 6012"
    exit 1
fi

scp_override_env () {
	if ! [ -f ../tools/override.env ]; then
		echo "${RedText}Failed!" 
		echo "override.env file missing from the ../tools directory. Add the appropriate file and try again"
		fail
	fi

	sshpass -p ${TARGET_PASSWORD} scp $SSH_OPTS ../tools/override.env ${TARGET_USER}@${TARGET_IP}:../data

	output=$(run_on_target "ls ../data/")

	if ! [[ $output == *"override"* ]]; then
		echo "Failed!"
		echo "env file is missing on Skynode"
		fail
	fi

	echo "Override.env file successfully copied"
}

install_python_dependencies

wait_for_connected

SERIAL=$1

update
# We know after updating that Docker is not actually done...
sleep 80

# Post update steps
# - register skynode serial number in suite

# - Update database with all relevant information
# 	- prism sky serial number
# 	- skynode serial number
# 	- sim imei
# 	- wifi ssid/password
# 	- aos version
# 	- release version

# - validation
# 	- software version is correct

wait_for_connected

scp_override_env
check_docker_containers
check_eth0_ip
set_and_check_wifi_ssid

echo "${GreenText}Success"

# Post build steps
# - query arm serial numbers and update database
