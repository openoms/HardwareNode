#!/bin/bash

# command info
if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "-help" ]; then
 echo "config script to install, update or uninstall ThunderHub"
 echo "bonus.thunderhub.sh [on|off|menu|update]"
 exit 1
fi

# check and load raspiblitz config
# to know which network is running
source /home/admin/raspiblitz.info
source /mnt/hdd/raspiblitz.conf
if [ ${#network} -eq 0 ]; then
 echo "FAIL - missing /mnt/hdd/raspiblitz.conf"
 exit 1
fi

# show info menu
if [ "$1" = "menu" ]; then

  # get network info
  localip=$(ip addr | grep 'state UP' -A2 | tail -n1 | awk '{print $2}' | cut -f1 -d'/')
  toraddress=$(sudo cat /mnt/hdd/tor/thunderhub/hostname 2>/dev/null)

  if [ "${runBehindTor}" = "on" ] && [ ${#toraddress} -gt 0 ]; then
    # Info with TOR
    /home/admin/config.scripts/blitz.lcd.sh qr "${toraddress}"
    whiptail --title " ThunderHub " --msgbox "Open the following URL in your local web browser:
http://${localip}:3010
Use your Password B to login.\n
Hidden Service address for TOR Browser (QR see LCD):\n${toraddress}
" 12 67
    /home/admin/config.scripts/blitz.lcd.sh hide
  else
    # Info without TOR
    whiptail --title " ThunderHub " --msgbox "Open the following URL in your local web browser:
http://${localip}:3010
Use your Password B to login.\n
Activate TOR to access the web interface from outside your local network.
" 12 57
  fi
  echo "please wait ..."
  exit 0
fi

# add default value to raspi config if needed
if ! grep -Eq "^thunderhub=" /mnt/hdd/raspiblitz.conf; then
  echo "thunderhub=off" >> /mnt/hdd/raspiblitz.conf
fi

# stop services
echo "making sure services are not running"
sudo systemctl stop thunderhub 2>/dev/null

# switch on
if [ "$1" = "1" ] || [ "$1" = "on" ]; then
  echo "*** INSTALL THUNDERHUB ***"

  isInstalled=$(sudo ls /etc/systemd/system/thunderhub.service 2>/dev/null | grep -c 'thunderhub.service')
  if ! [ ${isInstalled} -eq 0 ]; then
    echo "ThunderHub already installed."
  else 
    ###############
    # INSTALL
    ###############

    # Preparations
    # check and install NodeJS
    /home/admin/config.scripts/bonus.nodejs.sh on

    # create thunderhub user
    sudo adduser --disabled-password --gecos "" thunderhub
    # move the home directory to the disk
    sudo usermod -m -d /mnt/hdd/app-storage/thunderhub thunderhub
    
    # download and install
    sudo -u thunderhub git clone https://github.com/apotdevin/thunderhub.git /mnt/hdd/app-storage/thunderhub/thunderhub
    cd /mnt/hdd/app-storage/thunderhub/thunderhub
    # https://github.com/apotdevin/thunderhub/releases
    sudo -u thunderhub git reset --hard v0.6.13
    echo "Running npm install and run build..."
    sudo -u thunderhub npm install
    sudo -u thunderhub npm run build

    ###############
    # CONFIG
    ###############

    # make sure symlink to central app-data directory exists ***"
    sudo rm -rf /mnt/hdd/app-storage/thunderhub/.lnd  # not a symlink.. delete it silently
    # create symlink
    sudo ln -s "/mnt/hdd/app-data/lnd/" "/mnt/hdd/app-storage/thunderhub/.lnd"

    # make sure thunderhub is member of lndadmin
    sudo /usr/sbin/usermod --append --groups lndadmin thunderhub

    #################
    # .env
    #################

    echo "*** create ThunderHub .env file ***"
    cat > /home/admin/thunderhub.env <<EOF
# -----------
# Server Configs
# -----------
LOG_LEVEL='debug'
# HODL_KEY='HODL_HODL_API_KEY'
# BASE_PATH='/basePath'

# -----------
# Interface Configs
# -----------
THEME='dark'
# CURRENCY='sat'
# FETCH_PRICES=false
# FETCH_FEES=false

# -----------
# Account Configs
# -----------
ACCOUNT_CONFIG_PATH='/mnt/hdd/app-storage/thunderhub/thubConfig.yaml'
EOF
    sudo rm -f /mnt/hdd/app-storage/thunderhub/thunderhub/.env
    sudo mv /home/admin/thunderhub.env /mnt/hdd/app-storage/thunderhub/thunderhub/.env
    sudo chown thunderhub:thunderhub /mnt/hdd/app-storage/thunderhub/thunderhub/.env

    ##################
    # thubConfig.yaml
    ##################

    echo "*** create thubConfig.yaml ***"
    # use Password_B
    PASSWORD_B=$(sudo cat /mnt/hdd/${network}/${network}.conf | grep rpcpassword | cut -c 13-)
    cat > /home/admin/thubConfig.yaml <<EOF
masterPassword: '$PASSWORD_B' # Default password unless defined in account
accounts:
  - name: '$hostname'
    serverUrl: '127.0.0.1:10009'
    macaroonPath: '/mnt/hdd/app-storage/thunderhub/.lnd/data/chain/bitcoin/mainnet/admin.macaroon'
    certificatePath: '/mnt/hdd/app-storage/thunderhub/.lnd/tls.cert'
EOF
    sudo rm -f /mnt/hdd/app-storage/thunderhub/thubConfig.yaml
    sudo mv /home/admin/thubConfig.yaml /mnt/hdd/app-storage/thunderhub/thubConfig.yaml
    sudo chown thunderhub:thunderhub /mnt/hdd/app-storage/thunderhub/thubConfig.yaml
    sudo chmod 600 /mnt/hdd/app-storage/thunderhub/thubConfig.yaml | exit 1

    ##################
    # SYSTEMD SERVICE
    ##################
    echo "*** Install ThunderHub systemd for ${network} on ${chain} ***"
    cat > /home/admin/thunderhub.service <<EOF
# Systemd unit for thunderhub
# /etc/systemd/system/thunderhub.service

[Unit]
Description=ThunderHub daemon
Wants=lnd.service
After=lnd.service

[Service]
WorkingDirectory=/mnt/hdd/app-storage/thunderhub/thunderhub
ExecStart=/usr/bin/npm run start -- -p 3010
User=thunderhub
Restart=always
TimeoutSec=120
RestartSec=30
StandardOutput=null
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
    sudo mv /home/admin/thunderhub.service /etc/systemd/system/thunderhub.service 
    sudo sed -i "s|chain/bitcoin/mainnet|chain/${network}/${chain}net|" /etc/systemd/system/thunderhub.service
    sudo chown root:root /etc/systemd/system/thunderhub.service
    sudo systemctl enable thunderhub
    echo "OK - the ThunderHub service is now enabled"

    # open the firewall
    sudo ufw allow from any to any port 3010 comment 'allow ThunderHub'

    # setting value in raspiblitz config
    sudo sed -i "s/^thunderhub=.*/thunderhub=on/g" /mnt/hdd/raspiblitz.conf

    # Hidden Service for thunderhub if Tor is active
    if [ "${runBehindTor}" = "on" ]; then
      /home/admin/config.scripts/internet.hiddenservice.sh thunderhub 80 3010
    fi
  fi
  exit 0
fi

# switch off
if [ "$1" = "0" ] || [ "$1" = "off" ]; then
  
  echo "*** REMOVING THUNDERHUB ***"
  # remove systemd service
  sudo systemctl disable thunderhub
  sudo rm -f /etc/systemd/system/thunderhub.service
  # delete user and home directory
  sudo userdel -rf thunderhub
  echo "OK ThunderHub removed."

  # setting value in raspi blitz config
  sudo sed -i "s/^thunderhub=.*/thunderhub=off/g" /mnt/hdd/raspiblitz.conf

  exit 0
fi

# update
if [ "$1" = "update" ]; then
  echo "*** UPDATING THUNDERHUB ***"
  cd /mnt/hdd/app-storage/thunderhub/thunderhub
  sudo -u thunderhub git pull
  sudo -u thunderhub npm install
  sudo -u thunderhub npm run build
  echo "*** Updated to the latest in https://github.com/apotdevin/thunderhub ***"
  echo ""
  echo "*** Starting the ThunderHub service ... *** "
  sudo systemctl start thunderhub
  exit 0
fi

echo "FAIL - Unknown Parameter $1"
exit 1
