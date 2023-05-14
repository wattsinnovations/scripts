#!/bin/python3

"""

Python script to provision that Watts Innovations smart battery BMS

This script is designed to run on a Raspberry Pi 4B with an Adafruit 128x64 OLED display

You must enable I2C on your Raspberry Pi to use this script. 

You must install the Adafruit-SSD1306 library to use this script.
    python -m pip install --upgrade pip setuptools wheel
    pip install Adafruit-SSD1306

    Or alternatively:

    python -m pip install --upgrade pip setuptools wheel
    git clone https://github.com/adafruit/Adafruit_Python_SSD1306.git
    cd Adafruit_Python_SSD1306
    python setup.py install



"""

#################################################
##
## Imports
##
#################################################

import time

import Adafruit_GPIO.SPI as SPI
import Adafruit_SSD1306

from PIL import Image
from PIL import ImageDraw
from PIL import ImageFont

import subprocess


#################################################
##
## Configure and initialize display
##
#################################################

# 128x64 display with hardware I2C:
disp = Adafruit_SSD1306.SSD1306_128_64(rst=None)

# Initialize library.
disp.begin()

# Clear display.
disp.clear()
disp.display()

# Create blank image for drawing.
width = disp.width
height = disp.height
image = Image.new('1', (width, height))

# Get drawing object to draw on image.
draw = ImageDraw.Draw(image)

# Set up padding around display borders
padding = -2
top = padding
bottom = height-padding
# Move left to right keeping track of the current x position for drawing shapes.
x = 0

# load arial font from /usr/share/fonts/truetype/freefont and set font size to 12
# font size is also used to set line spacing
font_size = 12
font = ImageFont.truetype('/usr/share/fonts/truetype/freefont/FreeSans.ttf', font_size)

#################################################
##
## Functions
##
#################################################


def clear_image():
    """
    Clears any text currently on the display
    """
    draw.rectangle((0,0,width,height), outline=0, fill=0)


def write_line_to_display(string, line_number):
    """
    Writes a line of text to the display at the specified line number
    """
    draw.text((x, top + line_number * font_size), string, font=font, fill=255)
    disp.image(image)
    disp.display()
    time.sleep(.1)
'''

while True:

    # Clear the image
    clear_image()

    # Shell scripts for system monitoring from here : https://unix.stackexchange.com/questions/119126/command-to-display-memory-usage-disk-usage-and-cpu-load
    cmd = "hostname -I | cut -d\' \' -f1"
    IP = subprocess.check_output(cmd, shell = True )
    cmd = "top -bn1 | grep load | awk '{printf \"CPU Load: %.2f\", $(NF-2)}'"
    CPU = subprocess.check_output(cmd, shell = True )
    cmd = "free -m | awk 'NR==2{printf \"Mem: %s/%sMB %.2f%%\", $3,$2,$3*100/$2 }'"
    MemUsage = subprocess.check_output(cmd, shell = True )
    cmd = "df -h | awk '$NF==\"/\"{printf \"Disk: %d/%dGB %s\", $3,$2,$5}'"
    Disk = subprocess.check_output(cmd, shell = True )

    # Write two lines of text.

    draw.text((x, top),       "IP: " + str(IP),  font=font, fill=255)
    draw.text((x, top+8),     str(CPU), font=font, fill=255)
    draw.text((x, top+16),    str(MemUsage),  font=font, fill=255)
    draw.text((x, top+58),    str(Disk),  font=font, fill=255)

    # Display image.
    disp.image(image)
    disp.display()
    time.sleep(.1)
''' 

def run_subprocess_with_progress(subprocess_command, progress, subprocess_number):
    """
    Runs a subprocess from the subprocess_commands array in main() and updates the progress array with the status of the subprocess
    """
   
    clear_image()
    s = f"Step {subprocess_number}..."
    print(f"Executing subprocess {subprocess_number}...")
    write_line_to_display(s, 1)

    # runs the subprocess and captures the return code
    process = subprocess.Popen(subprocess_command, shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    process.communicate()

    # checks the return code and updates the progress array
    if process.returncode == 0:
        progress[subprocess_number - 1] = 100
        print(f"Subprocess {subprocess_number} completed successfully!")
        s = f"Subprocess {subprocess_number} completed successfully!"
        write_line_to_display(s, 2)

        # calculates and prints the progress percentages
        completed_subprocesses = sum(1 for p in progress if p == 100)
        total_subprocesses = len(progress)
        progress_percentage = (completed_subprocesses / total_subprocesses) * 100
        progress_percentage = round(progress_percentage)

        print(f"Progress: {progress_percentage}%")
        s = f"Progress: {progress_percentage}%"
        write_line_to_display(s, 3)
   
        # checks if all subprocesses are complete
        if progress_percentage == 100:
            clear_image()
            print("Provisioning complete!")
            s = "Provisioning complete!"
            write_line_to_display(s, 1)

    # if the subprocess fails, updates the progress array and prints the failure message
    else:
        print(f"Subprocess {subprocess_number} failed!")
        s = f"Subprocess {subprocess_number} failed!"
        write_line_to_display(s, 3)
    print("")
    time.sleep(1)

    
def main():
    """
    the ole meat n potatoes right here
    """
    # Define the subprocess commands - REPLACE THESE WITH THE COMMANDS TO INITIATE EACH PROVISIONING STEP
    # example would be similar to below which would show the IP address
    # cmd = "hostname -I | cut -d\' \' -f1"
    # IP = subprocess.check_output(cmd, shell = True )
    # write_line_to_display(IP, 1)
    subprocess_commands = [
        "ifconfig",
        # routte is intentially wrong to validate the failure condition 
        "routte",
        "whoami",
        # Add the remaining subprocess commands here
    ]

    # Define the progress values for each subprocess
    progress = [0] * len(subprocess_commands)

    # Track the currently executing subprocess
    current_subprocess = 0

    # Start the while loop
    while current_subprocess < len(subprocess_commands):

        subprocess_command = subprocess_commands[current_subprocess]
        subprocess_number = current_subprocess + 1

        run_subprocess_with_progress(subprocess_command, progress, subprocess_number)

        # Check if the current subprocess completed successfully
        if progress[current_subprocess] == 100:
            current_subprocess += 1
        else:
            # If the current subprocess failed, break out of the while loop
            
            print("Provisioning failed!")
            s = "Provisioning failed!"
            write_line_to_display(s, 4)
            break
            #

if __name__ == "__main__":
    main()
