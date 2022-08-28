#!/bin/bash

TARGET_IP="20.0.0.2"
COOKIES="cookies.txt"
FIRMWARE_FILE_PATH=""
EXPECTED_FW=$(echo '{
        "web":"1.16.0.1-10.5",
        "core":"2.12.1.0-10.4.1",
        "official":"10.4.1.0",
        "base":"0.12.0-10.3-aarch64"
    }' | jq -r --sort-keys . | tr -d " \"\r\n")


wait_for_halo () {
    until login ; do
        echo ""
        echo "waiting for Halo ($TARGET_IP) to login..."
        sleep 3
    done    
    echo ""
    
    until cellular_modems_are_ready ; do
        echo ""
        echo "waiting for cellular modems to load and at least one SIM card to dial..."
        sleep 3
    done
    echo ""
}

ping_success () {
    # Try pinging Halo ETH-1
    pingres=$(ping $TARGET_IP -i 0.2 -c 5 -w 1)
    loss=$(echo "$pingres" | grep "packet loss" | awk '{print $6}')
    loss=${loss%?}

    if [ "$loss" == "0" ]; then
        echo "Discovered $TARGET_IP"
    fi

    return $result
}

login () {
    curl -s -c "$COOKIES" --connect-timeout 3 -X POST -H "Content-Type: application/json" -d '{"username": "admin", "password": "admin"}' http://$TARGET_IP/api/v1/login > /dev/null
    return $?
}

