#!/usr/bin/env bash

# Constants
TARGET_USER="root"
TARGET_PASSWORD="root"
TARGET_IP=""
DESIRED_SSID=""
FIRMWARE_FILE_PATH=""
BANDWIDTH="15"

# Circumvents host key check, silences warning, connection timeout, silence warnings
SSH_OPTS="-o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedKeyTypes=+ssh-rsa -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o ConnectTimeout=2 -o LogLevel=ERROR"

wait_for_connected () {
	echo "Waiting to discover device..."
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

update_settings () {
	echo "Updating settings..."

	echo "Setting SSID to $DESIRED_SSID"
	run_on_target "uci set wireless.wifi0.mesh_id=$DESIRED_SSID"

	echo "Setting bandwidth to $BANDWIDTH"
	run_on_target "uci set wireless.radio0.chanbw=$BANDWIDTH"

	echo "Setting country code to US"
	run_on_target "uci set wireless.radio0.country=US"

	echo "Setting diversity rates"
	run_on_target "uci set diffserv.@general[0].diversity_rates=1"

	echo "Setting optimized video streaming"
	run_on_target "uci set diffserv.@general[0].optimized_vi=1"

	run_on_target "uci commit"

	# Flush to disk
	run_on_target "sync"
}

verify_settings () {
	result=$(run_on_target "uci show wireless | grep wireless.wifi0.mesh_id")
	ssid=$(echo "$result" | cut -d"'" -f 2)

	if [ "$ssid" != "$DESIRED_SSID" ]; then
		echo "Error, SSID does not match desired"
		echo "ssid: $ssid"
		echo "desired: $DESIRED_SSID"
		echo "Failed"
	else
		echo ""
		echo ""
		echo "************************************************"
		echo ""
		echo "Success! $TARGET_IP set to $DESIRED_SSID !"
		echo ""
		echo "************************************************"
		echo ""
		echo ""
	fi
}

update_fw () {
	echo "Uploading firmware..."
	filename=$(basename $FIRMWARE_FILE_PATH)
	echo "filepath: $FIRMWARE_FILE_PATH"
	scp $SSH_OPTS $FIRMWARE_FILE_PATH $TARGET_USER@$TARGET_IP:/tmp/$filename

	echo "Updating..."
	run_on_target "sysupgrade -n /tmp/$filename"
}

reboot () {
	echo "Rebooting"
	run_on_target "reboot"
}

# ========== #
#___ Main ___#
# ========== #
clear
echo " _________________________________________________ "
echo "|                                                 |"
echo "| DOODLE RADIO UPDATE AND SETTINGS CONFIG         |"
echo "| WATTS INNOVATIONS INC                           |"
echo "| DEC 2022 Jacob Dahl + Chris Baquol              |"
echo "|                                                 |"
echo "|_________________________________________________|"
echo ""
echo ""
echo "Firmware files in current working directory: "
echo ""
firmware_in_path="$(ls | grep *.bin)"
echo $firmware_in_path
echo ""
echo ""
echo "Enter the correct file name from list above or enter absolute path"
echo "of the .bin firmware file (/home/user/firmware_file.bin). Leave blank to"
read -p "skip updating firmware. This will be used for the whole batch and can only be set once!: " FIRMWARE_FILE_PATH


while :
do
	echo ""
	read -p "Enter Doodle IP or [q]uit: " TARGET_IP
	if [ "$TARGET_IP" == "q" ]; then
		echo "Goodbye!"
		exit
	fi
	read -p "Enter desired SSID: " DESIRED_SSID

	wait_for_connected

	#should add an else verification code block here to have user enter correct filename
	if ! [ -z "$FIRMWARE_FILE_PATH" ]; then
		update_fw
		spin[0]="Updating"
		spin[1]="Updating."
		spin[2]="Updating.."
		spin[3]="Updating..."
		spin[4]="Updating...."

		until connect ; do
			for i in "${spin[@]}"
			do
				echo -e "\e[1A\e[K$i"
				sleep 1
			done
		done
		echo "Update complete!"
	else
		echo ""
		echo "Skipping firmware update"
		echo ""
	fi

	update_settings

	reboot

	wait_for_connected

	verify_settings
done