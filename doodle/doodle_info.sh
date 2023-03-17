#!/usr/bin/env bash

# Constants
TARGET_USER="root"
TARGET_PASSWORD="root"
TARGET_IP=""
DESIRED_SSID=""
FIRMWARE_FILE_PATH=""
BANDWIDTH="15"
#STATION=""
#$info=""
# Circumvents host key check, silences warning, connection timeout, silence warnings
SSH_OPTS="-o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedKeyTypes=+ssh-rsa -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o ConnectTimeout=2 -o LogLevel=ERROR"


run_on_target() {
	sshpass -p ${TARGET_PASSWORD} ssh $SSH_OPTS ${TARGET_USER}@${TARGET_IP} $1
    #return $info
}


#########
## main
#########

echo ""
read -p "Enter Doodle IP or [q]uit: " TARGET_IP
if [ "$TARGET_IP" == "q" ]; then
    echo "Goodbye!"
    exit
fi 

station=$(run_on_target "iwinfo wlan0 assoclist | awk '{print $1}' | cut -c 1-17 | head -n 1")
rssi=$(run_on_target "iw wlan0 station dump | grep signal | cut -c 12-14 | head -n 1")

echo "Station: $station" 
echo "RSSI: $rssi"