####################################
##
## very quick and dirty script to log temperature data 
## using the lm_sensors package on ubuntu
##
## sudo apt install lm_sensors
##
## this is very gross and should never be shown to the public
##
## cbaq 9.7.2023
##
####################################

import subprocess
import json
import time
from datetime import datetime

def get_sensors_data():
    # Run the sensors command and get the output in JSON format
    result = subprocess.run(['sensors', '-j'], capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError("Failed to execute sensors command.")  
    data = json.loads(result.stdout)  
    return data
    

def main():
    filename = "templog.csv"
    with open(filename, 'a', newline='') as file:
        while True:
            data = get_sensors_data()      
            for chip, chip_data in data.items():  
                if "temp" in str(chip_data):             
                    chip_data_list = str(chip_data).split(",")   
                    all_temps = str(chip) + ","
                    for value in chip_data_list:
                        if "temp" in value:
                            if "max" not in value:
                                if "alarm" not in value:
                                    if "crit" not in value:
                                        if "min" not in value:
                                        # print("VALUE: "+ value)
                                            value_list = value.split(":")
                                            i=0
                                            for i in value_list:
                                                if "input" not in i:
                                                    all_temps += i +","
                    all_temps = all_temps.replace("}"," ").replace("'"," ")            
                    timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
                    line = timestamp +","+all_temps
                    print(line)
                    file.write(str(line) + "\n")
            time.sleep(1)
       
if __name__ == "__main__":
    main()
