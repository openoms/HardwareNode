

sudo apt-get update
sudo apt-get upgrade -y

#Cloudshell2: 
echo ""
echo "Enabling the LCD (needs restart)"
wget https://github.com/john1117/odroid-cloudshell/raw/master/odroid-cloudshell_20170420-4_armhf.deb
sudo dpkg -i odroid-cloudshell_20170420-4_armhf.deb

# based on https://www.raspberrypi-spy.co.uk/20104/how-to-change-the-command-line-font-size/
sudo sed -i 's/FONTFACE="Fixed"/FONTFACE="Terminus"/' /etc/default/console-setup
sudo sed -i 's/FONTSIZE="8x16"/FONTSIZE="6x12"/' /etc/default/console-setup 

echo "Fan configuration"
sudo apt install -y i2c-tools
wget https://github.com/john1117/cloudshell2-fan/raw/master/cloudshell2-fan_20170420-1_armhf.deb
sudo dpkg -i cloudshell2-fan_20170420-1_armhf.deb
echo "start fan"
sudo systemctl start cloudshell2-fan


# BTRFS already present:
sudo apt-get install -y btrfs-tools
sudo mkdir /mnt/hdd
sudo mount /dev/sda /mnt/hdd
# sudo btrfs filesystem balance start -dconvert=raid1 -mconvert=raid1 /mnt/hdd
btrfs device stats /mnt/hdd

echo "Press a key to add BTRFS disk to fstab reboot or CTRL+C to abort"
read key
wget https://raw.githubusercontent.com/openoms/raspiblitz/XU4CloudShell2/XU4CloudShell2/btrfs_to_fstab.sh
sudo chmod +x btrfs_to_fstab.sh
./btrfs_to_fstab.sh

echo "Press a key to reboot or CTRL+C to abort"
read key
sudo reboot