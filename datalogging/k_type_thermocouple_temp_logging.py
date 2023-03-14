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

# Coefficients used later to convert mV to temp

# -200 C to 0 C
# -5.891 mV to 0 mV
voltsToTemp1 = (0.0E0,
                2.5173462E1,
                -1.1662878E0,
                -1.0833638E0,
                -8.977354E-1,
                -3.7342377E-1,
                -8.6632643E-2,
                -1.0450598E-2,
                -5.1920577E-4)

# 0 C to 500 C
# 0 mV to 20.644 mV
voltsToTemp2 = (0.0E0,
                2.508355E1,
                7.860106E-2,
                -2.503131E-1,
                8.31527E-2,
                -1.228034E-2,
                9.804036E-4,
                -4.41303E-5,
                1.057734E-6,
                -1.052755E-8)

# 500 C to 1372 C
# 20.644 mV to 54.886 mV
voltsToTemp3 = (-1.318058E2,
                4.830222E1,
                -1.646031E0,
                5.464731E-2,
                -9.650715E-4,
                8.802193E-6,
                -3.11081E-8)


# verifies mV reading is within expected value range
def voltsToTempConstants(mVolts):
    if mVolts < -5.891 or mVolts > 54.886:
        raise Exception("Invalid range")
    if mVolts < 0:
        return voltsToTemp1
    elif mVolts < 20.644:
        return voltsToTemp2
    else:
        return voltsToTemp3


# -270 C to 0 C
tempToVolts1 = (0.0E0,
                0.39450128E-1,
                0.236223736E-4,
                -0.328589068E-6,
                -0.499048288E-8,
                -0.675090592E-10,
                -0.574103274E-12,
                -0.310888729E-14,
                -0.104516094E-16,
                -0.198892669E-19,
                -0.163226975E-22)


class ExtendedList(list):
    def __init__(self):
        list.__init__(self)
        self.extended = None

# 0 C to 1372 C
tempToVolts2 = ExtendedList()
tempToVolts2.append(-0.176004137E-1)
tempToVolts2.append(0.38921205E-1)
tempToVolts2.append(0.1855877E-4)
tempToVolts2.append(-0.994575929E-7)
tempToVolts2.append(0.318409457E-9)
tempToVolts2.append(-0.560728449E-12)
tempToVolts2.append(0.560750591E-15)
tempToVolts2.append(-0.3202072E-18)
tempToVolts2.append(0.971511472E-22)
tempToVolts2.append(-0.121047213E-25)
tempToVolts2.extended = (0.1185976E0, -0.1183432E-3, 0.1269686E3)


# verified temp is within expected value range
def tempToVoltsConstants(tempC):
    if tempC < -270 or tempC > 1372:
        raise Exception("Invalid range: -270 to 1372 C")
    if tempC < 0:
        return tempToVolts1
    else:
        return tempToVolts2


# used to convert between mv and temp
def evaluatePolynomial(coeffs, x):
    tot = 0
    y = 1
    for a in coeffs:
        tot += y * a
        y *= x
    return tot


# uses coefficients to calculate temp
def tempCToMVolts(tempC):
    coeffs = tempToVoltsConstants(tempC)
    extendedCalc = 0;

    if hasattr(coeffs, "extended"):
        a0, a1, a2 = coeffs.extended
        extendedCalc = a0 * math.exp(a1 * pow(tempC - a2, 2))

    return evaluatePolynomial(coeffs, tempC) + extendedCalc


def mVoltsToTempC(mVolts):
    coeffs = voltsToTempConstants(mVolts)
    return evaluatePolynomial(coeffs, mVolts)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Logs temperature data using a LabJack U6 and K-type Thermocouple connected to AIN0.')
    parser.add_argument('-f', '--filename', type=str, help='file name to save log')
    parser.add_argument('-r', '--rate', type=int, default=10, help='rate to save data to log in Hz')
    args = parser.parse_args()
    
    labjack = u6.U6()
    labjack.getCalibrationData()

    print("\n\n\n########################################################")
    print("\nTemperature logging script using LabJack U6")
    print("and K-Type Thermocouple connected to AIN0")
    print("\n########################################################\n")

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

        while True:
            timestamp = time.strftime("%Y-%m-%d %H:%M:%S", time.localtime())

            # reads cold junction temperature
            CJTEMPinC = labjack.getTemperature() + 2.5 - 273.15

            # reads analog voltage from thermocouple
            TCmVolts = labjack.getAIN(0, resolutionIndex=8, gainIndex=3) * 1000

            # calculates mv required to calculate temp
            totalMVolts = TCmVolts + tempCToMVolts(CJTEMPinC)

            temp = mVoltsToTempC(totalMVolts)

            print(timestamp + "\t\t" + "%.2f" % temp + " Deg (C)")

            logWriter.writerow([timestamp, temp])

            time.sleep(1/loggingRateHz)
