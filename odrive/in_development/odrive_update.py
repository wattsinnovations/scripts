#!/usr/bin/env python3

import sys
from io import StringIO

import fibre.discovery
from fibre import Logger, Event
import odrive
import odrive.dfu
from odrive.configuration import *

import tkinter as tk
from tkinter import filedialog

def exit():
	window.destroy()

def upload_firmware():

	file_path = filedialog.askopenfilename()

	# Disable the button
	label.config(text = "Flashing...")
	button.config(state='disabled')
	window.update()

	# Setup args to pass to upload function
	class Nargs:
		def __init__(self, serial, file):
			self.serial_number = serial
			self.file = file

	nargs = Nargs(serial_number, file_path)

	odrive.dfu.launch_dfu(nargs, logger, app_shutdown_token)

	label.config(text = "Finished")

	button.config(text='Exit', state='normal', command=lambda: exit())


if __name__ == '__main__':

	# Set up ODrive
	logger = Logger(verbose=True)

	app_shutdown_token = Event()

	serial_number = None

	my_odrive = odrive.find_any(serial_number=serial_number,
									  search_cancellation_token=app_shutdown_token,
									  channel_termination_token=app_shutdown_token)

	sys.stdin = StringIO("y\ny") # answer yes to prompt(s)

	# Set up UI
	window = tk.Tk()
	window.resizable(False, False)
	window.title('ODrive Update')
	window.geometry("200x80")
	label = tk.Label(window,
				text = "Select ODrive Firmware",
				width = 25, height = 2)


	# Set up button callback
	button = tk.Button(window, text='Open', width=10, command=lambda: upload_firmware())

	label.grid(column = 1, row = 1)
	button.grid(column = 1, row = 2)

	window.mainloop()