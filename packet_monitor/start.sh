#!/bin/bash

sudo airmon-ng check kill
sudo airmon-ng start wlo1
sudo iw wlo1mon set channel 7

# Display filter options:
# wlan.fc.type_subtype == 0x8 && wlan.addr == 02:1f:7b:b5:dc:ea