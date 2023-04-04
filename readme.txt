Watts Setup and Provisioning Scripts Repo
-----------------------------------------

any script that requires a firmware path will need a separate directory named 'images',
with the appropriate firmware placed inside the folder


when setting up ODrive on 22.0.4, if python 3.10 errors are encountered when updating, try installing odrivetool 0.5.4

TODO: Create setup.sh to install all dependecies

-----------------------------------------

# EXAMPLES

Halo setup
----------
./prepare_halo.sh ../../images/halo/10.4.1.0-HALO_22_06_16_core2.12.1.0_web1.15.0.1_base0.11.0.tar ../../images/halo/prismsky_certs/ ../../images/halo/halo_web_users.sh PRISMSKY99

Skynode
----------

./skynode_update.sh <VehicleSerialNumber> <MachineType> <ConnectionType>
    Machine Type options: stock, du
    Connection Type options: usb, ip
    ---Examples--- 
    ./skynode_update.sh 6569 stock usb

./provision_eeproms.sh -i 2 -m 1.1 -p FA28 -t MF -1 $serialnum -2 $serialnum -3 $serialnum -4 $serialnum

./checkEEPROM.sh <ArmLocation>

AI Node
----------

./ai_node_update.sh

./checkUSBCam.sh

ODrive
----------

./odriveUpdate.sh


python3 odriveSetup.py

OG PRISM
----------

DoodleLabs
----------

Packet Monitor
----------

-----------------------------------------

