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
lvcreate -L ${management_lv}G -n management-lv icp-vg
lvcreate -L ${installer_lv}G -n installer-lv icp-vg

#Create Filesystems
mkfs.ext4 /dev/icp-vg/kubelet-lv
mkfs.ext4 /dev/icp-vg/docker-lv
mkfs.ext4 /dev/icp-vg/management-lv
mkfs.ext4 /dev/icp-vg/installer-lv

#Create Directories
mkdir -p /var/lib/docker
mkdir -p /var/lib/kubelet
mkdir -p /opt/ibm/cfc
mkdir -p /opt/ibm/cluster

#Add mount in /etc/fstab
cat <<EOL | tee -a /etc/fstab
/dev/mapper/icp--vg-kubelet--lv /var/lib/kubelet ext4 defaults 0 0
/dev/mapper/icp--vg-docker--lv /var/lib/docker ext4 defaults 0 0
/dev/mapper/icp--vg-management--lv /opt/ibm/cfc ext4 defaults 0 0
/dev/mapper/icp--vg-installer--lv /opt/ibm/cluster ext4 defaults 0 0
EOL

#Mount Filesystems
mount -a
