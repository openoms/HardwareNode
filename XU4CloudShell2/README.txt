https://wiki.odroid.com/accessory/add-on_boards/xu4_cloudshell2/easy_install

https://de.eu.odroid.in/ubuntu_18.04lts/XU3_XU4_MC1_HC1_HC2/

ssh root@192.168.1.122
password: odroid

apt-get update
apt-get upgrade

# if E: Could not get lock /var/lib/dpkg/lock-frontend - open (11: Resource temporarily unavailable)
# E: Unable to acquire the dpkg frontend lock (/var/lib/dpkg/lock-frontend), is another process using it?
reboot

For BTRFS:
https://blog.programster.org/btrfs-cheatsheet
# wget https://github.com/openoms/raspiblitz/raw/xu4_cloudshell2/home.admin/30initBTRFS_HDD.sh && sudo chmod +x 30initBTRFS_HDD.sh && ./30initBTRFS_HDD.sh
./30initBtrfs_HDD.sh


wget https://raw.githubusercontent.com/openoms/raspiblitz/armbian1.2/build_sdcard.sh  && sudo bash build_sdcard.sh armbian1.2 openoms

#Cloudshell2: 
# Enabling/Configure the LCD
wget https://github.com/john1117/odroid-cloudshell/raw/master/odroid-cloudshell_20170420-4_armhf.deb
sudo dpkg -i odroid-cloudshell_20170420-4_armhf.deb
# Fan configuration
sudo apt install -y i2c-tools
wget https://github.com/john1117/cloudshell2-fan/raw/master/cloudshell2-fan_20170420-1_armhf.deb
sudo dpkg -i cloudshell2-fan_20170420-1_armhf.deb
# start fan
systemctl start cloudshell2-fan

sudo reboot

screen: https://github.com/rootzoll/raspiblitz/issues/341
sudo dpkg-reconfigure console-setup

# BTRFS already present:
sudo apt-get install -y btrfs-tools
sudo mkdir /mnt/hdd
sudo mount /dev/sda /mnt/hdd
sudo btrfs filesystem balance start -dconvert=raid1 -mconvert=raid1 /mnt/hdd
btrfs device stats /mnt/hdd

wget https://raw.githubusercontent.com/openoms/raspiblitz/armbian1.2/btrfs/btrfs_to_fstab.sh && chmod +x btrfs_to_fstab.sh && ./btrfs_to_fstab.sh 

wget https://raw.githubusercontent.com/openoms/raspiblitz/armbian1.2/build_sdcard.sh  && sudo bash build_sdcard.sh armbian1.2 openoms

btrfs device stats /mnt/hdd

TODO:
#change sda1 to sdb on 00mainmenu.sh:
#cp _bootstrapBtrfsHDD.sh _bootstrap.sh
#  sudo systemctl daemon-reload

# check if HDD is connected
hddExists=$(lsblk | grep -c sda1)
if [ ${hddExists} -eq 0 ]; then

change HHD1 sda1 to sdb in 50cloneHDD.sh
change HDD2 sda2/sdb to sdc1 in 50cloneHDD.sh

95finalSetup.sh creating swap fails on btrfs:
