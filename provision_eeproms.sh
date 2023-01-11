#!/usr/bin/env bash

# Constants
TARGET_USER="root"
TARGET_PASSWORD="auterion"
TARGET_IP=""
SSH_OPTS="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o ConnectTimeout=2 -o LogLevel=ERROR"
HOST_IP="10.223.100.50"
MY_PATH=$(dirname "$0")

# Argument options
PROP_ID=""
DATE_OF_ASM=$(date +'%m/%d/%Y')
MOT_ASM_VER=""
PROP_NAME=""
TECH=""
FR_SERIAL_NUM=""
BR_SERIAL_NUM=""
BL_SERIAL_NUM=""
FL_SERIAL_NUM=""

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

interactive_arguments () {
	read -p "Propulsion ID: " PROP_ID
	read -p "Motor assembly version: " MOT_ASM_VER
	read -p "Propeller name: " PROP_NAME
	read -p "Technician initials: " TECH
	read -p "Front Right serial " FR_SERIAL_NUM
	read -p "Back Right serial " BR_SERIAL_NUM
	read -p "Back Left serial " BL_SERIAL_NUM
	read -p "Front Left serial " FL_SERIAL_NUM
}

handle_arguments() {
	while getopts :i:m:p:t:1:2:3:4: option; do
		case "${option}" in
		i)
			PROP_ID=${OPTARG}
			;;
		m)
			MOT_ASM_VER=${OPTARG}
			;;
		p)
			PROP_NAME=${OPTARG}
			;;
		t)
			TECH=${OPTARG}
			;;
		1)
			FR_SERIAL_NUM=${OPTARG}
			;;
		2)
			BR_SERIAL_NUM=${OPTARG}
			;;
		3)
			BL_SERIAL_NUM=${OPTARG}
			;;
		4)
			FL_SERIAL_NUM=${OPTARG}
			;;
		\?)
			print_help
			exit 1
			;;
		esac
	done

	check_opts
}

check_opts () {
	if [ -z "$PROP_ID" ]; then
		print_help
		echo
		echo "Propulsion ID required"
		exit
	elif [ -z "$MOT_ASM_VER" ]; then
		print_help
		echo
		echo "Motor assmebly version required"
		exit
	elif [ -z "$PROP_NAME"  ]; then
		print_help
		echo
		echo "Propeller name required"
		exit
	elif [ -z "$TECH" ]; then
		print_help
		echo
		echo "Tech initials required"
		exit
	elif [ -z "$FR_SERIAL_NUM" ]; then
		print_help
		echo
		echo "FR Serial number required"
		exit
	elif [ -z "$BR_SERIAL_NUM" ]; then
		print_help
		echo
		echo "BR Serial number required"
		exit
	elif [ -z "$BL_SERIAL_NUM" ]; then
		print_help
		echo
		echo "BL Serial number required"
		exit
	elif [ -z "$FL_SERIAL_NUM" ]; then
		print_help
		echo
		echo "FL Serial number required"
		exit
	fi
}

get_target_ip () {
	# Try pinging skynode on USB first
	pingres=$(ping 10.41.1.1 -i 0.2 -c 5 -w 1)
	loss=$(echo "$pingres" | grep "packet loss" | awk '{print $6}')
	loss=${loss%?}

	if [ "$loss" == "0" ]; then
		echo "Connecting to Skynode over USB"
		TARGET_IP=$(echo $pingres | sed -nE 's/^PING[^(]+\(([^)]+)\).*/\1/p')
		HOST_IP=10.41.1.2
		return
	fi

	# Try pinging skynode on ETH next
	pingres=$(ping 10.223.0.69 -i 0.2 -c 5 -w 1)
	loss=$(echo "$pingres" | grep "packet loss" | awk '{print $6}')
	loss=${loss%?}

	if [ "$loss" == "0" ]; then
		echo "Connecting to Skynode over ETH"
		TARGET_IP=$(echo $pingres | sed -nE 's/^PING[^(]+\(([^)]+)\).*/\1/p')
		HOST_IP=10.223.100.50
		return
	fi

	# Couldn't ping skynode, try raspberry pi
	pingres=$(ping raspberrypi -i 0.2 -w 2 -c 5 -w 1)
	loss=$(echo "$pingres" | grep "packet loss" | awk '{print $6}')
	loss=${loss%?}

	if [ "$loss" == "0" ]; then
		echo "Connecting to Raspberry Pi over WiFi"
		TARGET_IP=$(echo $pingres| sed -nE 's/^PING[^(]+\(([^)]+)\).*/\1/p')
		TARGET_USER="pi"
		TARGET_PASSWORD=""
		return
	fi

	echo "Could not detect device!"
	exit 1
}

