###


import psutil
import socket
import requests
import csv
import time
import warnings
import datetime

#Ignore unsigned HTTPS
warnings.filterwarnings('ignore', message='Unverified HTTPS request')

gcsip = '172.20.207.75'

# Check connection to GCS and Aircraft    
def check_connection(host, port=80, timeout=1):
    socket.setdefaulttimeout(timeout)
    try:
        socket.socket(socket.AF_INET, socket.SOCK_STREAM).connect((host, port))

    except Exception as ex:
        return False
    return True

def get_internal_battery_percent():
    battery = psutil.sensors_battery()
    percent = battery.percent
    return percent

# Get current time and output formatted without milliseconds
def get_time():
    current_time = datetime.datetime.now()
    current_time = current_time.replace(microsecond=0)
    return current_time

connected_status = False

while connected_status == False:
    connected_status = check_connection(gcsip)
    if connected_status == False:
        print(f"Connected to GCS: {connected_status}")
        time.sleep(1)
    else:
        print(f"Connected to GCS: {connected_status}")
        break

start_time = get_time()
start_batt_percent = get_internal_battery_percent()

while connected_status == True:
    connected_status = check_connection(gcsip)
    if connected_status == True:
        current_time = get_time()
        percent = get_internal_battery_percent()
        print(f"{current_time} - Battery Percentage: {percent}%")
    else:
        print(f"Connected to GCS: {connected_status}")
        end_time = get_time()
        end_batt_percent = get_internal_battery_percent()
        print("##################################################################")
        print("Connection lost! Sony batteries dead!")
        print(f"Start Time: {start_time}")
        print(f"End Time: {end_time}")
        print(f"Start Battery Percentage: {start_batt_percent}%")
        print(f"End Battery Percentage: {end_batt_percent}%")
        print(f"Elapsed Time: {end_time - start_time}")
        break

print(f"Battery Percentage: {percent}%")
