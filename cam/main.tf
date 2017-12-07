
resource "aws_vpc" "icp_vpc" {
  cidr_block = "172.16.0.0/16"
}
resource "aws_internet_gateway" "icp_igw" {
  vpc_id = "${aws_vpc.icp_vpc.id}"
}
resource "aws_route" "internet_access" {
  route_table_id         = "${aws_vpc.icp_vpc.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.icp_igw.id}"
}
resource "aws_subnet" "icp_subnet" {
  vpc_id                  = "${aws_vpc.icp_vpc.id}"
  cidr_block              = "172.16.1.0/24"
  map_public_ip_on_launch = true
}
resource "aws_security_group" "common_secgrp" {
  name        = "common-secgrp"
  description = "Common Default Security Group"
  vpc_id      = "${aws_vpc.icp_vpc.id}"

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Calico from VPC
  ingress {
    from_port   = 179
    to_port     = 179
    protocol    = "tcp"
    cidr_blocks = ["${aws_vpc.icp_vpc.cidr_block}"]
  }
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["${aws_vpc.icp_vpc.cidr_block}"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "master_secgrp" {
  name        = "${var.master["name"]}-secgrp"
  description = "${var.master["name"]} Security Group"
  vpc_id      = "${aws_vpc.icp_vpc.id}"

  # ICP Portal
  ingress {
    from_port   = 8443
    to_port     = 8443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # Liberty
  ingress {
    from_port   = 9443
    to_port     = 9443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # Kubectl
  ingress {
    from_port   = 8001
    to_port     = 8001
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "proxy_secgrp" {
  name        = "${var.proxy["name"]}-secgrp"
  description = "${var.proxy["name"]} Security Group"
  vpc_id      = "${aws_vpc.icp_vpc.id}"

  # NodePorts
  ingress {
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # Ingress Service
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 8181
    to_port     = 8181
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 18080
    to_port     = 18080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_key_pair" "cam_public_key" {
  key_name   = "${var.key_pair_name}"
  public_key = "${var.public_key}"
}
resource "tls_private_key" "ssh" {
  algorithm = "RSA"
}
resource "aws_key_pair" "temp_public_key" {
  key_name = "key-temp"
  public_key = "${tls_private_key.ssh.public_key_openssh}"
}
resource "aws_instance" "master" {
  count = "${var.master["nodes"]}"
  instance_type = "${var.master["instance_type"]}"
  ami = "${var.image_id}"
  vpc_security_group_ids = ["${aws_security_group.common_secgrp.id}","${aws_security_group.master_secgrp.id}"]
  subnet_id = "${aws_subnet.icp_subnet.id}"
  key_name = "${aws_key_pair.temp_public_key.id}"
  associate_public_ip_address = true

  #Calico requirement for single VPC
  source_dest_check = "false"
  tags {
    Name = "${var.master["name"]}-${count.index}"
  }

  ebs_block_device {
    #/var/lib/docker 40GB /var/li/kubelet 10GB
    device_name = "/dev/sdf"
    volume_type = "gp2"
    volume_size = 50
  }
  ebs_block_device {
    #/var/lib/etcd 2GB /var/lib/registry 10GB /opt/ibm/cfc 0GB
    device_name = "/dev/sdg"
    volume_type = "gp2"
    volume_size = 12
  } 

  connection {
    user = "${var.ssh_user}"
    private_key = "${tls_private_key.ssh.private_key_pem}"
    host = "${self.public_ip}"
  }

  user_data = <<EOF
#!/bin/bash
#Create Physical Volumes
pvcreate /dev/xvdf 
pvcreate /dev/xvdg

#Create Volume Groups
vgcreate docker-vg /dev/xvdf
vgcreate data-vg /dev/xvdg

#Create Logical Volumes
lvcreate -L 10G -n kubelet-lv docker-vg
lvcreate -l 100%FREE -n docker-lv docker-vg
lvcreate -L 2G -n etcd-lv data-vg
lvcreate -l 100%FREE -n registry-lv data-vg
#lvcreate -l 100%FREE -n management-lv data-vg

#Create Filesystems
mkfs.ext4 /dev/docker-vg/kubelet-lv
mkfs.ext4 /dev/docker-vg/docker-lv
mkfs.ext4 /dev/data-vg/etcd-lv
mkfs.ext4 /dev/data-vg/registry-lv
#mkfs.ext4 /dev/data-vg/management-lv

#Create Directories
mkdir -p /var/lib/docker
mkdir -p /var/lib/kubelet
mkdir -p /var/lib/etcd
mkdir -p /var/lib/registry
#mkdir -p /opt/ibm/cfc

#Add mount in /etc/fstab
cat <<EOL | tee -a /etc/fstab
/dev/mapper/docker--vg-kubelet--lv /var/lib/kubelet ext4 defaults 0 0
/dev/mapper/docker--vg-docker--lv /var/lib/docker ext4 defaults 0 0
/dev/mapper/data--vg-etcd--lv /var/lib/etcd ext4 defaults 0 0
/dev/mapper/data--vg-registry--lv /var/lib/registry ext4 defaults 0 0
#/dev/mapper/data--vg-management--lv /opt/ibm/cfc ext4 defaults 0 0
EOL

#Mount Filesystems
mount -a
EOF

  provisioner "file" {
    content = <<EOF
#!/bin/bash
LOGFILE="/var/log/addkey.log"
user_public_key=$1
if [ "$user_public_key" != "None" ] ; then
    echo "---start adding user_public_key----" | tee -a $LOGFILE 2>&1
    echo "$user_public_key" | tee -a $HOME/.ssh/authorized_keys          >> $LOGFILE 2>&1 || { echo "---Failed to add user_public_key---" | tee -a $LOGFILE; exit 1; }
    echo "---finish adding user_public_key----" | tee -a $LOGFILE 2>&1
fi
EOF
    destination = "/tmp/addkey.sh"
  }

  provisioner "file" {
    content = "${count.index == 0 ? tls_private_key.ssh.private_key_pem : ""}"
    destination = "$HOME/.ssh/id_rsa"
  }

  # Add Public Key
  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/addkey.sh; sudo bash /tmp/addkey.sh \"${aws_key_pair.cam_public_key.public_key}\"",
      "chmod 600 $HOME/.ssh/id_rsa"
    ]
  }
}

resource "aws_instance" "proxy" {
  count = "${var.proxy["nodes"]}"
  instance_type = "${var.proxy["instance_type"]}"
  ami = "${var.image_id}"
  vpc_security_group_ids = ["${aws_security_group.common_secgrp.id}","${aws_security_group.proxy_secgrp.id}"]
  subnet_id = "${aws_subnet.icp_subnet.id}"
  key_name = "${aws_key_pair.temp_public_key.id}"
  associate_public_ip_address = true

  #Calico requirement for single VPC
  source_dest_check = "false"
  tags {
    Name = "${var.proxy["name"]}-${count.index}"
  }

  ebs_block_device {
    #/var/lib/docker 40GB /var/li/kubelet 10GB
    device_name = "/dev/sdf"
    volume_type = "gp2"
    volume_size = 50
  }

  connection {
    user = "${var.ssh_user}"
    private_key = "${tls_private_key.ssh.private_key_pem}"
    host = "${self.public_ip}"
  }

  user_data = <<EOF
#!/bin/bash
#Create Physical Volumes
pvcreate /dev/xvdf 

#Create Volume Groups
vgcreate docker-vg /dev/xvdf

#Create Logical Volumes
lvcreate -L 10G -n kubelet-lv docker-vg
lvcreate -l 100%FREE -n docker-lv docker-vg

#Create Filesystems
mkfs.ext4 /dev/docker-vg/kubelet-lv
mkfs.ext4 /dev/docker-vg/docker-lv

#Create Directories
mkdir -p /var/lib/docker
mkdir -p /var/lib/kubelet

#Add mount in /etc/fstab
cat <<EOL | tee -a /etc/fstab
/dev/mapper/docker--vg-kubelet--lv /var/lib/kubelet ext4 defaults 0 0
/dev/mapper/docker--vg-docker--lv /var/lib/docker ext4 defaults 0 0
EOL

#Mount Filesystems
mount -a
EOF

  provisioner "file" {
    content = <<EOF
#!/bin/bash
LOGFILE="/var/log/addkey.log"
user_public_key=$1
if [ "$user_public_key" != "None" ] ; then
    echo "---start adding user_public_key----" | tee -a $LOGFILE 2>&1
    echo "$user_public_key" | tee -a $HOME/.ssh/authorized_keys          >> $LOGFILE 2>&1 || { echo "---Failed to add user_public_key---" | tee -a $LOGFILE; exit 1; }
    echo "---finish adding user_public_key----" | tee -a $LOGFILE 2>&1
fi
EOF
    destination = "/tmp/addkey.sh"
  }

  # Add Public Key
  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/addkey.sh; sudo bash /tmp/addkey.sh \"${aws_key_pair.cam_public_key.public_key}\""
    ]
  }
}

resource "aws_instance" "management" {
  count = "${var.management["nodes"]}"
  instance_type = "${var.management["instance_type"]}"
  ami = "${var.image_id}"
  vpc_security_group_ids = ["${aws_security_group.common_secgrp.id}"]
  subnet_id = "${aws_subnet.icp_subnet.id}"
  key_name = "${aws_key_pair.temp_public_key.id}"
  associate_public_ip_address = true

  #Calico requirement for single VPC
  source_dest_check = "false"
  tags {
    Name = "${var.management["name"]}-${count.index}"
  }

  ebs_block_device {
    #/var/lib/docker 40GB /var/li/kubelet 10GB
    device_name = "/dev/sdf"
    volume_type = "gp2"
    volume_size = 50
  }
  ebs_block_device {
    #/var/lib/etcd 0GB /var/lib/registry 0GB /opt/ibm/cfc 10GB
    device_name = "/dev/sdg"
    volume_type = "gp2"
    volume_size = 10
  } 

  connection {
    user = "${var.ssh_user}"
    private_key = "${tls_private_key.ssh.private_key_pem}"
    host = "${self.public_ip}"
  }

  user_data = <<EOF
#!/bin/bash
#Create Physical Volumes
pvcreate /dev/xvdf 
pvcreate /dev/xvdg

#Create Volume Groups
vgcreate docker-vg /dev/xvdf
vgcreate data-vg /dev/xvdg

#Create Logical Volumes
lvcreate -L 10G -n kubelet-lv docker-vg
lvcreate -l 100%FREE -n docker-lv docker-vg
lvcreate -l 100%FREE -n management-lv data-vg

#Create Filesystems
mkfs.ext4 /dev/docker-vg/kubelet-lv
mkfs.ext4 /dev/docker-vg/docker-lv
mkfs.ext4 /dev/data-vg/management-lv

#Create Directories
mkdir -p /var/lib/docker
mkdir -p /var/lib/kubelet
mkdir -p /opt/ibm/cfc

#Add mount in /etc/fstab
cat <<EOL | tee -a /etc/fstab
/dev/mapper/docker--vg-kubelet--lv /var/lib/kubelet ext4 defaults 0 0
/dev/mapper/docker--vg-docker--lv /var/lib/docker ext4 defaults 0 0
/dev/mapper/data--vg-management--lv /opt/ibm/cfc ext4 defaults 0 0
EOL

#Mount Filesystems
mount -a
EOF

  provisioner "file" {
    content = <<EOF
#!/bin/bash
LOGFILE="/var/log/addkey.log"
user_public_key=$1
if [ "$user_public_key" != "None" ] ; then
    echo "---start adding user_public_key----" | tee -a $LOGFILE 2>&1
    echo "$user_public_key" | tee -a $HOME/.ssh/authorized_keys          >> $LOGFILE 2>&1 || { echo "---Failed to add user_public_key---" | tee -a $LOGFILE; exit 1; }
    echo "---finish adding user_public_key----" | tee -a $LOGFILE 2>&1
fi
EOF
    destination = "/tmp/addkey.sh"
  }

  # Add Public Key
  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/addkey.sh; sudo bash /tmp/addkey.sh \"${aws_key_pair.cam_public_key.public_key}\""
    ]
  }
}

resource "aws_instance" "worker" {
  count = "${var.worker["nodes"]}"
  instance_type = "${var.worker["instance_type"]}"
  ami = "${var.image_id}"
  vpc_security_group_ids = ["${aws_security_group.common_secgrp.id}"]
  subnet_id = "${aws_subnet.icp_subnet.id}"
  key_name = "${aws_key_pair.temp_public_key.id}"
  associate_public_ip_address = true

  #Calico requirement for single VPC
  source_dest_check = "false"
  tags {
    Name = "${var.worker["name"]}-${count.index}"
  }

  ebs_block_device {
    #/var/lib/docker 40GB /var/li/kubelet 10GB
    device_name = "/dev/sdf"
    volume_type = "gp2"
    volume_size = 50
  }

  connection {
    user = "${var.ssh_user}"
    private_key = "${tls_private_key.ssh.private_key_pem}"
    host = "${self.public_ip}"
  }

  user_data = <<EOF
#!/bin/bash
#Create Physical Volumes
pvcreate /dev/xvdf 

#Create Volume Groups
vgcreate docker-vg /dev/xvdf

#Create Logical Volumes
lvcreate -L 10G -n kubelet-lv docker-vg
lvcreate -l 100%FREE -n docker-lv docker-vg

#Create Filesystems
mkfs.ext4 /dev/docker-vg/kubelet-lv
mkfs.ext4 /dev/docker-vg/docker-lv

#Create Directories
mkdir -p /var/lib/docker
mkdir -p /var/lib/kubelet

#Add mount in /etc/fstab
cat <<EOL | tee -a /etc/fstab
/dev/mapper/docker--vg-kubelet--lv /var/lib/kubelet ext4 defaults 0 0
/dev/mapper/docker--vg-docker--lv /var/lib/docker ext4 defaults 0 0
EOL

#Mount Filesystems
mount -a
EOF

  provisioner "file" {
    content = <<EOF
#!/bin/bash
LOGFILE="/var/log/addkey.log"
user_public_key=$1
if [ "$user_public_key" != "None" ] ; then
    echo "---start adding user_public_key----" | tee -a $LOGFILE 2>&1
    echo "$user_public_key" | tee -a $HOME/.ssh/authorized_keys          >> $LOGFILE 2>&1 || { echo "---Failed to add user_public_key---" | tee -a $LOGFILE; exit 1; }
    echo "---finish adding user_public_key----" | tee -a $LOGFILE 2>&1
fi
EOF
    destination = "/tmp/addkey.sh"
  }

  # Add Public Key
  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/addkey.sh; sudo bash /tmp/addkey.sh \"${aws_key_pair.cam_public_key.public_key}\""
    ]
  }
}

