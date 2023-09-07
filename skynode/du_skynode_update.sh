#!/bin/bash
TARGET_USER="root"
TARGET_PASSWORD="auterion"
TARGET_IP=""
MY_IP=""
MY_PATH=$(dirname "$0")
ARTIFACT_PATH="$MY_PATH/../../images/com.wattsinnovations.auterion_os_0.1.3.7.auterionos"
SSH_OPTS="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o ConnectTimeout=2 -o LogLevel=ERROR"
SERIAL=""
MACHINE_TYPE=""
CONNECTION_TYPE=""

RedText=$'\e[1;31m'
GreenText=$'\e[1;32m'

set_connection_type () {
	if [ -z "$CONNECTION_TYPE" ]; then
		echo "Must specify aircraft connection type"
		fail
	fi

	if [ "$CONNECTION_TYPE" == "usb" ]; then
		TARGET_IP="10.41.1.1"
		MY_IP="10.41.1.2"
	fi

	if [ "$CONNECTION_TYPE" == "ip" ]; then
		TARGET_IP="10.223.0.69"
		MY_IP="10.223.100.50"
	fi
	
	# error handling for if connection type is not specified by the user
	if [ "$CONNECTION_TYPE" != "usb" ] && [ "$CONNECTION_TYPE" != "ip" ]; then
		echo "$CONNECTION_TYPE"
		echo "Must specify aircraft connection type as either 'ip' or 'usb'"
		fail
	fi
}

wait_for_connected () {
	until connect ; do
		echo "Waiting to discover device connected via ${CONNECTION_TYPE}..."
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

# Check for DU or Stock sky being updated, and copy the appropriate override.env file
scp_override_env () {
	# ANY MACHINE UPDATED WITH THIS SCRIPT IS ASSUMED TO BE A DU MACHINE

	if ! [ -f ../tools/du_override/override.env ]; then
		echo "${RedText}Failed!" 
		echo "override.env file missing from the ../tools/du_override directory. Add the appropriate file and try again"
		fail
	fi

	sshpass -p ${TARGET_PASSWORD} scp $SSH_OPTS ../tools/du_override/override.env ${TARGET_USER}@${TARGET_IP}:../data

	output=$(run_on_target "ls ../data/")

	if ! [[ $output == *"override"* ]]; then
		echo "Failed!"
		echo "env file is missing on Skynode"
		fail
	fi

	echo "Override.env successfully copied"
}

# disable WiFi
disable_wifi () {
	python3 $MY_PATH/set_ext_param.py --port $MY_IP:14550 --compid 191 --set WIFI_MODE=0

	echo "WiFi disabled successfully"
}


# install Halo default gateway service
install_halo_default_gw_service () {
	../halo/install_halo_default_gw_service.sh $CONNECTION_TYPE
	echo "Default gateway configured for Halo"
}

welcome_to_watts () {
	base64 -d <<<"H4sIACmG+GQAA61RwQ0DMQj7Zwq+fbFA5+gLyYswfLHju4vUbyFBxBiHKCuAsIEpaEdUQRt33dgvdUWNy3K8Wp07Jjkd0fZRqB3joErI8ArJZUmMiPoUi/fVo9Z4XdlDbSm6OGoDf2KWRuHtlxrP7ofPufODSsCzvTnbyCFnzcuYFqSGTTNIHePMD6oAsFj3B/zF1heBAEbs0wEAAA==" | gunzip
	base64 -d <<<"H4sIAAAAAAAAA8WWsW7jMAyG93uKGgQ4diME3CJDCwFOWrnkUfTs/Sk7iZPajpOmd0QRpbbEj/wpURmG45a+2ROLr/bnZdzr1GPMKyKHmcXfr+d5JneiuRYm9X/AvICTlVKJx/qayM8yZ4W9M0mreD4Tkzv5bzA71KsTM488jhgIVhRwFaa1Ja21ZcBpj5mGdcGylmYUzLBxGphFa5VvEWZz7LfYBBbjDnP3QKQq+fRXQC0QV7QQdabkFU+KIjA5bEbuaJusFrW8tjnaIJ8fH5+lhLA+ZKsqFfSh9ZdTyJGa4zFVxay8DH2TifghniC8nG9zjfPiJicvoevYLfIsmCxSq+IglTDFN8WIt7Z0vc3sLmN7TEaTk+6GCzGhporAqFOnD4LSPUiVawsRLPW0ylz2GViKMnBJeX7oMncgiwLCTXOJUxpB4F8iNzhus905vSvQTZ7pXIeoOEK2xdS2mJcV4tF5wwLIY1m+v3F4/6y1NW0vkbVVR9Cd0YGks86yjr4xd8E629M9AYsTlf7Fp16k0xFNt4537AXmoJx7UlaBUuxv5lpH3U7sx8zmLP0g1pFz1Dmh/tlolHxzvb0lz3kFlO1jxr2CLYzjIcHJ6LXtmLj7zJUFUDa1SA5dCCeYYx/Fk2ZcjwC3mHsLnB2fMt0rvc3Hti1YE2V+lhnKPNQmY8/i+tRo3HxpfBQpQt2DzGPTZhsAiw4olnqHst5ixaa3dZS3MiO5aHQVvwu2xBioF7bPtr19e4yocVPaJm2ykzEZTk7cLCX9lNnSA1zrSuj0K+VRbM/Vc8uydN0f0t7J9IO0dzKfs//B/AI8P6lylw0AAA==" | gunzip
	echo
	echo "WATTS UPDATER - DU P-SKY"
}

#__________________ Main _________________ #

CONNECTION_TYPE=$1

welcome_to_watts

set_connection_type

install_python_dependencies

wait_for_connected

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
# - software version is correct

wait_for_connected

scp_override_env
check_docker_containers
check_eth0_ip
disable_wifi

echo "${GreenText}Success"

# Post build steps
# - query arm serial numbers and update database
