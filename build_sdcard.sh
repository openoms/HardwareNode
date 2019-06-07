#!/bin/bash
#########################################################################
# Build your SD card image based on:
# RASPBIAN STRETCH WITH DESKTOP (2019-04-09)
# https://www.raspberrypi.org/downloads/raspbian/
# SHA256: 7e10a446f8e57210d0e9ad02f0c833aabb86e58187b4dc02431aff5a3f1ccb83
# 
# or download the image for your ARM based SBC on https://DietPi.com
##########################################################################
# setup fresh SD card with image above - login per SSH and run this script: 
##########################################################################

echo ""
echo "*****************************************"
echo "* RASPIBLITZ SD CARD IMAGE SETUP v1.2   *"
echo "*****************************************"
echo ""

# 1st optional parameter is the BRANCH to get code from when
# provisioning sd card with raspiblitz assets/scripts later on
echo "*** CHECK INPUT PARAMETERS ***"
wantedBranch="$1"
if [ ${#wantedBranch} -eq 0 ]; then
  wantedBranch="master"
fi
echo "will use code from branch --> '${wantedBranch}'"

# 2nd optional parameter is the GITHUB-USERNAME to get code from when
# provisioning sd card with raspiblitz assets/scripts later on
# if 2nd parameter is used - 1st is mandatory
echo "*** CHECK INPUT PARAMETERS ***"
githubUser="$2"
if [ ${#githubUser} -eq 0 ]; then
  githubUser="rootzoll"
fi
echo "will use code from user --> '${githubUser}'"

sleep 3

echo ""
echo "*** CHECK BASE IMAGE ***"

# armv7=32Bit , armv8=64Bit
echo "Detect CPU architecture ..." 
isARM=$(uname -m | grep -c 'arm')
isAARCH64=$(uname -m | grep -c 'aarch64')
isX86_64=$(uname -m | grep -c 'x86_64')
isX86_32=$(uname -m | grep -c 'i386\|i486\|i586\|i686\|i786')
if [ ${isARM} -eq 0 ] && [ ${isAARCH64} -eq 0 ] && [ ${isX86_64} -eq 0 ] && [ ${isX86_32} -eq 0 ] ; then
  echo "!!! FAIL !!!"
  echo "Can only build on ARM, aarch64, x86_64 or i386 not on:"
  uname -m
  exit 1
else
 echo "OK running on $(uname -m) architecture."
fi

# keep in mind that DietPi for Raspberry is also a stripped down Raspbian
echo "Detect Base Image ..." 
baseImage="?"
isDietPi=$(uname -n | grep -c 'DietPi')
isRaspbian=$(cat /etc/os-release 2>/dev/null | grep -c 'Raspbian')
isArmbian=$(cat /etc/os-release 2>/dev/null | grep -c 'Debian')
isUbuntu=$(cat /etc/os-release 2>/dev/null | grep -c 'Ubuntu')
if [ ${isRaspbian} -gt 0 ]; then
  baseImage="raspbian"
fi
if [ ${isArmbian} -gt 0 ]; then
  baseImage="armbian"
fi 
if [ ${isUbuntu} -gt 0 ]; then
baseImage="ubuntu"
fi
if [ ${isDietPi} -gt 0 ]; then
  baseImage="dietpi"
fi
if [ "${baseImage}" = "?" ]; then
  cat /etc/os-release 2>/dev/null
  echo "!!! FAIL !!!"
  echo "Base Image cannot be detected or is not supported."
  exit 1
else
  echo "OK running ${baseImage}"
fi

# setting static DNS server
# see https://github.com/rootzoll/raspiblitz/issues/322#issuecomment-466733550
# check /etc/dhcpd.conf and /etc/dhcp/dhcpd.conf
if [ "${baseImage}" = "raspbian" ] || [ "${baseImage}" = "dietpi" ] ; then
  sudo sed -i "s/^#static domain_name_servers=192.168.0.1*/static domain_name_servers=1.1.1.1/g" /etc/dhcpcd.conf
  systemctl daemon-reload
fi
if [ "${baseImage}" = "ubuntu" ]; then
  sudo sed -i "s/^#static domain_name_servers=192.168.0.1*/static domain_name_servers=1.1.1.1/g" /etc/dhcp/dhcpd.conf
  systemctl daemon-reload
fi

if [ "${baseImage}" = "raspbian" ] || [ "${baseImage}" = "dietpi" ] ; then
  # fixing locales for build
  # https://github.com/rootzoll/raspiblitz/issues/138
  # https://daker.me/2014/10/how-to-fix-perl-warning-setting-locale-failed-in-raspbian.html
  # https://stackoverflow.com/questions/38188762/generate-all-locales-in-a-docker-image
  echo ""
  echo "*** FIXING LOCALES FOR BUILD ***"
  sudo sed -i "s/^# en_US.UTF-8 UTF-8.*/en_US.UTF-8 UTF-8/g" /etc/locale.gen
  sudo sed -i "s/^# en_US ISO-8859-1.*/en_US ISO-8859-1/g" /etc/locale.gen
  sudo locale-gen
  export LANGUAGE=en_GB.UTF-8
  export LANG=en_GB.UTF-8
  export LC_ALL=en_GB.UTF-8
fi

# update debian
echo ""
echo "*** UPDATE DEBIAN ***"
sudo apt-get update
sudo apt-get upgrade -f -y --allow-change-held-packages

echo ""
echo "*** PREPARE ${baseImage} ***"

# special prepare when AtomicPi (X86_64, Ubuntu)
isAtomicPi=$(cut -d: -f1 /etc/passwd | grep -c "atomicpi")
if [ ${isAtomicPi} -gt 0 ]; then
  echo "running on AtomicPi"
  sudo usermod -l pi atomicpi
fi

# special prepare when DietPi
if [ "${baseImage}" = "dietpi" ]; then
  echo "renaming dietpi user to pi"
  sudo usermod -l pi dietpi
fi

# special prepare when Raspbian
if [ "${baseImage}" = "raspbian" ]; then
  # do memory split (16MB)
  sudo raspi-config nonint do_memory_split 16
  # set to wait until network is available on boot (0 seems to yes)
  sudo raspi-config nonint do_boot_wait 0
  # set WIFI country so boot does not block
  sudo raspi-config nonint do_wifi_country US
  # see https://github.com/rootzoll/raspiblitz/issues/428#issuecomment-472822840
  echo "max_usb_current=1" | sudo tee -a /boot/config.txt
  # extra: remove some big packages not needed
  sudo apt-get remove -y --purge libreoffice* oracle-java* chromium-browser nuscratch scratch sonic-pi minecraft-pi python-pygame
  sudo apt-get clean
  sudo apt-get -y autoremove
fi

# special prepare when Ubuntu or Armbian
if [ "${baseImage}" = "ubuntu" ] || [ "${baseImage}" = "armbian" ]; then
  # make user pi and add to sudo 
  sudo adduser --disabled-password --gecos "" pi
  sudo adduser pi sudo
fi

echo ""
echo "*** CONFIG ***"
# based on https://github.com/Stadicus/guides/blob/master/raspibolt/raspibolt_20_pi.md#raspi-config

# set new default passwort for root user
echo "root:raspiblitz" | sudo chpasswd
echo "pi:raspiblitz" | sudo chpasswd

if [ "${baseImage}" = "raspbian" ]; then
  # set Raspi to boot up automatically with user pi (for the LCD)
  # https://www.raspberrypi.org/forums/viewtopic.php?t=21632
  sudo raspi-config nonint do_boot_behaviour B2
  sudo bash -c "echo '[Service]' >> /etc/systemd/system/getty@tty1.service.d/autologin.conf"
  sudo bash -c "echo 'ExecStart=' >> /etc/systemd/system/getty@tty1.service.d/autologin.conf"
  sudo bash -c "echo 'ExecStart=-/sbin/agetty --autologin pi --noclear %I 38400 linux' >> /etc/systemd/system/getty@tty1.service.d/autologin.conf"
fi

if [ "${baseImage}" = "dietpi" ]; then
  # set DietPi to boot up automatically with user pi (for the LCD)
  # requires AUTO_SETUP_AUTOSTART_TARGET_INDEX=7 in the dietpi.txt
  # /DietPi/dietpi/dietpi-autostart overwrites /etc/systemd/system/getty@tty1.service.d/dietpi-autologin.conf on reboot
  sudo sed -i 's/agetty --autologin root %I $TERM/agetty --autologin pi --noclear %I 38400 linux/' /DietPi/dietpi/dietpi-autostart
fi

if [ "${baseImage}" = "ubuntu" ] || [ "${baseImage}" = "armbian" ]; then
  sudo bash -c "echo '[Service]' >> /lib/systemd/system/getty@.service"
  sudo bash -c "echo 'ExecStart=' >> /lib/systemd/system/getty@.service"
  sudo bash -c "echo 'ExecStart=-/sbin/agetty --autologin pi --noclear %I 38400 linux' >> /lib/systemd/system/getty@.service"
fi

# change log rotates
# see https://github.com/rootzoll/raspiblitz/issues/394#issuecomment-471535483
echo "/var/log/syslog" >> ./rsyslog
echo "{" >> ./rsyslog
echo "	rotate 7" >> ./rsyslog
echo "	daily" >> ./rsyslog
echo "	missingok" >> ./rsyslog
echo "	notifempty" >> ./rsyslog
echo "	delaycompress" >> ./rsyslog
echo "	compress" >> ./rsyslog
echo "	postrotate" >> ./rsyslog
echo "		invoke-rc.d rsyslog rotate > /dev/null" >> ./rsyslog
echo "	endscript" >> ./rsyslog
echo "}" >> ./rsyslog
echo "" >> ./rsyslog
echo "/var/log/mail.info" >> ./rsyslog
echo "/var/log/mail.warn" >> ./rsyslog
echo "/var/log/mail.err" >> ./rsyslog
echo "/var/log/mail.log" >> ./rsyslog
echo "/var/log/daemon.log" >> ./rsyslog
echo "{" >> ./rsyslog
echo "        rotate 4" >> ./rsyslog
echo "        size=100M" >> ./rsyslog
echo "        missingok" >> ./rsyslog
echo "        notifempty" >> ./rsyslog
echo "        compress" >> ./rsyslog
echo "        delaycompress" >> ./rsyslog
echo "        sharedscripts" >> ./rsyslog
echo "        postrotate" >> ./rsyslog
echo "                invoke-rc.d rsyslog rotate > /dev/null" >> ./rsyslog
echo "        endscript" >> ./rsyslog
echo "}" >> ./rsyslog
echo "" >> ./rsyslog
echo "/var/log/kern.log" >> ./rsyslog
echo "/var/log/auth.log" >> ./rsyslog
echo "{" >> ./rsyslog
echo "        rotate 4" >> ./rsyslog
echo "        size=100M" >> ./rsyslog
echo "        missingok" >> ./rsyslog
echo "        notifempty" >> ./rsyslog
echo "        compress" >> ./rsyslog
echo "        delaycompress" >> ./rsyslog
echo "        sharedscripts" >> ./rsyslog
echo "        postrotate" >> ./rsyslog
echo "                invoke-rc.d rsyslog rotate > /dev/null" >> ./rsyslog
echo "        endscript" >> ./rsyslog
echo "}" >> ./rsyslog
echo "" >> ./rsyslog
echo "/var/log/user.log" >> ./rsyslog
echo "/var/log/lpr.log" >> ./rsyslog
echo "/var/log/cron.log" >> ./rsyslog
echo "/var/log/debug" >> ./rsyslog
echo "/var/log/messages" >> ./rsyslog
echo "{" >> ./rsyslog
echo "	rotate 4" >> ./rsyslog
echo "	weekly" >> ./rsyslog
echo "	missingok" >> ./rsyslog
echo "	notifempty" >> ./rsyslog
echo "	compress" >> ./rsyslog
echo "	delaycompress" >> ./rsyslog
echo "	sharedscripts" >> ./rsyslog
echo "	postrotate" >> ./rsyslog
echo "		invoke-rc.d rsyslog rotate > /dev/null" >> ./rsyslog
echo "	endscript" >> ./rsyslog
echo "}" >> ./rsyslog
sudo mv ./rsyslog /etc/logrotate.d/rsyslog
sudo chown root:root /etc/logrotate.d/rsyslog
sudo service rsyslog restart

echo ""
echo "*** SOFTWARE UPDATE ***"
# based on https://github.com/Stadicus/guides/blob/master/raspibolt/raspibolt_20_pi.md#software-update

# installs like on RaspiBolt
sudo apt-get install -y htop git curl bash-completion jq dphys-swapfile

# installs bandwidth monitoring for future statistics
sudo apt-get install -y vnstat

# prepare for BTRFS data drive raid
sudo apt-get install -y btrfs-tools

# prepare for ssh reverse tunneling
sudo apt-get install -y autossh

# prepare for display graphics mode
# see https://github.com/rootzoll/raspiblitz/pull/334
sudo apt-get install -y fbi

# prepare for powertest
sudo apt install -y sysbench

# prepare dor display service
# see https://github.com/rootzoll/raspiblitz/issues/88#issuecomment-471342311
sudo apt-get install -y redis-server
sudo -H pip3 install redis

# check for dependencies on DietPi, Ubuntu, Armbian
sudo apt-get install -y build-essential
sudo apt-get install -y python-pip
sudo apt-get install -y python-dev
# rsync is needed to copy from HDD
sudo apt install -y rsync
# install ifconfig
sudo apt install -y net-tools
#to display hex codes
sudo apt install -y xxd
# setuptools needed for Nyx
sudo pip install setuptools
# netcat for 00infoBlitz.sh
sudo apt install -y netcat
# install OpenSSH client + server
sudo apt install -y openssh-client
sudo apt install -y openssh-sftp-server
# install killall, fuser
sudo apt-get install -y psmisc

sudo apt-get clean
sudo apt-get -y autoremove

echo ""
echo "*** ADDING MAIN USER admin ***"
# based on https://github.com/Stadicus/guides/blob/master/raspibolt/raspibolt_20_pi.md#adding-main-user-admin
# using the default password 'raspiblitz'

sudo adduser --disabled-password --gecos "" admin
echo "admin:raspiblitz" | sudo chpasswd
sudo adduser admin sudo
sudo chsh admin -s /bin/bash

# configure sudo for usage without password entry
echo '%sudo ALL=(ALL) NOPASSWD:ALL' | sudo EDITOR='tee -a' visudo

echo ""
echo "*** ADDING SERVICE USER bitcoin"
# based on https://github.com/Stadicus/guides/blob/master/raspibolt/raspibolt_20_pi.md#adding-the-service-user-bitcoin

# create user and set default password for user
sudo adduser --disabled-password --gecos "" bitcoin
echo "bitcoin:raspiblitz" | sudo chpasswd

echo ""
echo "*** SWAP FILE ***"
# based on https://github.com/Stadicus/guides/blob/master/raspibolt/raspibolt_20_pi.md#moving-the-swap-file
# but just deactivating and deleting old (will be created alter when user adds HDD)

sudo dphys-swapfile swapoff
sudo dphys-swapfile uninstall

echo ""
echo "*** INCREASE OPEN FILE LIMIT ***"
# based on https://github.com/Stadicus/guides/blob/master/raspibolt/raspibolt_20_pi.md#increase-your-open-files-limit

sudo sed --in-place -i "56s/.*/*    soft nofile 128000/" /etc/security/limits.conf
sudo bash -c "echo '*    hard nofile 128000' >> /etc/security/limits.conf"
sudo bash -c "echo 'root soft nofile 128000' >> /etc/security/limits.conf"
sudo bash -c "echo 'root hard nofile 128000' >> /etc/security/limits.conf"
sudo bash -c "echo '# End of file' >> /etc/security/limits.conf"

sudo sed --in-place -i "23s/.*/session required pam_limits.so/" /etc/pam.d/common-session

sudo sed --in-place -i "25s/.*/session required pam_limits.so/" /etc/pam.d/common-session-noninteractive
sudo bash -c "echo '# end of pam-auth-update config' >> /etc/pam.d/common-session-noninteractive"

# "*** BITCOIN ***"
# based on https://github.com/Stadicus/guides/blob/master/raspibolt/raspibolt_30_bitcoin.md#installation

# set version (change if update is available)
# https://bitcoincore.org/en/download/
# bitcoinVersion="0.18.0" # commented out checksums for this version until lnd version >0.5.1
bitcoinVersion="0.17.1"

# set OS version and checksum
# needed to make sure download is not changed
# calculate with sha256sum and also check with SHA256SUMS.asc
# https://bitcoincore.org/bin/bitcoin-core-0.18.0/SHA256SUMS.asc
if [ ${isARM} -eq 1 ] ; then
  bitcoinOSversion="arm-linux-gnueabihf"
  # bitcoinSHA256="3d7eb57290b2f14c495a24ecbab8100b35861f0c81bc10d86e5c0a8ec8284b27"
  bitcoinSHA256="aab3c1fb92e47734fadded1d3f9ccf0ac5a59e3cdc28c43a52fcab9f0cb395bc"
fi
if [ ${isAARCH64} -eq 1 ] ; then
  bitcoinOSversion="aarch64-linux-gnu"
  # bitcoinSHA256="bfc3b8fddbb7ab9b532c9866859fc507ec959bdb82954966f54c8ebf8c7bb53b"
  bitcoinSHA256="5659c436ca92eed8ef42d5b2d162ff6283feba220748f9a373a5a53968975e34"
fi
if [ ${isX86_64} -eq 1 ] ; then
  bitcoinOSversion="x86_64-linux-gnu"
  # bitcoinSHA256="5146ac5310133fbb01439666131588006543ab5364435b748ddfc95a8cb8d63f"
  bitcoinSHA256="53ffca45809127c9ba33ce0080558634101ec49de5224b2998c489b6d0fc2b17"
fi
if [ ${isX86_32} -eq 1 ] ; then
  bitcoinOSversion="i686-pc-linux-gnu"
  # bitcoinSHA256="36ce9ffb375f6ee280df5a86e61038e3c475ab9dee34f6f89ea82b65a264183b"
  bitcoinSHA256="b1e1dcf8265521fef9021a9d49d8661833e3f844ca9a410a9dd12a617553dda1"
fi

echo ""
echo "*** BITCOIN v${bitcoinVersion} for ${bitcoinOSversion} ***"

# needed to check code signing
laanwjPGP="01EA5486DE18A882D4C2684590C8019E36C2E964"

# prepare directories
sudo rm -r /home/admin/download
sudo -u admin mkdir /home/admin/download
cd /home/admin/download

# download resources
binaryName="bitcoin-${bitcoinVersion}-${bitcoinOSversion}.tar.gz"
sudo -u admin wget https://bitcoin.org/bin/bitcoin-core-${bitcoinVersion}/${binaryName}
if [ ! -f "./${binaryName}" ]
then
    echo "!!! FAIL !!! Download BITCOIN BINARY not success."
    exit 1
fi

# check binary is was not manipulated (checksum test)
binaryChecksum=$(sha256sum ${binaryName} | cut -d " " -f1)
if [ "${binaryChecksum}" != "${bitcoinSHA256}" ]; then
  echo "!!! FAIL !!! Downloaded BITCOIN BINARY not matching SHA256 checksum: ${bitcoinSHA256}"
  exit 1
fi

# check gpg finger print
sudo -u admin wget https://bitcoin.org/laanwj-releases.asc
if [ ! -f "./laanwj-releases.asc" ]
then
  echo "!!! FAIL !!! Download laanwj-releases.asc not success."
  exit 1
fi
gpg ./laanwj-releases.asc
fingerprint=$(gpg ./laanwj-releases.asc 2>/dev/null | grep "${laanwjPGP}" -c)
if [ ${fingerprint} -lt 1 ]; then
  echo ""
  echo "!!! BUILD WARNING --> Bitcoin PGP author not as expected"
  echo "Should contain laanwjPGP: ${laanwjPGP}"
  echo "PRESS ENTER to TAKE THE RISK if you think all is OK"
  read key
fi
gpg --import ./laanwj-releases.asc
sudo -u admin wget https://bitcoin.org/bin/bitcoin-core-${bitcoinVersion}/SHA256SUMS.asc
verifyResult=$(gpg --verify SHA256SUMS.asc 2>&1)
goodSignature=$(echo ${verifyResult} | grep 'Good signature' -c)
echo "goodSignature(${goodSignature})"
correctKey=$(echo ${verifyResult} |  grep "using RSA key ${laanwjPGP: -16}" -c)
echo "correctKey(${correctKey})"
if [ ${correctKey} -lt 1 ] || [ ${goodSignature} -lt 1 ]; then
  echo ""
  echo "!!! BUILD FAILED --> LND PGP Verify not OK / signatute(${goodSignature}) verify(${correctKey})"
  exit 1
fi

# correct versions for install if needed
# just if an small update shows a different formatted version number
if [ "${bitcoinVersion}" = "0.17.0.1" ]; then 
 bitcoinVersion="0.17.0"
fi

# install
sudo -u admin tar -xvf ${binaryName}
sudo install -m 0755 -o root -g root -t /usr/local/bin/ bitcoin-${bitcoinVersion}/bin/*
sleep 3
installed=$(sudo -u admin bitcoind --version | grep "${bitcoinVersion}" -c)
if [ ${installed} -lt 1 ]; then
  echo ""
  echo "!!! BUILD FAILED --> Was not able to install bitcoind version(${bitcoinVersion})"
  exit 1
fi

if [ "${baseImage}" = "raspbian" ]; then
  echo ""
  echo "*** LITECOIN ***"
  # based on https://medium.com/@jason.hcwong/litecoin-lightning-with-raspberry-pi-3-c3b931a82347

  # set version (change if update is available)
  litecoinVersion="0.16.3"
  litecoinSHA256="fc6897265594985c1d09978b377d51a01cc13ee144820ddc59fbb7078f122f99"
  cd /home/admin/download

  # download
  binaryName="litecoin-${litecoinVersion}-arm-linux-gnueabihf.tar.gz"
  sudo -u admin wget https://download.litecoin.org/litecoin-${litecoinVersion}/linux/${binaryName}

  # check download
  binaryChecksum=$(sha256sum ${binaryName} | cut -d " " -f1)
  if [ "${binaryChecksum}" != "${litecoinSHA256}" ]; then
    echo "!!! FAIL !!! Downloaded LITECOIN BINARY not matching SHA256 checksum: ${litecoinSHA256}"
    exit 1
  fi

  # install
  sudo -u admin tar -xvf ${binaryName}
  sudo install -m 0755 -o root -g root -t /usr/local/bin litecoin-${litecoinVersion}/bin/*
  installed=$(sudo -u admin litecoind --version | grep "${litecoinVersion}" -c)
  if [ ${installed} -lt 1 ]; then
    echo ""
    echo "!!! BUILD FAILED --> Was not able to install litecoind version(${litecoinVersion})"
    exit 1
  fi
fi

# "*** LND ***"
## based on https://github.com/Stadicus/guides/blob/master/raspibolt/raspibolt_40_lnd.md#lightning-lnd
## see LND releases: https://github.com/lightningnetwork/lnd/releases
lndVersion="0.6.1-beta"

if [ ${isARM} -eq 1 ] ; then
  lndOSversion="armv7"
  lndSHA256="5541959c7fde98d76d88cc8070ca626c681ba38c44afcb85bf417a9a677e23c2"
fi
if [ ${isAARCH64} -eq 1 ] ; then
  lndOSversion="arm64"
  lndSHA256="d5f7280c324ebc1d322435a0eac4c42dca73ebc6a613878d9e0d33a68276da5c"
fi
if [ ${isX86_64} -eq 1 ] ; then
  lndOSversion="amd64"
  lndSHA256="c55367edb82955dc942baf9f48f79fadde1eee0e86c1d59d2fe1993140ec1b3f"
fi 
if [ ${isX86_32} -eq 1 ] ; then
  lndOSversion="386"
  lndSHA256="00a7cd0ca657bb242b0f3acb5f4e26a13fd789946fab73c252118e3f89c1cf57"
fi 

echo ""
echo "*** LND v${lndVersion} for ${lndOSversion} ***"

# olaoluwa
PGPpkeys="https://keybase.io/roasbeef/pgp_keys.asc"
PGPcheck="BD599672C804AF2770869A048B80CD2BB8BD8132"
# bitconner 
#PGPpkeys="https://keybase.io/bitconner/pgp_keys.asc"
#PGPcheck="9C8D61868A7C492003B2744EE7D737B67FA592C7"

# get LND resources
cd /home/admin/download
binaryName="lnd-linux-${lndOSversion}-v${lndVersion}.tar.gz"
sudo -u admin wget https://github.com/lightningnetwork/lnd/releases/download/v${lndVersion}/${binaryName}
sudo -u admin wget https://github.com/lightningnetwork/lnd/releases/download/v${lndVersion}/manifest-v${lndVersion}.txt
sudo -u admin wget https://github.com/lightningnetwork/lnd/releases/download/v${lndVersion}/manifest-v${lndVersion}.txt.sig
sudo -u admin wget -O /home/admin/download/pgp_keys.asc ${PGPpkeys}

# check binary is was not manipulated (checksum test)
binaryChecksum=$(sha256sum ${binaryName} | cut -d " " -f1)
if [ "${binaryChecksum}" != "${lndSHA256}" ]; then
  echo "!!! FAIL !!! Downloaded LND BINARY not matching SHA256 checksum: ${lndSHA256}"
  exit 1
fi

# check gpg finger print
gpg ./pgp_keys.asc
fingerprint=$(sudo gpg /home/admin/download/pgp_keys.asc 2>/dev/null | grep "${PGPcheck}" -c)
if [ ${fingerprint} -lt 1 ]; then
  echo ""
  echo "!!! BUILD WARNING --> LND PGP author not as expected"
  echo "Should contain PGP: ${PGPcheck}"
  echo "PRESS ENTER to TAKE THE RISK if you think all is OK"
  read key
fi
gpg --import ./pgp_keys.asc
sleep 3
verifyResult=$(gpg --verify manifest-v${lndVersion}.txt.sig 2>&1)
goodSignature=$(echo ${verifyResult} | grep 'Good signature' -c)
echo "goodSignature(${goodSignature})"
correctKey=$(echo ${verifyResult} | tr -d " \t\n\r" | grep "${olaoluwaPGP}" -c)
echo "correctKey(${correctKey})"
if [ ${correctKey} -lt 1 ] || [ ${goodSignature} -lt 1 ]; then
  echo ""
  echo "!!! BUILD FAILED --> LND PGP Verify not OK / signatute(${goodSignature}) verify(${correctKey})"
  exit 1
fi

# install
sudo -u admin tar -xzf ${binaryName}
sudo install -m 0755 -o root -g root -t /usr/local/bin lnd-linux-${lndOSversion}-v${lndVersion}/*
sleep 3
installed=$(sudo -u admin lnd --version)
if [ ${#installed} -eq 0 ]; then
  echo ""
  echo "!!! BUILD FAILED --> Was not able to install LND"
  exit 1
fi

# prepare python for lnd api use
# https://dev.lightning.community/guides/python-grpc/
# 
echo ""
echo "*** LND API for Python ***"
sudo update-alternatives --install /usr/bin/python python /usr/bin/python2.7 3
sudo update-alternatives --install /usr/bin/python python /usr/bin/python3.5 2
sudo update-alternatives --install /usr/bin/python python /usr/bin/python3.6 1
echo "to switch between python2/3: sudo update-alternatives --config python"
sudo apt-get -f -y install virtualenv
sudo chown -R admin /home/admin
sudo -u admin bash -c "cd; virtualenv python-env-lnd; source /home/admin/python-env-lnd/bin/activate; pip install grpcio grpcio-tools googleapis-common-protos pathlib2"
echo ""

# "*** Installing Go ***"
# Go is needed for ZAP connect later
# see https://golang.org/dl/
goVersion="1.12.5"
if [ ${isARM} -eq 1 ] ; then
  goOSversion="armv6l"
fi
if [ ${isAARCH64} -eq 1 ] ; then
  goOSversion="arm64"
fi
if [ ${isX86_64} -eq 1 ] ; then
  goOSversion="amd64"
fi 
if [ ${isX86_32} -eq 1 ] ; then
  goOSversion="386"
fi 

echo "*** Installing Go v${goVersion} for ${goOSversion} ***"

# wget https://storage.googleapis.com/golang/go${goVersion}.linux-${goOSversion}.tar.gz
wget https://dl.google.com/go/go${goVersion}.linux-${goOSversion}.tar.gz
if [ ! -f "./go${goVersion}.linux-${goOSversion}.tar.gz" ]
then
    echo "!!! FAIL !!! Download not success."
    exit 1
fi
sudo tar -C /usr/local -xzf go${goVersion}.linux-${goOSversion}.tar.gz
sudo rm *.gz
sudo mkdir /usr/local/gocode
sudo chmod 777 /usr/local/gocode
export GOROOT=/usr/local/go
export PATH=$PATH:$GOROOT/bin
export GOPATH=/usr/local/gocode
export PATH=$PATH:$GOPATH/bin
echo ""

##### Build from Source
## To quickly catch up get latest patches if needed
#repo="github.com/lightningnetwork/lnd"
#commit="3f57f65bf0cb710159b0182391d1d75e9e3005bc"
## BUILDING LND FROM SOURCE
#echo "*** Installing Go ***"
#wget https://storage.googleapis.com/golang/go1.11.linux-armv6l.tar.gz
#if [ ! -f "./go1.11.linux-armv6l.tar.gz" ]
#then
#    echo "!!! FAIL !!! Download not success."
#    exit 1
#fi
#sudo tar -C /usr/local -xzf go1.11.linux-armv6l.tar.gz
#sudo rm *.gz
#sudo mkdir /usr/local/gocode
#sudo chmod 777 /usr/local/gocode
#export GOROOT=/usr/local/go
#export PATH=$PATH:$GOROOT/bin
#export GOPATH=/usr/local/gocode
#export PATH=$PATH:$GOPATH/bin
#echo ""
#echo "*** Build LND from Source ***"
#go get -d $repo
## make sure to always have the same code (commit) to build
## TODO: To update lnd -> change to latest commit
#cd $GOPATH/src/$repo
#sudo git checkout $commit
#make && make install
#sudo chmod 555 /usr/local/gocode/bin/lncli
#sudo chmod 555 /usr/local/gocode/bin/lnd
#sudo bash -c "echo 'export PATH=$PATH:/usr/local/gocode/bin/' >> /home/admin/.bashrc"
#sudo bash -c "echo 'export PATH=$PATH:/usr/local/gocode/bin/' >> /home/pi/.bashrc"
#sudo bash -c "echo 'export PATH=$PATH:/usr/local/gocode/bin/' >> /home/bitcoin/.bashrc"
#lndVersionCheck=$(lncli --version)
#echo "LND VERSION: ${lndVersionCheck}"
#if [ ${#lndVersionCheck} -eq 0 ]; then
#  echo "FAIL - Something went wrong with building LND from source."
#  echo "Sometimes it may just be a connection issue. Reset to fresh Rasbian and try again?"
#  exit 1
#fi
#echo ""
#echo "** Link to /usr/local/bin ***"
#sudo ln -s /usr/local/gocode/bin/lncli /usr/local/bin/lncli
#sudo ln -s /usr/local/gocode/bin/lnd /usr/local/bin/lnd

echo ""
echo "*** RASPIBLITZ EXTRAS ***"

# for setup schell scripts
sudo apt-get -y install dialog bc

# enable copy of blockchain from 2nd HDD formatted with exFAT
sudo apt-get -y install exfat-fuse

# for blockchain torrent download
sudo apt-get -y install transmission-cli
sudo apt-get -y install rtorrent
sudo apt-get -y install cpulimit

# for background downloading
sudo apt-get -y install screen

# optimization for torrent download
sudo bash -c "echo 'net.core.rmem_max = 4194304' >> /etc/sysctl.conf"
sudo bash -c "echo 'net.core.wmem_max = 1048576' >> /etc/sysctl.conf"

# *** SHELL SCRIPTS AND ASSETS

# move files from gitclone
cd /home/admin/
sudo -u admin git clone -b ${wantedBranch} https://github.com/${githubUser}/raspiblitz.git
sudo -u admin cp /home/admin/raspiblitz/home.admin/*.* /home/admin
sudo -u admin chmod +x *.sh
sudo -u admin cp -r /home/admin/raspiblitz/home.admin/assets /home/admin/
sudo -u admin cp -r /home/admin/raspiblitz/home.admin/config.scripts /home/admin/
sudo -u admin chmod +x /home/admin/config.scripts/*.sh

# add /sbin to path for all
sudo bash -c "echo 'PATH=\$PATH:/sbin' >> /etc/profile"

# profile path for admin
sudo bash -c "echo '' >> /home/admin/.profile"
sudo bash -c "echo 'GOROOT=/usr/local/go' >> /home/admin/.profile"
sudo bash -c "echo 'PATH=\$PATH:\$GOROOT/bin' >> /home/admin/.profile"
sudo bash -c "echo 'GOPATH=/usr/local/gocode' >> /home/admin/.profile"
sudo bash -c "echo 'PATH=\$PATH:\$GOPATH/bin' >> /home/admin/.profile"

# bash autostart for admin
sudo bash -c "echo '# shortcut commands' >> /home/admin/.bashrc"
sudo bash -c "echo 'source /home/admin/_commands.sh' >> /home/admin/.bashrc"
sudo bash -c "echo '# automatically start main menu for admin' >> /home/admin/.bashrc"
sudo bash -c "echo './00raspiblitz.sh' >> /home/admin/.bashrc"

if [ "${baseImage}" = "raspbian" ] || [ "${baseImage}" = "armbian" ] || [ "${baseImage}" = "ubuntu" ]; then
  # bash autostart for pi
  # run as exec to dont allow easy physical access by keyboard
  # see https://github.com/rootzoll/raspiblitz/issues/54
  sudo bash -c 'echo "# automatic start the LCD info loop" >> /home/pi/.bashrc'
  sudo bash -c 'echo "SCRIPT=/home/admin/00infoLCD.sh" >> /home/pi/.bashrc'
  sudo bash -c 'echo "# replace shell with script => logout when exiting script" >> /home/pi/.bashrc'
  sudo bash -c 'echo "exec \$SCRIPT" >> /home/pi/.bashrc'
fi
if [ "${baseImage}" = "raspbian" ]; then
  # create /home/admin/setup.sh - which will get executed after reboot by autologin pi user
  cat > /home/admin/setup.sh <<EOF

  # make LCD screen rotation correct
  sudo sed --in-place -i "57s/.*/dtoverlay=tft35a:rotate=270/" /boot/config.txt

EOF
  sudo chmod +x /home/admin/setup.sh
fi

if [ "${baseImage}" = "dietpi" ]; then
  # bash autostart for dietpi
  sudo bash -c 'echo "# automatic start the LCD info loop" >> /home/dietpi/.bashrc'
  sudo bash -c 'echo "SCRIPT=/home/admin/00infoLCD.sh" >> /home/dietpi/.bashrc'
  sudo bash -c 'echo "# replace shell with script => logout when exiting script" >> /home/dietpi/.bashrc'
  sudo bash -c 'echo "exec \$SCRIPT" >> /home/dietpi/.bashrc'
fi

echo ""
echo "*** HARDENING ***"
# based on https://github.com/Stadicus/guides/blob/master/raspibolt/raspibolt_20_pi.md#hardening-your-pi

# fail2ban (no config required)
sudo apt-get install -y fail2ban

# *** BOOTSTRAP ***
# see background README for details
echo ""
echo "*** RASPI BOOSTRAP SERVICE ***"
sudo chmod +x /home/admin/_bootstrap.sh
sudo cp ./assets/bootstrap.service /etc/systemd/system/bootstrap.service
sudo systemctl enable bootstrap

# *** BACKGROUND ***
echo ""
echo "*** RASPI BACKGROUND SERVICE ***"
sudo chmod +x /home/admin/_background.sh
sudo cp ./assets/background.service /etc/systemd/system/background.service
sudo systemctl enable background

# *** TOR Prepare ***
echo "*** Prepare TOR source+keys ***"
sudo /home/admin/config.scripts/internet.tor.sh prepare
echo ""
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
echo "If you see fails above .. please run again later on:"
echo "sudo /home/admin/config.scripts/internet.tor.sh prepare"
echo ""

# *** RASPIBLITZ IMAGE READY ***
echo ""
echo "**********************************************"
echo "ALMOST READY"
echo "**********************************************"
echo ""
echo "Your SD Card Image for RaspiBlitz is almost ready."
echo "Last step is to install LCD drivers. This will reboot your Pi when done."
echo ""
echo "Maybe take the chance and look thru the output above if you can spot any errror."
echo ""
echo "After final reboot - your SD Card Image is ready."
echo ""
echo "IMPORTANT IF WANT TO MAKE A RELEASE IMAGE FROM THIS BUILD:"
echo "login once after reboot without HDD and run 'XXprepareRelease.sh'"
echo ""
echo "to continue: reboot with \`sudo shutdown -r now\` and login with user:admin password:raspiblitz"
echo ""

# install default LCD on DietPi without reboot to allow automatic build
if [ "${baseImage}" = "dietpi" ]; then
  echo "Installing the default display available from Amazon" 
  # based on https://www.elegoo.com/tutorial/Elegoo%203.5%20inch%20Touch%20Screen%20User%20Manual%20V1.00.2017.10.09.zip
  cd /home/admin/
  # sudo apt-mark hold raspberrypi-bootloader
  git clone https://github.com/goodtft/LCD-show.git
  sudo chmod -R 755 LCD-show
  sudo chown -R admin:admin LCD-show
  cd LCD-show/
  # sudo ./LCD35-show
  sudo rm -rf /etc/X11/xorg.conf.d/40-libinput.conf
  sudo mkdir /etc/X11/xorg.conf.d
  sudo cp ./usr/tft35a-overlay.dtb /boot/overlays/
  sudo cp ./usr/tft35a-overlay.dtb /boot/overlays/tft35a.dtbo
  sudo cp -rf ./usr/99-calibration.conf-35  /etc/X11/xorg.conf.d/99-calibration.conf
  sudo cp -rf ./usr/99-fbturbo.conf  /usr/share/X11/xorg.conf.d/
  sudo cp ./usr/cmdline.txt /DietPi/
  sudo cp ./usr/inittab /etc/
  sudo cp ./boot/config-35.txt /DietPi/config.txt
  # make LCD screen rotation correct
  sudo sed -i "s/dtoverlay=tft35a/dtoverlay=tft35a:rotate=270/" /DietPi/config.txt
  echo "to continue reboot with \`sudo shutdown -r now \` and login with admin"
fi

# ask about LCD only on Raspbian
if [ "${baseImage}" = "raspbian" ]; then
  echo "Press ENTER to install LCD and reboot ..."
  read key

  # give Raspi a default hostname (optional)
  sudo raspi-config nonint do_hostname "RaspiBlitz"

  # *** Display selection ***
  dialog --title "Display" --yesno "Are you using the default display available from Amazon?\nSelect 'No' if you are using the Swiss version from play-zone.ch!" 6 80
  defaultDisplay=$?

  if [ "${defaultDisplay}" = "0" ]; then

    # *** RASPIBLITZ / LCD (at last - because makes a reboot) ***
    # based on https://www.elegoo.com/tutorial/Elegoo%203.5%20inch%20Touch%20Screen%20User%20Manual%20V1.00.2017.10.09.zip
    
    echo "--> LCD DEFAULT"
    cd /home/admin/
    sudo apt-mark hold raspberrypi-bootloader
    git clone https://github.com/goodtft/LCD-show.git
    sudo chmod -R 755 LCD-show
    sudo chown -R admin:admin LCD-show
    cd LCD-show/
    sudo ./LCD35-show

  else

    # Download and install the driver
    # based on http://www.raspberrypiwiki.com/index.php/3.5_inch_TFT_800x480@60fps

    echo "--> LCD ALTERNATIVE"
    cd /boot
    sudo wget http://www.raspberrypiwiki.com/download/RPI-HD-35-INCH-TFT/dt-blob-For-3B-plus.bin
    sudo mv dt-blob-For-3B-plus.bin dt-blob.bin
    cat <<EOF >> config.txt

  dtparam=spi=off
  dtparam=i2c_arm=off

  # Set screen size and any overscan required
  overscan_left=0
  overscan_right=0
  overscan_top=0
  overscan_bottom=0
  framebuffer_width=800
  framebuffer_height=480


  enable_dpi_lcd=1
  display_default_lcd=1
  dpi_group=2
  dpi_mode=87
  dpi_output_format=0x6f015

  # set up the size to 800x480
  hdmi_timings=480 0 16 16 24 800 0 4 2 2 0 0 0 60 0 32000000 6

  #rotate screen
  display_rotate=3

  dtoverlay=i2c-gpio,i2c_gpio_scl=24,i2c_gpio_sda=23
  fi
EOF
    init 6
  fi
fi
