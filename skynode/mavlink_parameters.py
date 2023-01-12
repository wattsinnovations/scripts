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


def download_parameters(mav, sysid, compid):
	mav.mav.param_request_list_send(sysid, compid)
	count = 0
	expected_count = None
	parameters = []
	while True:
		m = mav.recv_match(type='PARAM_VALUE', blocking=True, timeout=10)

		if m is None:
			print("Cannot connect with component " + str(compid))
			sys.exit(1)
		if m.param_index == 65535:
			# print("volunteered parameter: %s" % str(m))
			continue
		if False:
			print("  received (%4u/%4u %s=%f" %
						  (m.param_index, m.param_count, m.param_id, m.param_value))
		if m.param_index >= m.param_count:
			raise ValueError("parameter index (%u) gte parameter count (%u)" %
							 (m.param_index, m.param_count))
		if expected_count is None:
			expected_count = m.param_count
		else:
			if m.param_count != expected_count:
				raise ValueError("expected count changed")

		# print("received: " + p.name + " -- " + str(p.value))
		p = ParameterMetadata(int(sysid), int(compid), str(m.param_id), param_value_from_type(m.param_value, m.param_type), int(m.param_type))

		# Check if entry is already in the array
		if p not in parameters:
			count += 1
			parameters.append(p)
			if count == expected_count:
				break
	return parameters


def upload_parameters(mav, sysid, compid, parameters):
	for p in parameters:
		if (p.compid != compid):
			print("Skipping " + p.name + " for CompID " + str(p.compid))
			continue
		set_param(mav, p)


def save_parameters_to_file(filename, parameters):
	f = open(filename, mode='w')
	for p in parameters:
		if p.type == mavutil.mavlink.MAV_PARAM_TYPE_REAL32:
			valuestr = str(format(p.value, '.18f'))
		else:
			valuestr = str(p.value)
		f.write(str(p.sysid) + '\t' + str(p.compid) + '\t' + p.name + '\t' + valuestr + '\t' + str(p.type) + '\n')


def load_parameters_from_file(filename):
	parameters = []
	print("Parsing parameter file")
	f = open(filename, mode='r')
	for line in f:
		line = line.strip()
		if not line or line[0] == "#":
			continue
		# Parse out all the tabs
		# [sysid][compid][NAME][value][type]
		a = line.split('\t', 4)
		if len(a) != 5:
			print("Invalid line: %s" % line)
			continue
		parameters.append(ParameterMetadata(int(a[0]), int(a[1]), str(a[2]), str(a[3]), int(a[4])))
	return parameters


def set_param(mav, param):
	parmdict = mavparm.MAVParmDict()
	success = parmdict.mavset(mav, param.name, param.value, retries=1, parm_type=param.type)
	print ("Set " + param.name + " to " + param.value if success else print("Set " + param.name + " failed"))
	return success


def param_value_from_type(value, ptype):
	if ptype != mavutil.mavlink.MAV_PARAM_TYPE_REAL32:
		if math.isnan(float(value)):
			nvalue = int(-1)
		else:
			nvalue = struct.unpack("<I", struct.pack("f", value))[0]
	else:
		nvalue = float(value)
	return nvalue


def main():
	parser = ArgumentParser(description=__doc__)
	parser.add_argument("--port", "-p", dest="port",
					  help="Mavlink port name: e.g. udp:10.223.100.50:14550", default="udp:10.223.100.50:14550")
	parser.add_argument("--compid", "-i", dest="compid",
					  help="Component ID of the device", default="161")

	parser.add_argument("--upload", "-u", dest="uploadParamFile",
					  help="Parameter file to load", default=None)


	parser.add_argument("--download", "-d", dest="downloadParamFile",
					  help="File name to download parameters into", default=None)

	args = parser.parse_args()

	mav = mavutil.mavlink_connection(args.port, autoreconnect=True)
	heartbeat = mav.wait_heartbeat(blocking=True, timeout=3)
	if(heartbeat == None):
		sys.exit("Did not get heartbeat....exiting.")

	# We have to send a heartbeat otherwise we won't get any data back to us
	mav.mav.heartbeat_send(mavutil.mavlink.MAV_TYPE_GCS, mavutil.mavlink.MAV_AUTOPILOT_GENERIC, 0, 0, 0)

	# Download parameters
	if args.downloadParamFile is not None:
		print("Downloading parameters from Component " + str(args.compid))
		sysid = 1 # sysid 1 is the autopilot
		parameters = download_parameters(mav, int(sysid), int(args.compid))
		filename = args.downloadParamFile + ".params"
		save_parameters_to_file(filename, parameters)

	# Upload parameters
	if args.uploadParamFile is not None:
		if ".params" in args.uploadParamFile:
			print("\nUploading parameters from file " + args.uploadParamFile)
			sysid = 1 # sysid 1 is the autopilot
			fileparameters = load_parameters_from_file(args.uploadParamFile)
			upload_parameters(mav, int(sysid), int(args.compid), fileparameters)
		else:
			print("Invalid parameter file")

	print("Done")


if __name__ == '__main__':
	main()
