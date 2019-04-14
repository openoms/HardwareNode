## Ubuntu

https://de.eu.odroid.in/ubuntu_18.04lts/XU3_XU4_MC1_HC1_HC2

ssh root@192.168.1.122

password: odroid

apt-get update

apt-get upgrade

if:
>E: Could not get lock /var/lib/dpkg/lock-frontend - open (11: Resource temporarily unavailable)

>E: Unable to acquire the dpkg frontend lock (/var/lib/dpkg/lock-frontend), is another process using it?

reboot

## Armbian:

ssh root@192.168.1.122

password: 1234

follow instructions

## Prepare the XU4CloudShell2

wget https://raw.githubusercontent.com/openoms/raspiblitz/XU4CloudShell2/XU4CloudShell2/prepareXU4CloudShell2.sh && sudo chmod +x prepareXU4CloudShell2.sh && ./prepareXU4CloudShell2.sh

## Build the SDcard

wget https://raw.githubusercontent.com/openoms/raspiblitz/armbian1.2/build_sdcard.sh  && sudo bash build_sdcard.sh armbian1.2 openoms

## Configure the screen: 
https://github.com/rootzoll/raspiblitz/issues/341

sudo dpkg-reconfigure console-setup

based on https://www.raspberrypi-spy.co.uk/20104/how-to-change-the-command-line-font-size/
sudo sed -i 's/FONTFACE="Fixed"/FONTFACE="Terminus"/' /etc/default/console-setup
sudo sed -i 's/FONTSIZE="8x16"/FONTSIZE="6x12"/' /etc/default/console-setup 

scp ./XU4CloudShell2/00infoBlitz_3.2inch.sh admin@192.168.1.122:/home/admin/00infoBlitz.sh

---

TODO:


* change sda1 to sda on 00mainmenu.sh:
* cp _bootstrapBtrfsHDD.sh _bootstrap.sh and sudo systemctl daemon-reload

>check if HDD is connected
hddExists=$(lsblk | grep -c sda1)
if [ ${hddExists} -eq 0 ]; then

* change HHD1 sda1 to sdb in 50cloneHDD.sh
change HDD2 sda2/sdb to sdc1 in 50cloneHDD.sh

* 90finishSetup.sh creating swap fails on btrfs

---

Resources: 
https://wiki.odroid.com/accessory/add-on_boards/xu4_cloudshell2/easy_install