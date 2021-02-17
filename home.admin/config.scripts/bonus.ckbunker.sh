#!/bin/bash

# https://github.com/lightninglabs/ckbunker/releases-
pinnedVersion="v0.9"

# command info
if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "-help" ]; then
 echo "config script to switch the CKbunkeer on or off"
 echo "bonus.ckbunker.sh [on|off|menu|setup|run]"
 echo "Installs CKBunker $pinnedVersion"
 exit 1
fi

source /mnt/hdd/raspiblitz.conf

# add default value to raspi config if needed
if ! grep -Eq "^ckbunker=" /mnt/hdd/raspiblitz.conf; then
  echo "ckbunker=off" >> /mnt/hdd/raspiblitz.conf
fi

# show info menu
if [ "$1" = "menu" ]; then
  dialog --title " Info CKBunker Service " --msgbox "\n\
Usage and examples: https://github.com/Coldcard/ckbunker\n
Use the shortcut 'ckbunker' in the terminal to switch to the dedicated user.\n
Type 'ckbunker' again to see the available options.
" 10 56
  exit 0
fi

# stop services
echo "making sure the ckbunker.service is not running"
sudo systemctl stop ckbunker 2>/dev/null

# switch on
if [ "$1" = "1" ] || [ "$1" = "on" ]; then
  echo "# Install CKBunker"
  isInstalled=$(sudo ls /etc/systemd/system/ckbunker.service 2>/dev/null | grep -c 'ckbunker.service')
  if [ ${isInstalled} -eq 0 ]; then
    # dependencies
    sudo apt install -y virtualenv python-dev libusb-1.0-0-dev libudev-dev
    
    # create dedicated user
    sudo adduser --disabled-password --gecos "" ckbunker
    
    # add the user to the Tor group
    usermod -a -G debian-tor joinmarket

    # TODO echo "# persist settings in app-data"

    # open firewall to LAN (edit to the correct subnet 'from 192.168.3.0/24 to any port')
    sudo ufw allow 9823 comment "ckbunker"
    
    # add the udev rules
    cd /etc/udev/rules.d/
    sudo wget https://raw.githubusercontent.com/Coldcard/ckcc-protocol/master/51-coinkite.rules
    sudo udevadm control --reload-rules && sudo udevadm trigger
    
    # change to bitcoin user - required to access the Tor auth_cookie
    sudo su - bitcoin
    
    # install ckbunker
    sudo -u ckbunker git clone --recursive https://github.com/Coldcard/ckbunker.git
    cd ckbunker
    # reset to the tested release: https://github.com/Coldcard/ckbunker/releases
    sudo -u ckbunker git reset --hard $pinnedVersion
    sudo -u ckbunker  virtualenv -p python3 ENV
    source ENV/bin/activate
    sudo -u ckbunker pip install -r requirements.txt
    sudo -u ckbunker pip install --editable .
  fi
fi