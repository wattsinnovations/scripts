#!/usr/bin/env python3

from argparse import ArgumentParser
from pymavlink import mavutil, mavparm
import sys, fnmatch, os, time, struct, math

class ParameterMetadata:
	def __init__(self, sysid, compid, name, value, ptype):
		self.sysid = sysid
		self.compid = compid
		self.name = name
		self.value = value
		self.type = ptype


def param_value_encoded_from_type(value, ptype):
	if ptype == mavutil.mavlink.MAV_PARAM_EXT_TYPE_REAL32:
		data = bytearray(struct.pack("f", float(value)))
	elif ptype == mavutil.mavlink.MAV_PARAM_EXT_TYPE_INT32:
		data = bytearray(struct.pack("i", int(value)))
	else:
		data = bytearray(str(value), 'utf-8')
	return data


def send_ext_param(mav, sysid, compid, p):
	data = param_value_encoded_from_type(p.value, p.type)
	mav.mav.param_ext_set_send(sysid, compid, bytes(p.name.upper(),'utf-8'), data, p.type)


# Parse a key/value pair with delimiter '='
def parse_var(pair):
	items = pair.split('=')
	key = items[0].strip() # we remove blanks around keys, as is logical
	if len(items) > 1:
		# rejoin the rest:
		value = '='.join(items[1:])
	return (key, value)


# Parse a series of key-value pairs and return a dictionary
def parse_vars(items):
	d = {}
	if items:
		for item in items:
			key, value = parse_var(item)
			d[key] = value
	return d


def isfloat(x):
    try:
        a = float(x)
    except (TypeError, ValueError):
        return False
    else:
        return True


def isint(x):
    try:
        a = float(x)
        b = int(a)
    except (TypeError, ValueError):
        return False
    else:
        return a == b and not '.' in x


def coerce_value(v):
	if isint(v):
		return int(v)
	elif isfloat(v):
		return float(v)
	else:
		return str(v)


def type_from_value(value):
	if type(value) is str:
		return mavutil.mavlink.MAV_PARAM_EXT_TYPE_CUSTOM
	elif type(value) is int:
		return mavutil.mavlink.MAV_PARAM_EXT_TYPE_INT32
	elif type(value) is float:
		return mavutil.mavlink.MAV_PARAM_EXT_TYPE_REAL32


def main():
	parser = ArgumentParser(description=__doc__)
	parser.add_argument("--port", "-p", dest="port",
					  help="Mavlink port name: e.g. udp:10.223.100.50:14550", default="udp:10.223.100.50:14550")

	parser.add_argument("--compid", "-i", dest="compid",
					  help="Component ID of the device", default="191")

	parser.add_argument("--set", "-s", dest="params",
						metavar="KEY=VALUE", nargs='+',
						help="Set a number of key-value pairs")

	args = parser.parse_args()

	mav = mavutil.mavlink_connection(args.port, autoreconnect=True)
	heartbeat = mav.wait_heartbeat(blocking=True, timeout=3)
	if(heartbeat == None):
		sys.exit("Did not get heartbeat....exiting.")

	# We have to send a heartbeat otherwise we won't get any data back to us
	mav.mav.heartbeat_send(mavutil.mavlink.MAV_TYPE_GCS, mavutil.mavlink.MAV_AUTOPILOT_GENERIC, 0, 0, 0)

	time.sleep(1)

	params = parse_vars(args.params)

	# We always use a sysid of 1 which corresponds to the aircraft itself
	sysid = 1

	parameters = []
	for p in params:
		name = p
		value = coerce_value(params[p])
		ptype = type_from_value(value)
		parameters.append(ParameterMetadata(sysid, args.compid, name, value, ptype))


	# Start param transaction with Auterion OS
	# mav.mav.command_long_send(sysid, 191, mavutil.mavlink.MAV_CMD_PARAM_TRANSACTION,
	# 							mavutil.mavlink.PARAM_TRANSACTION_ACTION_START,
	# 							Mavutil.mavlink.PARAM_TRANSACTION_TRANSPORT_PARAM_EXT,
	# 							69,
	# 							0, 0, 0, 0)
	mav.mav.command_long_send(sysid, int(args.compid), 900, 0,
								0,
								1,
								124,
								0, 0, 0, 0)

	time.sleep(1)

	for p in parameters:
		print(p.name + " --> " + str(p.value))
		send_ext_param(mav, int(sysid), int(args.compid), p)


	# Commit param transaction with Auterion OS
	mav.mav.command_long_send(sysid, int(args.compid), 900, 0,
								1,
								1,
								124,
								0, 0, 0, 0)

	time.sleep(1)

	print("Done")


if __name__ == '__main__':
	main()
