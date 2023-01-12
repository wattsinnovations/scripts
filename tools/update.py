#! /usr/bin/env python3
import argparse
import os
import requests
import time
import enum
from datetime import datetime
try:
    from requests_toolbelt import MultipartEncoder, MultipartEncoderMonitor
    from tqdm import tqdm
except ImportError as e:
    print("Modules tqdm and requests-toolbelt are missing")
    print("Run 'pip3 install --user -r setup/requirements.txt'")
    exit(1)

UPDATE_ENDPOINT_BASE="http://{}/api/local-updater"
UPDATE_ARTIFACT_PATH="output/{}/update.auterionos"
TIMEOUT=900 # 15 minutes

class ExitCode(enum.Enum):
    SUCCESS = 0
    ARTIFACT_NOT_FOUND = 1
    UPDATE_FAILED = 2
    FMU_UPDATE_FAILED = 3
    DEVICE_NOT_CONNECTED = 4
    TIMEOUT = 5
    INCOMPATIBLE_API = 6
    CANCELLED = 10
    REQUEST_API_VERSION = 99

def get_api_version(url):
    try:
        response = requests.get(f"{url}/version",  timeout=5)
        if response and "version" in response.json():
            return response.json()["version"]
        elif response.status_code == 404:
            # The version route is not implemented in v1.0
            return "v1.0"
        else:
            return None
    except:
        return None

def refresh_progress_bar(monitor):
    if monitor.finished:
        return
    if monitor.last_bytes_read is None:
        monitor.progress_bar.update(monitor.bytes_read)
    else:
        monitor.progress_bar.update(monitor.bytes_read-monitor.last_bytes_read)
    monitor.last_bytes_read = monitor.bytes_read
    percentage = float(monitor.last_bytes_read) / float(monitor.total_size)
    if percentage > 1.0:
        monitor.finished = True
        monitor.progress_bar.close()
        print("Waiting for the device to complete the installation")

def upload_artifact(url, file_path):
    e = MultipartEncoder(fields={'file': (None, open(file_path,"rb"), 'application/octet-stream')})
    m = MultipartEncoderMonitor(e, refresh_progress_bar)
    m.last_bytes_read = None
    m.total_size = os.path.getsize(file_path)
    m.progress_bar = tqdm(desc="Uploading artifact", unit_scale=True, total=m.total_size)
    m.finished = False
    try:
        response = requests.post("{}/update".format(url), data=m)
        if response:
            return True
        else:
            print("Error: {}".format(response.text))
            return False
    except Exception as e:
        print(e)
        m.progress_bar.close()
        return False

def check_device_online(url):
    try:
        if requests.get("{}/ping".format(url)):
           return True
        if requests.get("{}/v1.0/ping".format(url)):
           return True
    except:
        try:
            if requests.get("{}/v1.0/ping".format(url)):
                return True
        except:
            return False
    return False

def get_device_status(url, reboot_counter, last_status=None):
    status = None
    try:
        response = requests.get("{}/status".format(url), timeout=1)
        if response and "status" in response.json():
            status = response.json()["status"]
        elif response.status_code == 404:
            return False, ExitCode.REQUEST_API_VERSION, None, reboot_counter
    except:
        if reboot_counter > 5:
            status = "REBOOTING"
        else:
            status = last_status
            reboot_counter += 1
    # if status == "UPLOADING":
    #     # We do nothing
    code = None
    if last_status != status:
        if last_status == "REBOOTING":
            # Force to request the API
            return False, ExitCode.REQUEST_API_VERSION, None, reboot_counter
        if status == "INSTALLING":
            print("Waiting for the device to complete the installation")
        elif status == "INSTALLED":
            print("Waiting for the device to reboot")
        elif status == "REBOOTING":
            print("Device is rebooting")
        elif status == "REBOOTED":
            print("Device rebooted")
        elif status == "VERIFICATION":
            print("Update verification")
        elif status == "FMU_UPDATE":
            print("Update FMU")
        elif status == "FMU_UPDATE_SUCCEED":
            print("FMU updated successfully")
        elif status == "CUSTOM_APP_INSTALL":
            print("Installing custom apps")
        elif status == "FMU_UPDATE_FAILED":
            print("FMU update failed")
            code = ExitCode.FMU_UPDATE_FAILED
        elif status == "REPARTITIONING":
            print("Device is being repartitioned")
        elif status == "SUCCEED":
            print("The device has been updated successfully")
            code = ExitCode.SUCCESS
        elif status == "APP_INSTALL_SUCCEED":
            print("Application has been installed successfully")
            code = ExitCode.SUCCESS
        elif status == "APP_INSTALL_FAILED":
            print("Application installation failed.")
            code = ExitCode.UPDATE_FAILED
        elif status == "FAILED":
            print("Update verification failed. The system has been rollbacked")
            code = ExitCode.UPDATE_FAILED
        elif status == "NEED_POWER_CYCLE":
            print("The device has been updated successfully, you need to powercycle your drone to complete the update.")
            code = ExitCode.SUCCESS
        elif status == "CANCELLED":
            print("Update has been cancelled")
            code = ExitCode.CANCELLED
    return code != None, code, status, reboot_counter

def update_failed():
    print("Failed to update the device")
    exit(1)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--artifact", help="artifact path")
    parser.add_argument("--device-ip", default="10.41.1.1", help="artifact path")
    args = parser.parse_args()
    artifact_path = args.artifact
    device_ip = args.device_ip
    UPDATE_ENDPOINT = UPDATE_ENDPOINT_BASE.format(device_ip)
    if artifact_path is None:
        print("Artifact path is missing")
        exit(1)
    print("Looking for the update artifact")
    if os.path.exists(artifact_path):
        print("Check if your device is online...")
        if check_device_online(UPDATE_ENDPOINT):
            version = get_api_version(UPDATE_ENDPOINT)
            if version is None:
                print("Your device is not connected")
                exit(4)
            url = "{}/{}".format(UPDATE_ENDPOINT, version)
            print("API: {}".format(version))
            if upload_artifact(url, artifact_path):
                final_state = False
                code = 0
                reboot_counter = 0
                last_status = None
                start = datetime.now()
                while not final_state and (datetime.now() - start).seconds <= TIMEOUT:
                    time.sleep(1)
                    final_state, code, last_status, reboot_counter = get_device_status(url, reboot_counter, last_status)
                    if code == ExitCode.REQUEST_API_VERSION:
                        # We might have rebooted on a previous version of local-updater
                        version = get_api_version(UPDATE_ENDPOINT)
                        if version is None:
                            print("Failed to get API version after reboot")
                            exit(ExitCode.INCOMPATIBLE_API.value)
                        url = "{}/{}".format(UPDATE_ENDPOINT, version)
                        print("API: {}".format(version))
                if (datetime.now() - start).seconds > TIMEOUT:
                    print("Update timeout")
                    exit(ExitCode.TIMEOUT.value)
                else:
                    exit(code.value)
            else:
                update_failed()
        else:
            print("Your device is not connected")
            exit(ExitCode.DEVICE_NOT_CONNECTED.value)
    else:
        print("Update artifact not found")
        exit(ExitCode.ARTIFACT_NOT_FOUND.value)

if __name__ == "__main__":
    main()
