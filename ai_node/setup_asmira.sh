#!/bin/bash

TARGET_SKYNODE_SN=""
TARGET_USER="root"
TARGET_PASSWORD="auterion"
TARGET_IP="10.223.0.70"
SSH_OPTS="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o ConnectTimeout=2 -o LogLevel=ERROR"
DOCKER_COMPOSE_FILE_PATH="./docker-compose.yml"
SETTINGS_DEFAULT_FILE_PATH="./settings.default.env"

run_on_target() {
	sshpass -p ${TARGET_PASSWORD} ssh $SSH_OPTS ${TARGET_USER}@${TARGET_IP} $1
}

remove_and_replace_yml() {
   	run_on_target "rm /data/app/asmira/src/docker-compose.yml"
	output=$(run_on_target "ls /data/app/asmira/src/")
	echo "$output"

	scp $SSH_OPTS $DOCKER_COMPOSE_FILE_PATH $TARGET_USER@$TARGET_IP:/data/app/asmira/src/

	echo "docker-compose.yml copied to remote"
}

remove_and_replace_env() {
	run_on_target "rm /data/app/asmira/src/settings.default.env"
	output=$(run_on_target "ls /data/app/asmira/src/")
	echo "$output"

	scp $SSH_OPTS $SETTINGS_DEFAULT_FILE_PATH $TARGET_USER@$TARGET_IP:/data/app/asmira/src/
	echo "SUCCESS"
	echo "settings.user.env copied to remote"
}

set_prism_sky_serial_number() {
	run_on_target "echo ASMIRA_STREAM_ID=$1 >> /data/app/asmira/src/settings.default.env"
}

check_skynode_sn_provided() {
	# check if user provided prism sky serial number
	if [[ "$1" != "" ]]; then
		TARGET_SKYNODE_SN="$1"
		echo "PRISM Sky target is $1"
	else
		TARGET_SKYNODE_SN=
		echo "skynode sn must be provided, script exiting"
		exit
	fi
}

start_docker_container() {
	run_on_target "docker-compose -f /data/app/asmira/src/docker-compose.yml up -d"
	echo "ASMIRA is up and running"
}

check_skynode_sn_provided $1
remove_and_replace_yml
remove_and_replace_env
set_prism_sky_serial_number $1
start_docker_container