run_on_target() {
	sshpass -p ${TARGET_PASSWORD} ssh $SSH_OPTS ${TARGET_USER}@${TARGET_IP} $1
}

run_skynode () {
	# Writes Propulsion ID and Location
	$MY_PATH/px4_shell_command.py -p "udp:$HOST_IP:14550" "m95040df -S -b 1 -c 1 id ${PROP_ID}"
	$MY_PATH/px4_shell_command.py -p "udp:$HOST_IP:14550" "m95040df -S -b 1 -c 2 id ${PROP_ID}"
	$MY_PATH/px4_shell_command.py -p "udp:$HOST_IP:14550" "m95040df -S -b 1 -c 3 id ${PROP_ID}"
	$MY_PATH/px4_shell_command.py -p "udp:$HOST_IP:14550" "m95040df -S -b 1 -c 4 id ${PROP_ID}"

	# Write the date
	$MY_PATH/px4_shell_command.py -p "udp:$HOST_IP:14550" "m95040df -S -b 1 -c 1 date ${DATE_OF_ASM}"
	$MY_PATH/px4_shell_command.py -p "udp:$HOST_IP:14550" "m95040df -S -b 1 -c 2 date ${DATE_OF_ASM}"
	$MY_PATH/px4_shell_command.py -p "udp:$HOST_IP:14550" "m95040df -S -b 1 -c 3 date ${DATE_OF_ASM}"
	$MY_PATH/px4_shell_command.py -p "udp:$HOST_IP:14550" "m95040df -S -b 1 -c 4 date ${DATE_OF_ASM}"

	# Write the assembly
	$MY_PATH/px4_shell_command.py -p "udp:$HOST_IP:14550" "m95040df -S -b 1 -c 1 asm ${MOT_ASM_VER}"
	$MY_PATH/px4_shell_command.py -p "udp:$HOST_IP:14550" "m95040df -S -b 1 -c 2 asm ${MOT_ASM_VER}"
	$MY_PATH/px4_shell_command.py -p "udp:$HOST_IP:14550" "m95040df -S -b 1 -c 3 asm ${MOT_ASM_VER}"
	$MY_PATH/px4_shell_command.py -p "udp:$HOST_IP:14550" "m95040df -S -b 1 -c 4 asm ${MOT_ASM_VER}"

	# Write the propeller
	$MY_PATH/px4_shell_command.py -p "udp:$HOST_IP:14550" "m95040df -S -b 1 -c 1 prop ${PROP_NAME}"
	$MY_PATH/px4_shell_command.py -p "udp:$HOST_IP:14550" "m95040df -S -b 1 -c 2 prop ${PROP_NAME}"
	$MY_PATH/px4_shell_command.py -p "udp:$HOST_IP:14550" "m95040df -S -b 1 -c 3 prop ${PROP_NAME}"
	$MY_PATH/px4_shell_command.py -p "udp:$HOST_IP:14550" "m95040df -S -b 1 -c 4 prop ${PROP_NAME}"

	# Write the tech
	$MY_PATH/px4_shell_command.py -p "udp:$HOST_IP:14550" "m95040df -S -b 1 -c 1 tech ${TECH}"
	$MY_PATH/px4_shell_command.py -p "udp:$HOST_IP:14550" "m95040df -S -b 1 -c 2 tech ${TECH}"
	$MY_PATH/px4_shell_command.py -p "udp:$HOST_IP:14550" "m95040df -S -b 1 -c 3 tech ${TECH}"
	$MY_PATH/px4_shell_command.py -p "udp:$HOST_IP:14550" "m95040df -S -b 1 -c 4 tech ${TECH}"

	# Write the serial
	$MY_PATH/px4_shell_command.py -p "udp:$HOST_IP:14550" "m95040df -S -b 1 -c 1 serial ${FR_SERIAL_NUM}"
	$MY_PATH/px4_shell_command.py -p "udp:$HOST_IP:14550" "m95040df -S -b 1 -c 2 serial ${BR_SERIAL_NUM}"
	$MY_PATH/px4_shell_command.py -p "udp:$HOST_IP:14550" "m95040df -S -b 1 -c 3 serial ${BL_SERIAL_NUM}"
	$MY_PATH/px4_shell_command.py -p "udp:$HOST_IP:14550" "m95040df -S -b 1 -c 4 serial ${FL_SERIAL_NUM}"

	# # Zero the flight time
	$MY_PATH/px4_shell_command.py -p "udp:$HOST_IP:14550" "m95040df -S -b 1 -c 1 time 0"
	$MY_PATH/px4_shell_command.py -p "udp:$HOST_IP:14550" "m95040df -S -b 1 -c 2 time 0"
	$MY_PATH/px4_shell_command.py -p "udp:$HOST_IP:14550" "m95040df -S -b 1 -c 3 time 0"
	$MY_PATH/px4_shell_command.py -p "udp:$HOST_IP:14550" "m95040df -S -b 1 -c 4 time 0"

	sleep 1

	# Check to ensure values were written
	ep1_result=$($MY_PATH/px4_shell_command.py -p "udp:$HOST_IP:14550" "m95040df -S -b 1 -c 1 info")
	ep2_result=$($MY_PATH/px4_shell_command.py -p "udp:$HOST_IP:14550" "m95040df -S -b 1 -c 2 info")
	ep3_result=$($MY_PATH/px4_shell_command.py -p "udp:$HOST_IP:14550" "m95040df -S -b 1 -c 3 info")
	ep4_result=$($MY_PATH/px4_shell_command.py -p "udp:$HOST_IP:14550" "m95040df -S -b 1 -c 4 info")

	echo "$ep1_result"
	echo "$ep2_result"
	echo "$ep3_result"
	echo "$ep4_result"

	success="Success!"
	################## EEPROM 1 ##################
	# Check Propulsion ID
	if [ "$(echo "$ep1_result" | grep ID: | awk '{print $4}')" != "${PROP_ID}" ]; then
		echo "Failed to set Propulsion ID on EEPROM 1"
		success="Fail!"
	fi

	# Check Location
	if [ "$(echo "$ep1_result" | grep Location: | awk '{print $4}')" != "FR" ]; then
		echo "Failed to set Location on EEPROM 1"
		success="Fail!"
	fi

	# Check Date
	if [ "$(echo "$ep1_result" | grep Date: | awk '{print $4}')" != "${DATE_OF_ASM}" ]; then
		echo "Failed to set Date on EEPROM 1"
		success="Fail!"
	fi

	# Check Assembly
	if [ "$(echo "$ep1_result" | grep Assembly: | awk '{print $4}')" != "${MOT_ASM_VER}" ]; then
		echo "Failed to set Assembly on EEPROM 1"
		success="Fail!"
	fi

	# Check Propeller
	if [ "$(echo "$ep1_result" | grep Prop: | awk '{print $4}')" != "${PROP_NAME}" ]; then
		echo "Failed to set Propeller on EEPROM 1"
		success="Fail!"
	fi

	# Check Technician Initials
	if [ "$(echo "$ep1_result" | grep Tech: | awk '{print $4}')" != "${TECH}" ]; then
		echo "Failed to set Technician Initials on EEPROM 1"
		success="Fail!"
	fi

	# Check Serial
	if [ "$(echo "$ep1_result" | grep Serial: | awk '{print $4}')" != "${FR_SERIAL_NUM}" ]; then
		echo "Failed to set Serial on EEPROM 1"
		success="Fail!"
	fi
	echo ""

	################## EEPROM 2 ##################
	# Check Propulsion ID
	if [ "$(echo "$ep2_result" | grep ID: | awk '{print $4}')" != "${PROP_ID}" ]; then
		echo "Failed to set Propulsion ID on EEPROM 2"
		success="Fail!"
	fi

	# Check Location
	if [ "$(echo "$ep2_result" | grep Location: | awk '{print $4}')" != "BR" ]; then
		echo "Failed to set Location on EEPROM 2"
		success="Fail!"
	fi

	# Check Date
	if [ "$(echo "$ep2_result" | grep Date: | awk '{print $4}')" != "${DATE_OF_ASM}" ]; then
		echo "Failed to set Date on EEPROM 2"
		success="Fail!"
	fi

	# Check Assembly
	if [ "$(echo "$ep2_result" | grep Assembly: | awk '{print $4}')" != "${MOT_ASM_VER}" ]; then
		echo "Failed to set Assembly on EEPROM 2"
		success="Fail!"
	fi

	# Check Propeller
	if [ "$(echo "$ep2_result" | grep Prop: | awk '{print $4}')" != "${PROP_NAME}" ]; then
		echo "Failed to set Propeller on EEPROM 2"
		success="Fail!"
	fi

	# Check Technician Initials
	if [ "$(echo "$ep2_result" | grep Tech: | awk '{print $4}')" != "${TECH}" ]; then
		echo "Failed to set Technician Initials on EEPROM 2"
		success="Fail!"
	fi

	# Check Serial
	if [ "$(echo "$ep2_result" | grep Serial: | awk '{print $4}')" != "${BR_SERIAL_NUM}" ]; then
		echo "Failed to set Serial on EEPROM 2"
		success="Fail!"
	fi
	echo ""

	################## EEPROM 3 ##################
	# Check Propulsion ID
	if [ "$(echo "$ep1_result" | grep ID: | awk '{print $4}')" != "${PROP_ID}" ]; then
		echo "Failed to set Propulsion ID on EEPROM 3"
		success="Fail!"
	fi

	# Check Location
	if [ "$(echo "$ep3_result" | grep Location: | awk '{print $4}')" != "BL" ]; then
		echo "Failed to set Location on EEPROM 3"
		success="Fail!"
	fi

	# Check Date
	if [ "$(echo "$ep3_result" | grep Date: | awk '{print $4}')" != "${DATE_OF_ASM}" ]; then
		echo "Failed to set Date on EEPROM 3"
		success="Fail!"
	fi

	# Check Assembly
	if [ "$(echo "$ep3_result" | grep Assembly: | awk '{print $4}')" != "${MOT_ASM_VER}" ]; then
		echo "Failed to set Assembly on EEPROM 3"
		success="Fail!"
	fi

	# Check Propeller
	if [ "$(echo "$ep3_result" | grep Prop: | awk '{print $4}')" != "${PROP_NAME}" ]; then
		echo "Failed to set Propeller on EEPROM 3"
		success="Fail!"
	fi

	# Check Technician Initials
	if [ "$(echo "$ep3_result" | grep Tech: | awk '{print $4}')" != "${TECH}" ]; then
		echo "Failed to set Technician Initials on EEPROM 3"
		success="Fail!"
	fi

	# Check Serial
	if [ "$(echo "$ep3_result" | grep Serial: | awk '{print $4}')" != "${BL_SERIAL_NUM}" ]; then
		echo "Failed to set Serial on EEPROM 3"
		success="Fail!"
	fi
	echo ""

	################## EEPROM 4 ##################
	# Check Propulsion ID
	if [ "$(echo "$ep4_result" | grep ID: | awk '{print $4}')" != "${PROP_ID}" ]; then
		echo "Failed to set Propulsion ID on EEPROM 4"
		success="Fail!"
	fi

	# Check Location
	if [ "$(echo "$ep4_result" | grep Location: | awk '{print $4}')" != "FL" ]; then
		echo "Failed to set Location on EEPROM 4"
		success="Fail!"
	fi

	# Check Date
	if [ "$(echo "$ep4_result" | grep Date: | awk '{print $4}')" != "${DATE_OF_ASM}" ]; then
		echo "Failed to set Date on EEPROM 4"
		success="Fail!"
	fi

	# Check Assembly
	if [ "$(echo "$ep4_result" | grep Assembly: | awk '{print $4}')" != "${MOT_ASM_VER}" ]; then
		echo "Failed to set Assembly on EEPROM 4"
		success="Fail!"
	fi

	# Check Propeller
	if [ "$(echo "$ep4_result" | grep Prop: | awk '{print $4}')" != "${PROP_NAME}" ]; then
		echo "Failed to set Propeller on EEPROM 4"
		success="Fail!"
	fi

	# Check Technician Initials
	if [ "$(echo "$ep4_result" | grep Tech: | awk '{print $4}')" != "${TECH}" ]; then
		echo "Failed to set Technician Initials on EEPROM 4"
		success="Fail!"
	fi

	# Check Serial
	if [ "$(echo "$ep4_result" | grep Serial: | awk '{print $4}')" != "${FL_SERIAL_NUM}" ]; then
		echo "Failed to set Serial on EEPROM 4"
		success="Fail!"
	fi
	echo ""
	echo "$success"
}

