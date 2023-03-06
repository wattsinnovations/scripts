# README


## Prerequisites

Must change registry to bypass powershell script execution policies

Manually change GPS COM port to COM30 in device manager

Change Windows Explorer options to show hidden folders


## Instructions

Create scripts folder in root of C:\
Inside of C:\scripts create another folder called logs
Copy setGPSCOMsettings.ps1 and script.cmd to C:\scripts\
Create shortcut for script.cmd and save it in C:\Users\KONTACT\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\
Right click on shortcut, click properties and change the Run option to "MINIMIZED"
