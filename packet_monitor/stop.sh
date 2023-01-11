#!/bin/bash

sudo airmon-ng stop wlo1mon
sudo systemctl start wpa_supplicant.service
sudo systemctl start NetworkManager.service