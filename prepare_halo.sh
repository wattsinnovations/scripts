#!/bin/bash

UAS_ID=""
TARGET_IP="20.0.0.2"
COOKIES=""
FIRMWARE_FILE_PATH=""
EXPECTED_VERSION=$(echo '{
        "web":"1.15.0.1-10.4",
        "core":"2.12.1.0-10.4.1",
        "official":"10.4.1.0",
        "base":"0.12.0-10.3-aarch64"
    }' | jq -r --sort-keys . | tr -d " \"\r\n")


RedText=$'\e[1;31m'
GreenText=$'\e[1;32m'

wait_for_halo () {
    until login ; do
        echo "Waiting for Halo ($TARGET_IP) to login..."
        sleep 3
    done    

    until cellular_modems_are_ready ; do
        echo "Waiting for cellular modems to load and at least one SIM card to dial..."
        sleep 3
    done
}

login () {
    COOKIES=$(curl -s -c - --connect-timeout 3 -X POST -H "Content-Type: application/json" \
        -d '{"username": "admin", "password": "admin"}' \
        http://$TARGET_IP/api/v1/login)
    return $?
}

cellular_modems_are_ready () {
    login
    nics_status=$(curl -s --cookie <(echo "$COOKIES") http://$TARGET_IP/api/v1/nics/status)
    # echo $nics_status | jq
    # exit
    all_cellular_ips=$(echo $nics_status | jq -r '.nics.cellular_modem[] | .ip_address')
    num_of_modems="$(echo "$all_cellular_ips" | wc -l)"
    
    if [ "$num_of_modems" = "4" ]; then
        echo "$all_cellular_ips" | grep -E [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+ > /dev/null
        if [ "$?" = "0" ]; then
            echo "All modems are detected, and there's at least one valid IP address. waiting for full init..."
            sleep 5
            login
            return 0
        else
            echo "All modems are detected, waiting for a SIM card to successfully dial..."
            return 1
        fi
    else
        echo "Waiting for all modems to load, only $num_of_modems were detected so far"
        return 1
    fi
}

get_installed_version () {
    curl -s --cookie <(echo "$COOKIES")  -X GET http://$TARGET_IP/api/v1/versions | jq --sort-keys -r '.versions.installed' | tr -d " \"\r\n"
}

update_firmware () {
    echo "Updating to $FIRMWARE_FILE_PATH"

    success=$(curl -s --cookie <(echo "$COOKIES")  -X POST -F "file=@\"$FIRMWARE_FILE_PATH\";filename=\"halo_firmware.tar\"" http://$TARGET_IP/api/v1/update)

    if ! [ "$success" == "null" ]; then
        echo "${RedText}Failed to upgrade firmware"
        exit 1
    else
        echo "Halo firmware upgrade success"
    fi
}

get_serial_number () {
    SERIAL=$(curl -s --cookie <(echo "$COOKIES") http://$TARGET_IP/api/v1/serial | jq '.serial'| tr -d \")
}

reset_factory_settings () {
    echo "Reset Halo to Factory Settings... (auto reboot afterwards)"
    curl -s --cookie <(echo "$COOKIES") -X POST http://$TARGET_IP/api/v1/maintenance/factory_reset
}

set_nics_settings () {
    ETH1_IP1="20.0.0.2"
    ETH1_SUBNET1="255.255.255.0"
    ETH1_IP2="10.223.0.71"
    ETH1_SUBNET2="255.255.0.0"
    echo "Setting ETH-1 with the following IP Addresses:
    ETH-1:
        Static IP 1: $ETH1_IP1, Subnet: $ETH1_SUBNET1
        Static IP 2: $ETH1_IP2, Subnet: $ETH1_SUBNET2
        "
    result=$(curl -s --cookie <(echo "$COOKIES") -X PUT -H "Content-Type: application/json" -d "
    {\"settings\": {
        \"static_data\": [
            {
                \"gateway_address\": \"0.0.0.0\",
                \"ip_address\": \"$ETH1_IP1\",
                \"subnet_address\": \"$ETH1_SUBNET1\",
                \"dns_address\": \"\",
                \"used_for_data\": false
            },
            {
                \"gateway_address\": \"0.0.0.0\",
                \"ip_address\": \"$ETH1_IP2\",
                \"subnet_address\": \"$ETH1_SUBNET2\",
                \"dns_address\": \"\",
                \"used_for_data\": false
            }
        ],
        \"dhcp_settings\": null,
        \"built_in\": true}}" "http://$TARGET_IP/api/v1/nics/ethernet/eth0/settings")
    if [ "$result" = "null" ]; then
        echo "Done."
    else
        echo "${RedText}Settings NICs settings failed!"
    fi
}

import_vpn_profile () {
    echo "Searching VPN Certificate Folder for Halo: '$SERIAL'..."
    if ! [ -d "$VPN_CERTS_PATH/$SERIAL" ]; then
        echo "${RedText}Fail: Couldn't find certs folder: '$VPN_CERTS_PATH/$SERIAL'"
        exit 1
    else
        echo "Cert Folder Found. Importing to Halo..."
        CA="$VPN_CERTS_PATH/$SERIAL/L3_VPN/ca.crt"
        CERT="$VPN_CERTS_PATH/$SERIAL/L3_VPN/vpn.crt"
        KEY="$VPN_CERTS_PATH/$SERIAL/L3_VPN/vpn.key"
        success=$(curl -s --cookie <(echo "$COOKIES") -F "body={
        \"profile\":
            {\"name\": \"L3_VPN_env_ca\", \"mode\": 1, \"auto_activate\": false, \"config_source\": 1,
            \"config\":
                {\"encryption_type\": 3, \"compression_type\": 3, \"layer_type\": 2}
                }};type=application/json" \
                -F "ca_cert=@$CA;type=application/octet-stream" \
                -F "cert=@$CERT;type=application/octet-stream" \
                -F "key=@$KEY;type=application/octet-stream" \
        http://$TARGET_IP/api/v1/apps/openvpn/profiles)
    fi

    if ! [ "$success" = "null" ]; then
        echo "${RedText}Failed to import VPN profile"
        exit 1
    else
        echo "Import VPN profile success"
    fi
}

set_apn () {
    nic_id="$1"
    apn="$2"
    echo -n "  -> Setting $nic_id with $apn... "

    result=$(curl -s --cookie <(echo "$COOKIES") -X PUT -H "Content-Type: application/json" \
            -d "{\"dialing_rules\": {\"dial_type\": 1, \"username\": \"\", \"password\": \"\", \"auth_mode\": 0, \"apn\": \"$apn\", \"dial_number\": \"*99#\", \"pdp_type\": null}}" "http://$TARGET_IP/api/v1/nics/cellular-modem/$nic_id/dialingrules")
    echo $result
    if [ "$result" = "null" ]; then
        echo "APN set."
    else
        echo "${RedText}Failed to set APN!"
        exit 1
    fi
}

set_uas_id () {
    echo "Setting UAS ID: $UAS_ID"

    result=$(curl -s --cookie <(echo "$COOKIES") -X POST -H "Content-Type: application/json" -d "
    {\"is_enabled\": true, \"settings\": {
            \"is_ble_enabled\": false,
            \"is_utm_enabled\": false,
            \"utm_url\": null,
            \"basic_id\": \"$UAS_ID\",
            \"id_type\": 3,
            \"ua_type\": 2,
            \"self_id\": \"$UAS_ID\",
            \"operator_id\": \"\"
        }
    }" "http://$TARGET_IP/api/v1/advanced/remote_id")
    if [ "$result" = "null" ]; then
        echo "UAS ID set successfully"
    else
        echo "${RedText}warning: setting UAS ID failed, but can continue without it."
    fi
}

set_users () {
  source $NEW_USERS_SETTINGS
  # NEW_ADMIN_USERNAME, NEW_ADMIN_PWD, NEW_BASIC_USERNAME, NEW_BASIC_PWD
  echo "Adding user: '$NEW_BASIC_USERNAME'..."
  result=$(curl -s --cookie <(echo "$COOKIES") -X POST -H "Content-Type: application/json" -d "
    {\"user\": {
            \"name\": \"$NEW_BASIC_USERNAME\",
            \"password\": \"$NEW_BASIC_PWD\",
            \"permission_level\": 20,
            \"device_admin\": false
        }
    }" "http://$TARGET_IP/api/v1/users")
    if [ "$result" = "null" ]; then
        echo "Done."
    else
        echo "Failed to add user."
    fi

    echo "Changing admin user..."
    result=$(curl -s --cookie <(echo "$COOKIES") -X PUT -H "Content-Type: application/json" -d "
    {\"user\": {
            \"name\": \"$NEW_ADMIN_USERNAME\",
            \"is_utm_enabled\": false,
            \"password\": \"$NEW_ADMIN_PWD\",
            \"permission_level\": 24,
            \"device_admin\": true
        }
    }" "http://$TARGET_IP/api/v1/users/admin")
    if [ "$result" = "null" ]; then
        echo "Done."
    else
        echo "Failed to change admin."
    fi
}

check_configuration () {
    nics_status=$(curl -s --cookie <(echo "$COOKIES") http://$TARGET_IP/api/v1/nics/status)
    ip_addrs=$(echo "$nics_status" | jq '.nics.ethernet[1].current_ip_addresses' | tr -d \")
    wifi_ssid=$(echo "$nics_status" | jq '.nics.wifi[0].ssid' | tr -d \")

    # Print the data
    echo "=============================="
    echo "Halo configuration information"
    echo "=============================="
    echo "Serial:       $SERIAL"
    echo "eth1 IPs:     $ip_addrs"
    echo "WiFi SSID:    $wifi_ssid"
    echo "------------------------------"

    num_verizon=0
    num_att=0
    num_tmo=0

    while read -r data; do

        nic_id=$(echo $data | awk '{print $1}')
        slot=$(echo $data | awk '{print $2}')
        imei=$(echo $data | awk '{print $3}')
        iccid=$(echo $data | awk '{print $4}')
        carrier=$(echo $data | awk '{print $5}')

        # Check carrier and set APN if necessary
        if ! [ "$carrier" ]; then
            carrier="null"
        else
            if [ "$carrier" = "Verizon" ]; then
                set_apn "$nic_id" "TELIT.VZWENTP"
                num_verizon=$((num_verizon+1))
            elif [ "$carrier" = "at&t" ]; then
                set_apn "$nic_id" "30304.mcs"
                num_att=$((num_att+1))
            elif [ "$carrier" = "T-Mobile" ]; then
                num_tmo=$((num_tmo+1))
            fi
        fi

        echo "Modem $slot"
        echo "  ICCID       $iccid"
        echo "  Carrier     $carrier"
        echo "  IMEI        $imei"
        echo "------------------------------"
        done <<<$(echo "$nics_status" | jq -r '.nics.cellular_modem[] | .nic_id + " " + .usb_slot + " " + .imei + " " + .iccid + " " + .carrier')

    # We expect 2 Verizon and 2 T-Mobile sims
    # if [ "$num_tmo" = "2" ] && [ "$num_verizon" = "2" ]; then
    if [ "$num_tmo" = "2" ] && [ "$num_verizon" = "1" ] && [ "$num_att" = "1" ]; then
        echo "SIM combination: PASS"
    else
        echo "${RedText}SIM combination: FAILED"
        exit 1
    fi
}

#__________________ Main _________________ #
if ! [ $4 ]; then
    echo "Usage: prepare_halo.sh <firmware-file> <vpn_certs_path> <new_users_vars> <uas_id>"
    exit 1
fi

FIRMWARE_FILE_PATH="$1"
VPN_CERTS_PATH="$2"
NEW_USERS_SETTINGS="$3"
UAS_ID="$4"

if ! [ -d "$VPN_CERTS_PATH" ]; then
  echo "can't find VPN certs folder"
  exit 1
fi

if ! [ -f "$NEW_USERS_SETTINGS" ]; then
  echo "can't find users settings vars file. the expected format is:
NEW_ADMIN_USERNAME=\"<username>\"
NEW_ADMIN_PWD=\"<password>\"
NEW_BASIC_USERNAME=\"<username>\"
NEW_BASIC_PWD=\"<password>\"
"
  exit 1
fi

wait_for_halo

get_serial_number

echo "Preparing Halo: $SERIAL"

installed_version=$(get_installed_version)

if [ "$installed_version" = "$EXPECTED_VERSION" ]; then
    echo "Halo version is up to date, skipping upgrade."
else
    echo "Halo version is not up to date, upgrading..."
    echo "Installed version:"
    echo $installed_version
    echo "Expected version:"
    echo $EXPECTED_VERSION
    update_firmware
fi

reset_factory_settings

sleep 30

wait_for_halo

set_nics_settings

import_vpn_profile

set_uas_id

check_configuration

set_users

echo "${GreenText}Halo $SERIAL was prepared and tested successfully"

# ./prepare_halo.sh ../auterion/images/halo/10.4.1.0-HALO_22_06_16_core2.12.1.0_web1.15.0.1_base0.11.0.tar ../auterion/images/halo/prismsky_certs/ ../auterion/images/halo/halo_web_users.sh PRISMSKY99