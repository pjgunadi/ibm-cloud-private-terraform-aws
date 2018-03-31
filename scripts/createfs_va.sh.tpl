#!/bin/bash
#Check and install LVM Prerequisites
if ! pvdisplay; then
  if grep -q -i ubuntu /etc/*release; then
    apt-get -y install lvm2
  else
    yum install -y lvm2
  fi
fi

#Create Physical Volumes
pvcreate /dev/xvdf

#Create Volume Groups
vgcreate icp-vg /dev/xvdf

#Create Logical Volumes
lvcreate -L ${kubelet_lv}G -n kubelet-lv icp-vg
lvcreate -L ${docker_lv}G -n docker-lv icp-vg
lvcreate -L ${va_lv}G -n va-lv icp-vg

#Create Filesystems
mkfs.ext4 /dev/icp-vg/kubelet-lv
mkfs.ext4 /dev/icp-vg/docker-lv
mkfs.ext4 /dev/icp-vg/va-lv

#Create Directories
mkdir -p /var/lib/docker
mkdir -p /var/lib/kubelet
mkdir -p /var/lib/icp/va

#Add mount in /etc/fstab
cat <<EOL | tee -a /etc/fstab
/dev/mapper/icp--vg-kubelet--lv /var/lib/kubelet ext4 defaults 0 0
/dev/mapper/icp--vg-docker--lv /var/lib/docker ext4 defaults 0 0
/dev/mapper/icp--vg-va--lv /var/lib/icp/va ext4 defaults 0 0
EOL

#Mount Filesystems
mount -a