run_raspberry_pi () {
	# Run our provisioning commands
	run_on_target "sudo systemctl stop prism_os.service"
	# Page index 0 is propulsion ID
	run_on_target "~/prism_os/tests/eeprom_test 1 write 0 ${PROP_ID}"
	run_on_target "~/prism_os/tests/eeprom_test 2 write 0 ${PROP_ID}"
	run_on_target "~/prism_os/tests/eeprom_test 3 write 0 ${PROP_ID}"
	run_on_target "~/prism_os/tests/eeprom_test 4 write 0 ${PROP_ID}"
	# Page index 1 is location
	run_on_target "~/prism_os/tests/eeprom_test 1 write 1 FR"
	run_on_target "~/prism_os/tests/eeprom_test 2 write 1 BR"
	run_on_target "~/prism_os/tests/eeprom_test 3 write 1 BL"
	run_on_target "~/prism_os/tests/eeprom_test 4 write 1 FL"
	# Page index 2 is date
	run_on_target "~/prism_os/tests/eeprom_test 1 write 2 ${DATE_OF_ASM}"
	run_on_target "~/prism_os/tests/eeprom_test 2 write 2 ${DATE_OF_ASM}"
	run_on_target "~/prism_os/tests/eeprom_test 3 write 2 ${DATE_OF_ASM}"
	run_on_target "~/prism_os/tests/eeprom_test 4 write 2 ${DATE_OF_ASM}"
	# Page index 3 is motor assemlby version
	run_on_target "~/prism_os/tests/eeprom_test 1 write 3 ${MOT_ASM_VER}"
	run_on_target "~/prism_os/tests/eeprom_test 2 write 3 ${MOT_ASM_VER}"
	run_on_target "~/prism_os/tests/eeprom_test 3 write 3 ${MOT_ASM_VER}"
	run_on_target "~/prism_os/tests/eeprom_test 4 write 3 ${MOT_ASM_VER}"
	# Page index 4 is Propeller name
	run_on_target "~/prism_os/tests/eeprom_test 1 write 4 ${PROP_NAME}"
	run_on_target "~/prism_os/tests/eeprom_test 2 write 4 ${PROP_NAME}"
	run_on_target "~/prism_os/tests/eeprom_test 3 write 4 ${PROP_NAME}"
	run_on_target "~/prism_os/tests/eeprom_test 4 write 4 ${PROP_NAME}"
	# Page index 5 is technician name
	run_on_target "~/prism_os/tests/eeprom_test 1 write 5 ${TECH}"
	run_on_target "~/prism_os/tests/eeprom_test 2 write 5 ${TECH}"
	run_on_target "~/prism_os/tests/eeprom_test 3 write 5 ${TECH}"
	run_on_target "~/prism_os/tests/eeprom_test 4 write 5 ${TECH}"
	# Page index 6 is serial number
	run_on_target "~/prism_os/tests/eeprom_test 1 write 6 ${FR_SERIAL_NUM}"
	run_on_target "~/prism_os/tests/eeprom_test 2 write 6 ${BR_SERIAL_NUM}"
	run_on_target "~/prism_os/tests/eeprom_test 3 write 6 ${BL_SERIAL_NUM}"
	run_on_target "~/prism_os/tests/eeprom_test 4 write 6 ${FL_SERIAL_NUM}"

	# Page index 31 is flight time
	run_on_target "~/prism_os/tests/eeprom_test 1 write 31 0"
	run_on_target "~/prism_os/tests/eeprom_test 2 write 31 0"
	run_on_target "~/prism_os/tests/eeprom_test 3 write 31 0"
	run_on_target "~/prism_os/tests/eeprom_test 4 write 31 0"

	run_on_target "sudo systemctl start prism_os.service"
}

print_help () {
	echo "Provision all 4 eeproms"
	echo "Parameters:"
	echo "- propulsion ID number (-i): 1 is quad, 2 is x8, etc"
	echo "- motor assembly version (-m)"
	echo "- propeller name (-p)"
	echo "- technician initials (-t)"
	echo "- FR serial number (-1)"
	echo "- BR serial number (-2)"
	echo "- BL serial number (-3)"
	echo "- FL serial number (-4)"
	echo ""
	echo "e.g:  ./provision_eeproms.sh -i 1 -m 1 -p FA28 -t JD -1 4000 -2 4001 -3 4002 -4 4003"
}

#__________________ Main _________________ #
if ! [ $1 ]; then
	interactive_arguments
else
	handle_arguments $@
fi

# Detect pi or skynode
get_target_ip
if ! [ $TARGET_IP ]; then
	echo "No device detected"
	exit 1
fi

wait_for_connected

# Check if it's a pi or a skynode
if [ $TARGET_USER == "pi" ]; then
	echo "Running on pi"
	run_raspberry_pi
else
	echo "Running on Skynode"
	run_skynode
fi