cellular_modems_are_ready () {
    login
    all_cellular_ips=$(curl -s -b cookies.txt http://$TARGET_IP/api/v1/nics/status | jq -r '.nics.cellular_modem[] | .ip_address')
    num_of_modems="$(echo "$all_cellular_ips" | wc -l)"
    
    if [ "$num_of_modems" = "4" ]; then
        echo "$all_cellular_ips" | grep -E [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+ > /dev/null
        if [ "$?" = "0" ]; then
            echo "all modems are detected, and there's at least one valid IP address. waiting for full init..."
            sleep 5
            login
            return 0
        else
            echo "all modems are detected, waiting for a SIM card to successfully dial..."
            return 1
        fi
    else
        echo "waiting for all modems to load, only $num_of_modems were detected so far"
        return 1
    fi
}

reboot () {
    # This fully reboots it, which takes too long
    curl -v -b cookies.txt -X POST http://$TARGET_IP/api/v1/reboot
}

get_installed_version () {
    curl -s -b "$COOKIES" -X GET http://$TARGET_IP/api/v1/versions | jq --sort-keys -r '.versions.installed' | tr -d " \"\r\n"
}

update_firmware () {
    echo "Updating to $FIRMWARE_FILE_PATH"

    success=$(curl -s -b "$COOKIES" -X POST -F "file=@\"$FIRMWARE_FILE_PATH\";filename=\"halo_firmware.tar\"" http://$TARGET_IP/api/v1/update)

    if ! [ "$success" == "null" ]; then
        echo "Failed to upgrade firmware"
        exit 1
    else
        echo "Halo firmware upgrade success"
    fi
}

get_serial_number () {
    # Read Seral number
    SERIAL=$(curl -s -b cookies.txt http://$TARGET_IP/api/v1/serial | jq '.serial'| tr -d \")
}

get_halo_ssid () {
    # Get the SSID from the unconfigured halo
    nics_status=$(curl -s -b cookies.txt http://$TARGET_IP/api/v1/nics/status)
    SSID_TMP_FILE_PATH="/tmp/halo_${SERIAL}_ssid"
    echo $nics_status | jq '.nics.wifi[0].settings.configuration[0].ssid' > $SSID_TMP_FILE_PATH
}

set_halo_ssid () {
    # Get the settings JSON and write back the original SSID
    SSID=$(cat "$SSID_TMP_FILE_PATH" | tr -d \r\n)
    nics_status=$(curl -s -b cookies.txt http://$TARGET_IP/api/v1/nics/status)
    settings=$(echo $nics_status | jq --arg ssid "$SSID" '.nics.wifi[0].settings.configuration[0].ssid = "$ssid"')
    newsettings=$(echo $settings | jq '.nics.wifi[0].settings')

    success=$(curl -s -b cookies.txt -X PUT -H "Content-Type: application/json" \
        -d "{\"settings\": $newsettings}" \
        http://$TARGET_IP/api/v1/nics/wifi/wlan0/settings)

    if ! [ "$success" == "null" ]; then
        echo "Failed to update SSID"
        exit 1
    else
        echo "SSID update success"
    fi
}

import_halo_configuration () {
    success=$(curl -s -b cookies.txt -F "body={\"password\": \"123456\"};type=application/json" -F "tar_file=@$SETTINGS_TO_IMPORT;type=application/gzip" \
        http://$TARGET_IP/api/v1/maintenance/import_configuration)

    if ! [ "$success" == "null" ]; then
        echo "Failed to import configuration"
        exit 1
    else
        echo "Import configuration success"
    fi
}

export_halo_config () {
    # export config from a fully configured reference Halo device
    EXPORT_PATH="exported_halo_config.tar.gz"
    rm -f "$EXPORT_PATH"
    curl -s -b cookies.txt -X POST  -H "Content-Type: application/json" -d '{"password": "123456"}' \
        http://$TARGET_IP/api/v1/maintenance/export_configuration -o "$EXPORT_PATH"
    if [ -f "$EXPORT_PATH" ]; then
        echo "config exported successfully."
    else
        echo "config export failed!"
    fi
}

reboot_halo () {
    curl -s -b cookies.txt -X POST http://$TARGET_IP/api/v1/reboot
}

set_apn () {
    nic_id="$1"
    apn="$2"
    echo -n "  -> Setting $nic_id with $apn... "
    
    result=$(curl -s -b cookies.txt -X PUT -H "Content-Type: application/json" -d '{"dialing_rules": {"dial_type": 1, "username": "", "password": "", "auth_mode": 0, "apn": "$apn", "dial_number": "*99#", "pdp_type": null}}' "http://$TARGET_IP/api/v1/nics/cellular-modem/$nic_id/dialingrules")
    if [ "$result" = "null" ]; then
        echo "done."
    else
        echo "failed!!!"
    fi
    
}

check_configuration () {
    # Read Seral number
    serial=$(curl -s -b cookies.txt http://$TARGET_IP/api/v1/serial | jq '.serial'| tr -d \")

    # Read NICs status
    nics_status=$(curl -s -b cookies.txt http://$TARGET_IP/api/v1/nics/status)
    # Extract the IP address
    ip_addr=$(echo "$nics_status" | jq '.nics.ethernet[0].settings.static_data[1].TARGET_IP' | tr -d \")
    wifi_ssid=$(echo "$nics_status" | jq '.nics.wifi[0].ssid' | tr -d \")

    # Print the data
    echo "=============================="
    echo "Halo configuration information"
    echo "=============================="
    echo "Serial:       $serial"
    echo "IP eth0:      $ip_addr"
    echo "WiFi SSID:    $wifi_ssid"
    echo "------------------------------"
    
    num_verizon=0
    num_att=0
    num_tmo=0
    
    echo "$nics_status" | jq -r '.nics.cellular_modem[] | .nic_id + " " + .usb_slot + " " + .imei + " " + .iccid + " " + .carrier' | while read -r data; do
        nic_id=$(echo $data | awk '{print $1}')
        slot=$(echo $data | awk '{print $2}')
        imei=$(echo $data | awk '{print $3}')
        iccid=$(echo $data | awk '{print $4}')
        carrier=$(echo $data | awk '{print $5}')

        
        echo "Modem $slot"
        
        if ! [ "$carrier" ]; then
            carrier="null"
        else
            if [ "${carrier,,}" = "pelephone" ]; then
                set_apn "$nic_id" "TELIT.VZWENTP"
                num_verizon=$((num_verizon + 1))
            elif [ "${carrier,,}" = "at&t" ]; then
                set_apn "$nic_id" "30304.mcs"
                num_att=$((num_att + 1))
            elif [ "${carrier,,}" = "t-mobile" ]; then
                num_tmo=$((num_tmo + 1))
            fi
        fi

        echo "  ICCID       $iccid"
        echo "  Carrier     $carrier"
        echo "  IMEI        $imei"
        
        echo "------------------------------"
        done
    
    if [ "$num_tmo" = "2" ] && [ "$num_verizon" = "1" ] && [ "$num_att" = "1" ]; then
        echo "SIM combination: PASS"
    else
        echo "SIM combination: FAILED"
        exit 1
    fi
}

#__________________ Main _________________ #
if ! [ $2 ]; then
    echo "Usage: prepare_halo.sh <path to firmware upgrade file> <path to configuration file to import>"
    exit 1
fi

FIRMWARE_FILE_PATH="$1"
SETTINGS_TO_IMPORT="$2"

wait_for_halo

get_serial_number

echo "preparing Halo: $SERIAL";

installed_version=$(get_installed_version)

echo "Installed Version: $installed_version"
if [ "$installed_version" = "$EXPECTED_FW" ]; then
    echo "Halo version is updated, skipping upgrade."
else
    echo "Halo version is different than expected: $EXPECTED_FW. upgrading..."
    update_firmware
fi

get_halo_ssid

if [ "$SETTINGS_TO_IMPORT" = "export" ]; then
    export_halo_config
    exit
fi

import_halo_configuration

reboot_halo

sleep 30

wait_for_halo

set_halo_ssid

check_configuration

echo "Halo $SERIAL was prepared and tested successfully"