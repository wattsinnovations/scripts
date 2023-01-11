#!/usr/bin/env bash

# Constants
TARGET_USER="root"
TARGET_IP="10.223.0.69"
TARGET_PASSWORD="auterion"
SSH_OPTS="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o ConnectTimeout=2 -o LogLevel=ERROR"

ENV_VAR_NAME="DEFAULT_GATEWAY"
ENV_VAR_VALUE="10.223.0.71"

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

update_env_var () {
	# Check if $1 env var exists and add it if it doesn't
	exists=$(run_on_target "cat /data/override.env | grep $1")
	if ! [ $exists ]; then
		echo "Adding $1 to /data/override.env"
		run_on_target "echo \"$1=$2\" >> /data/override.env"

	else
		# Perform string key=value find and value replacement
		echo "Updating $1 to $2"
		run_on_target "sed -i '0,/^\([[:space:]]*$1=*\).*/s//\1'"$2"'/;' /data/override.env"

	fi
}


#__________________ Main _________________ #
wait_for_connected
run_on_target "sudo mount -o remount,rw /"
sshpass -p ${TARGET_PASSWORD} scp $SSH_OPTS overlay/usr/lib/systemd/system/default-gateway.service ${TARGET_USER}@${TARGET_IP}:/usr/lib/systemd/system/
run_on_target "ln -s /usr/lib/systemd/system/default-gateway.service /etc/systemd/system/basic.target.wants/default-gateway.service"
update_env_var $ENV_VAR_NAME $ENV_VAR_VALUE
