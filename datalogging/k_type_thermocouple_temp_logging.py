#!/bin/python3

################################################
#
# Simple python code to read a K-type thermocouple and log
# to a CSV. Can be used for multiple applications.
#
# Tested only on windows
#
# pip install -r requirements.txt
#
# Thermocouple used: https://media.digikey.com/pdf/Data%20Sheets/Digilent%20PDFs/240-080_Web.pdf
#
# Details of k-type thermocouple measurments used in this script originated from LabJackPython example:
# https://github.com/labjack/LabJackPython/blob/master/Examples/ktypeExample.py
#
# https://srdata.nist.gov/its90/type_k/kcoefficients.html
#
# Watts Innovations - Chris Baquol 3.8.2023
#
###############################################

import math
import time
import csv
import pathlib
import argparse

# labjack U6
import u6
from thermocouples_reference import thermocouples


if __name__ == '__main__':

    print("\n\n\n########################################################")
    print("\nTemperature logging script using LabJack U6")
    print("and K-Type Thermocouple connected to AIN0")
    print("\n########################################################\n")

    parser = argparse.ArgumentParser(description='Logs temperature data using a LabJack U6 and K-type Thermocouple connected to AIN0.')
    parser.add_argument('-f', '--filename', type=str, help='file name to save log')
    parser.add_argument('-r', '--rate', type=int, default=10, help='rate to save data to log in Hz')
    args = parser.parse_args()
    
    labjack = u6.U6()
    labjack.getCalibrationData()

    if args.filename:
        fileName = args.filename
    else:
        fileName = input("Enter log file name (automatically saved as .csv): ")
        
    timestamp = time.strftime("%Y-%m-%d %H.%M.%S", time.localtime())
    logPath = str(pathlib.Path(__file__).parent.resolve()) + "\\" + fileName + "-" + timestamp + ".csv"

    loggingRateHz = args.rate
   
    print("\nSaving data at " + str(loggingRateHz) + "Hz")
    print("\nLog file: " + logPath)

    with open(logPath, mode='w', newline='') as logFile:

        logWriter = csv.writer(logFile, delimiter=',', quotechar='"', quoting=csv.QUOTE_MINIMAL)

        # CSV Header
        logWriter.writerow(['Time', 'Temperature (C)'])

        print("\n\nTime\t\t\t\tTemperature(C)")

        typeK = thermocouples['K']

        while True:
            timestamp = time.strftime("%Y-%m-%d %H:%M:%S", time.localtime())

            # Reads cold junction temperature in Kelvin
            coldJunctTempC = labjack.getTemperature() + 2.5 - 273.15

            # Reads analog voltage from thermocouple
            thermoCoupleMillvolt = labjack.getAIN(0, resolutionIndex=8, gainIndex=3) * 1000

            # Use measured millivolts and cold junction temperature to caclulate thermocouple temperature
            tempC = typeK.inverse_CmV(thermoCoupleMillvolt, Tref=coldJunctTempC)

            print(timestamp + "\t\t" + "%.2f" % tempC + " Deg (C)")

            logWriter.writerow([timestamp, tempC])

            time.sleep(1/loggingRateHz)