module "icpprovision" {
  source = "github.com/pjgunadi/terraform-module-icp-deploy"
  //Connection IPs
  icp-ips = "${concat(aws_instance.master.*.public_ip, aws_instance.proxy.*.public_ip, aws_instance.management.*.public_ip, aws_instance.worker.*.public_ip)}"
  boot-node = "${element(aws_instance.master.*.public_ip, 0)}"

  //Configuration IPs
  icp-master = ["${aws_instance.master.*.private_ip}"]
  icp-worker = ["${aws_instance.worker.*.private_ip}"]
  icp-proxy = ["${aws_instance.proxy.*.private_ip}"]
  icp-management = ["${aws_instance.management.*.private_ip}"]

  enterprise-edition = false
  icp-version = "2.1.0"

  /* Workaround for terraform issue #10857
  When this is fixed, we can work this out autmatically */
  cluster_size  = "${var.master["nodes"] + var.worker["nodes"] + var.proxy["nodes"] + var.management["nodes"]}"

  icp_configuration = {
    "network_cidr"              = "10.1.0.0/16"
    "service_cluster_ip_range"  = "10.0.0.1/24"
    "ansible_user"              = "${var.ssh_user}"
    "ansible_become"            = "true"
    "default_admin_password"    = "${var.icpadmin_password}"
    "calico_ipip_enabled"       = "true"
    "cluster_access_ip"         = "${element(aws_instance.master.*.public_ip, 0)}"
  }

  generate_key = true
  #icp_pub_keyfile = "${tls_private_key.ssh.public_key_openssh}"
  #icp_priv_keyfile = "${tls_private_key.ssh.private_key_pem"}"
    
  ssh_user  = "${var.ssh_user}"
  ssh_key   = "${tls_private_key.ssh.private_key_pem}"
} 
