#!/bin/bash
existsHDD=$(lsblk | grep -c sda)
if [ ${existsHDD} -gt 0 ]; then
  echo "OK - HDD found as sda"
fi
mountOK=$(df | grep -c /mnt/hdd)
if [ ${mountOK} -eq 1 ]; then
  echo "HDD is already mounted"
  echo ""
  echo "*** Check HDD ***"
  formatBtrfsOK=$(lsblk -o UUID,NAME,FSTYPE,SIZE,LABEL,MODEL | grep BLOCKCHAIN | grep -c btrfs) 
  if [ ${formatBtrfsOK} -gt 0 ]; then
    echo "OK - HDD is formatted with btrfs and is named BLOCKCHAIN"
    uuid=$(lsblk -o UUID,NAME,FSTYPE,SIZE,LABEL,MODEL | grep BLOCKCHAIN)
    set -- $uuid
    uuid=$1
    fstabOK=$(cat /etc/fstab | grep -c ${uuid})
    if [ ${fstabOK} -eq 0 ]; then
      # see https://github.com/rootzoll/raspiblitz/issues/360#issuecomment-467567572
      # also https://www.cyberciti.biz/faq/linux-btrfs-fstab-entry-to-mount-filesystem-at-startup/
      fstabAdd="UUID=${uuid} /mnt/hdd btrfs defaults 0 2"
      echo "Adding line to /etc/fstab ..."
      echo ${fstabAdd}
      # adding the new line after line 3 to the /etc/fstab
      sudo sed "3 a ${fstabAdd}" -i /etc/fstab
    else
      echo "UUID is already in /etc/fstab"
    fi
  fi  
fi

fstabOK=$(cat /etc/fstab | grep -c ${uuid})
if [ ${fstabOK} -eq 1 ]; then
  echo "OK - HDD is listed in /etc/fstab"
else 
  echo "FAIL - HDD is not listed in /etc/fstab"
fi 