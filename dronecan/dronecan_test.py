#!/bin/python3

import dronecan, time, math
from argparse import ArgumentParser
import logging

import sys
import os
import base64
import struct
import zlib

# firmware_dir = '/home/jake/code/wi/px4_watts_private/build/watts_can-bms_default/'
# firmware_path = ''

# files = os.listdir(firmware_dir)
# for file in files:
#     if file.endswith('.uavcan.bin'):
#         firmware_path = firmware_dir + file;
#         firmware_path = os.path.normcase(os.path.abspath(firmware_path))
#         print(firmware_path)


file_path = '/home/jake/fw.uavcan.bin'
firmware_path = '/home/jake/fw.uavcan.bin'

try:
    with open(firmware_path, 'rb') as f:
        f.read(100)
except Exception as ex:
    sys.exit(1)

parser = ArgumentParser(description='dump all DroneCAN messages')
parser.add_argument("--bitrate", default=1000000, type=int, help="CAN bit rate")
parser.add_argument("--node-id", default=100, type=int, help="CAN node ID")
parser.add_argument("--dna-server", action='store_true', default=True, help="run DNA server")
parser.add_argument("--port", default='/dev/ttyACM0', type=str, help="serial port")
parser.add_argument("--app-firmware", default=firmware_path, type=str, help="serial port")

args = parser.parse_args()

# logging.basicConfig(level=logging.DEBUG)

# Set up this node as dna_server
global node
node = dronecan.make_node(args.port, node_id=args.node_id, bitrate=args.bitrate)

node_monitor = dronecan.app.node_monitor.NodeMonitor(node)

if args.dna_server:
    dynamic_node_id_allocator = dronecan.app.dynamic_node_id.CentralizedServer(node, node_monitor)


# Waiting for at least one other node to appear online
while len(node_monitor.get_all_node_id()) < 1:
    print('Waiting for other nodes to become online...' + str(len(node_monitor.get_all_node_id())))
    node.spin(timeout=1)

target_node_id = int(list(node_monitor.get_all_node_id())[0])
print("Discovered node: " + str(target_node_id))


# Set up the file server for firmware udpdate
# file_path = base64.b64encode(struct.pack("<I",zlib.crc32(bytearray(args.app_firmware,'utf-8'))))[:7].decode('utf-8')
# print(file_path)


file_server = dronecan.app.file_server.FileServer(node, lookup_paths=firmware_path)


update_started = False
update_complete = False

def on_node_status(e):
    global update_started
    global update_complete

    if e.transfer.source_node_id == target_node_id and e.message.mode == e.message.MODE_SOFTWARE_UPDATE \
    and e.message.health < e.message.HEALTH_ERROR:
        if not update_started:
            print('Performing update')
            update_started = True;
    else:
        if update_started:
            print('Update complete')
            update_complete = True;


def on_response(e):
    if e is not None:
        print('Firmware update response:', e.response)
        if e.response.error != e.response.ERROR_IN_PROGRESS:
            node.defer(3, request_update)


def request_update():
    global update_started

    print('REQUESTING UPDATE')
    request = dronecan.uavcan.protocol.file.BeginFirmwareUpdate.Request(
                source_node_id=node.node_id,
                image_file_remote_path=dronecan.uavcan.protocol.file.Path(path=file_path))

    if not update_started:
        node.request(request, target_node_id, on_response, priority=30)



node_status_handle = node.add_handler(dronecan.uavcan.protocol.NodeStatus, on_node_status)

request_update()

while not update_started or not update_complete:
    try:
        node.spin(0.1)

    except KeyboardInterrupt:
        sys.exit(0)
        pass