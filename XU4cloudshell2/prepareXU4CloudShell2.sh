

apt-get update
apt-get upgrade -y

#Cloudshell2: 
echo ""
echo "Enabling the LCD (needs restart)"
wget https://github.com/john1117/odroid-cloudshell/raw/master/odroid-cloudshell_20170420-4_armhf.deb
sudo dpkg -i odroid-cloudshell_20170420-4_armhf.deb
echo "Fan configuration"
sudo apt install -y i2c-tools
wget https://github.com/john1117/cloudshell2-fan/raw/master/cloudshell2-fan_20170420-1_armhf.deb
sudo dpkg -i cloudshell2-fan_20170420-1_armhf.deb
echo "start fan"
systemctl start cloudshell2-fan

echo "Press key to reboot or CTRL+C to abort"
reboot