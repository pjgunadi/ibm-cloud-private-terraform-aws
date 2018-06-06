provider "aws" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region     = "${var.region}"
}

resource "tls_private_key" "ssh" {
  algorithm = "RSA"

  provisioner "local-exec" {
    command = "cat > ${var.key_pair_name} <<EOL\n${tls_private_key.ssh.private_key_pem}\nEOL"
  }

  provisioner "local-exec" {
    command = "chmod 600 ${var.key_pair_name}"
  }
}

resource "aws_key_pair" "aws_public_key" {
  key_name   = "${var.key_pair_name}"
  public_key = "${tls_private_key.ssh.public_key_openssh}"
}

resource "aws_vpc" "icp_vpc" {
  cidr_block = "${var.aws_vpc_cidr}"
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
  cidr_block              = "${var.aws_subnet}"
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

  # Allow internet subnet and Kubernetes Network CIDR
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["${aws_vpc.icp_vpc.cidr_block}", "${var.network_cidr}"]
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

  # Registry
  ingress {
    from_port   = 8500
    to_port     = 8500
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Monitoring
  ingress {
    from_port   = 4300
    to_port     = 4300
    protocol    = "tcp"
    cidr_blocks = ["${element(split(",",var.management["nodes"] == 0 ? var.network_cidr : join(",",formatlist("%s/32",aws_instance.management.*.public_ip))),0)}"]
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
}

#Test ELB
resource "aws_security_group" "elb_secgrp" {
  name        = "icp-elb-secgrp"
  description = "ICP ELB Security Group"
  vpc_id      = "${aws_vpc.icp_vpc.id}"

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#Test ELB
resource "aws_elb" "master_elb" {
  name = "master-elb"

  subnets         = ["${aws_subnet.icp_subnet.id}"]
  security_groups = ["${aws_security_group.elb_secgrp.id}"]
  instances       = ["${aws_instance.master.id}"]

  listener {
    instance_port     = 8080
    instance_protocol = "http"
    lb_port           = 8080
    lb_protocol       = "http"
  }
}

data "template_file" "createfs_master" {
  template = "${file("${path.module}/scripts/createfs_master.sh.tpl")}"

  vars {
    kubelet_lv    = "${var.master["kubelet_lv"]}"
    docker_lv     = "${var.master["docker_lv"]}"
    etcd_lv       = "${var.master["etcd_lv"]}"
    registry_lv   = "${var.master["registry_lv"]}"
    management_lv = "${var.master["management_lv"]}"
    installer_lv  = "${var.installer_size}"
  }
}

data "template_file" "createfs_proxy" {
  template = "${file("${path.module}/scripts/createfs_proxy.sh.tpl")}"

  vars {
    kubelet_lv   = "${var.proxy["kubelet_lv"]}"
    docker_lv    = "${var.proxy["docker_lv"]}"
    installer_lv = "${var.installer_size}"
  }
}

data "template_file" "createfs_management" {
  template = "${file("${path.module}/scripts/createfs_management.sh.tpl")}"

  vars {
    kubelet_lv    = "${var.management["kubelet_lv"]}"
    docker_lv     = "${var.management["docker_lv"]}"
    management_lv = "${var.management["management_lv"]}"
    installer_lv  = "${var.installer_size}"
  }
}

data "template_file" "createfs_va" {
  template = "${file("${path.module}/scripts/createfs_va.sh.tpl")}"

  vars {
    kubelet_lv   = "${var.va["kubelet_lv"]}"
    docker_lv    = "${var.va["docker_lv"]}"
    va_lv        = "${var.va["va_lv"]}"
    installer_lv = "${var.installer_size}"
  }
}

data "template_file" "createfs_worker" {
  template = "${file("${path.module}/scripts/createfs_worker.sh.tpl")}"

  vars {
    kubelet_lv   = "${var.worker["kubelet_lv"]}"
    docker_lv    = "${var.worker["docker_lv"]}"
    installer_lv = "${var.installer_size}"
  }
}

//locals
locals {
  icp_boot_node_ip = "${aws_instance.master.0.public_ip}"
  heketi_ip        = "${aws_instance.gluster.0.public_ip}"
  ssh_options      = "-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
}

//instances
resource "aws_instance" "master" {
  count                       = "${var.master["nodes"]}"
  instance_type               = "${var.master["instance_type"]}"
  ami                         = "${var.image_id}"
  vpc_security_group_ids      = ["${aws_security_group.common_secgrp.id}", "${aws_security_group.master_secgrp.id}", "${aws_security_group.proxy_secgrp.id}"]
  subnet_id                   = "${aws_subnet.icp_subnet.id}"
  key_name                    = "${aws_key_pair.aws_public_key.id}"
  associate_public_ip_address = true

  #Calico requirement for single VPC
  source_dest_check = "false"

  tags {
    Name = "${format("%s-%s-%01d", lower(var.instance_prefix), lower(var.master["name"]),count.index + 1) }"
  }

  ebs_block_device {
    device_name = "/dev/sdf"
    volume_type = "gp2"
    volume_size = "${var.installer_size + var.master["kubelet_lv"] + var.master["docker_lv"] + var.master["registry_lv"] + var.master["etcd_lv"] + var.master["management_lv"] + 1}"
  }

  connection {
    user        = "${var.ssh_user}"
    private_key = "${tls_private_key.ssh.private_key_pem}"
    host        = "${self.public_ip}"
  }

  provisioner "file" {
    content     = "${data.template_file.createfs_master.rendered}"
    destination = "/tmp/createfs.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/createfs.sh; sudo /tmp/createfs.sh",
    ]
  }
}

resource "aws_instance" "proxy" {
  count                       = "${var.proxy["nodes"]}"
  instance_type               = "${var.proxy["instance_type"]}"
  ami                         = "${var.image_id}"
  vpc_security_group_ids      = ["${aws_security_group.common_secgrp.id}", "${aws_security_group.proxy_secgrp.id}"]
  subnet_id                   = "${aws_subnet.icp_subnet.id}"
  key_name                    = "${aws_key_pair.aws_public_key.id}"
  associate_public_ip_address = true

  #Calico requirement for single VPC
  source_dest_check = "false"

  tags {
    Name = "${format("%s-%s-%01d", lower(var.instance_prefix), lower(var.proxy["name"]),count.index + 1) }"
  }

  ebs_block_device {
    device_name = "/dev/sdf"
    volume_type = "gp2"
    volume_size = "${var.installer_size + var.proxy["kubelet_lv"] + var.proxy["docker_lv"] + 1}"
  }

  connection {
    user        = "${var.ssh_user}"
    private_key = "${tls_private_key.ssh.private_key_pem}"
    host        = "${self.public_ip}"
  }

  provisioner "file" {
    content     = "${data.template_file.createfs_proxy.rendered}"
    destination = "/tmp/createfs.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/createfs.sh; sudo /tmp/createfs.sh",
    ]
  }

  provisioner "local-exec" {
    when    = "destroy"
    command = "cat > ${var.key_pair_name} <<EOL\n${tls_private_key.ssh.private_key_pem}\nEOL"
  }

  provisioner "local-exec" {
    when    = "destroy"
    command = "chmod 600 ${var.key_pair_name}"
  }

  provisioner "local-exec" {
    when    = "destroy"
    command = "scp -i ${var.key_pair_name} ${local.ssh_options} ${path.module}/scripts/destroy/delete_node.sh ${var.ssh_user}@${local.icp_boot_node_ip}:/tmp/"
  }

  provisioner "local-exec" {
    when    = "destroy"
    command = "ssh -i ${var.key_pair_name} ${local.ssh_options} ${var.ssh_user}@${local.icp_boot_node_ip} \"chmod +x /tmp/delete_node.sh; /tmp/delete_node.sh ${var.icp_version} ${self.private_ip}\"; echo done"
  }
}

resource "aws_instance" "management" {
  count                       = "${var.management["nodes"]}"
  instance_type               = "${var.management["instance_type"]}"
  ami                         = "${var.image_id}"
  vpc_security_group_ids      = ["${aws_security_group.common_secgrp.id}"]
  subnet_id                   = "${aws_subnet.icp_subnet.id}"
  key_name                    = "${aws_key_pair.aws_public_key.id}"
  associate_public_ip_address = true

  #Calico requirement for single VPC
  source_dest_check = "false"

  tags {
    Name = "${format("%s-%s-%01d", lower(var.instance_prefix), lower(var.management["name"]),count.index + 1) }"
  }

  ebs_block_device {
    device_name = "/dev/sdf"
    volume_type = "gp2"
    volume_size = "${var.installer_size + var.management["kubelet_lv"] + var.management["docker_lv"] + var.management["management_lv"] + 1}"
  }

  connection {
    user        = "${var.ssh_user}"
    private_key = "${tls_private_key.ssh.private_key_pem}"
    host        = "${self.public_ip}"
  }

  provisioner "file" {
    content     = "${data.template_file.createfs_management.rendered}"
    destination = "/tmp/createfs.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/createfs.sh; sudo /tmp/createfs.sh",
    ]
  }

  provisioner "local-exec" {
    when    = "destroy"
    command = "cat > ${var.key_pair_name} <<EOL\n${tls_private_key.ssh.private_key_pem}\nEOL"
  }

  provisioner "local-exec" {
    when    = "destroy"
    command = "chmod 600 ${var.key_pair_name}"
  }

  provisioner "local-exec" {
    when    = "destroy"
    command = "scp -i ${var.key_pair_name} ${local.ssh_options} ${path.module}/scripts/destroy/delete_node.sh ${var.ssh_user}@${local.icp_boot_node_ip}:/tmp/"
  }

  provisioner "local-exec" {
    when    = "destroy"
    command = "ssh -i ${var.key_pair_name} ${local.ssh_options} ${var.ssh_user}@${local.icp_boot_node_ip} \"chmod +x /tmp/delete_node.sh; /tmp/delete_node.sh ${var.icp_version} ${self.private_ip}\"; echo done"
  }
}

resource "aws_instance" "va" {
  count                       = "${var.va["nodes"]}"
  instance_type               = "${var.va["instance_type"]}"
  ami                         = "${var.image_id}"
  vpc_security_group_ids      = ["${aws_security_group.common_secgrp.id}"]
  subnet_id                   = "${aws_subnet.icp_subnet.id}"
  key_name                    = "${aws_key_pair.aws_public_key.id}"
  associate_public_ip_address = true

  #Calico requirement for single VPC
  source_dest_check = "false"

  tags {
    Name = "${format("%s-%s-%01d", lower(var.instance_prefix), lower(var.va["name"]),count.index + 1) }"
  }

  ebs_block_device {
    device_name = "/dev/sdf"
    volume_type = "gp2"
    volume_size = "${var.installer_size + var.va["kubelet_lv"] + var.va["docker_lv"] + var.va["va_lv"] + 1}"
  }

  connection {
    user        = "${var.ssh_user}"
    private_key = "${tls_private_key.ssh.private_key_pem}"
    host        = "${self.public_ip}"
  }

  provisioner "file" {
    content     = "${data.template_file.createfs_va.rendered}"
    destination = "/tmp/createfs.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/createfs.sh; sudo /tmp/createfs.sh",
    ]
  }
}

resource "aws_instance" "worker" {
  depends_on = ["aws_instance.master", "aws_security_group.common_secgrp", "aws_internet_gateway.icp_igw", "aws_key_pair.aws_public_key", "aws_route.internet_access"]

  count                       = "${var.worker["nodes"]}"
  instance_type               = "${var.worker["instance_type"]}"
  ami                         = "${var.image_id}"
  vpc_security_group_ids      = ["${aws_security_group.common_secgrp.id}"]
  subnet_id                   = "${aws_subnet.icp_subnet.id}"
  key_name                    = "${aws_key_pair.aws_public_key.id}"
  associate_public_ip_address = true

  #Calico requirement for single VPC
  source_dest_check = "false"

  tags {
    Name = "${format("%s-%s-%01d", lower(var.instance_prefix), lower(var.worker["name"]),count.index + 1) }"
  }

  ebs_block_device {
    device_name = "/dev/sdf"
    volume_type = "gp2"
    volume_size = "${var.installer_size + var.worker["kubelet_lv"] + var.worker["docker_lv"] + 1}"
  }

  connection {
    user        = "${var.ssh_user}"
    private_key = "${tls_private_key.ssh.private_key_pem}"
    host        = "${self.public_ip}"
  }

  provisioner "file" {
    content     = "${data.template_file.createfs_worker.rendered}"
    destination = "/tmp/createfs.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/createfs.sh; sudo /tmp/createfs.sh",
    ]
  }

  provisioner "local-exec" {
    when    = "destroy"
    command = "cat > ${var.key_pair_name} <<EOL\n${tls_private_key.ssh.private_key_pem}\nEOL"
  }

  provisioner "local-exec" {
    when    = "destroy"
    command = "chmod 600 ${var.key_pair_name}"
  }

  provisioner "local-exec" {
    when    = "destroy"
    command = "scp -i ${var.key_pair_name} ${local.ssh_options} ${path.module}/scripts/destroy/delete_node.sh ${var.ssh_user}@${local.icp_boot_node_ip}:/tmp/"
  }

  provisioner "local-exec" {
    when    = "destroy"
    command = "ssh -i ${var.key_pair_name} ${local.ssh_options} ${var.ssh_user}@${local.icp_boot_node_ip} \"chmod +x /tmp/delete_node.sh; /tmp/delete_node.sh ${var.icp_version} ${self.private_ip}\"; echo done"
  }
}

resource "aws_instance" "gluster" {
  depends_on = ["aws_security_group.common_secgrp", "aws_internet_gateway.icp_igw", "aws_key_pair.aws_public_key", "aws_route.internet_access"]

  count                       = "${var.gluster["nodes"]}"
  instance_type               = "${var.gluster["instance_type"]}"
  ami                         = "${var.image_id}"
  vpc_security_group_ids      = ["${aws_security_group.common_secgrp.id}"]
  subnet_id                   = "${aws_subnet.icp_subnet.id}"
  key_name                    = "${aws_key_pair.aws_public_key.id}"
  associate_public_ip_address = true

  #Calico requirement for single VPC
  source_dest_check = "false"

  tags {
    Name = "${format("%s-%s-%01d", lower(var.instance_prefix), lower(var.gluster["name"]),count.index + 1) }"
  }

  ebs_block_device {
    #gluster
    device_name = "/dev/sdf"
    volume_type = "gp2"
    volume_size = "${var.gluster["glusterfs"]}"
  }

  connection {
    user        = "${var.ssh_user}"
    private_key = "${tls_private_key.ssh.private_key_pem}"
    host        = "${self.public_ip}"
  }

  provisioner "local-exec" {
    when    = "destroy"
    command = "cat > ${var.key_pair_name} <<EOL\n${tls_private_key.ssh.private_key_pem}\nEOL"
  }

  provisioner "local-exec" {
    when    = "destroy"
    command = "chmod 600 ${var.key_pair_name}"
  }

  provisioner "local-exec" {
    when    = "destroy"
    command = "scp -i ${var.key_pair_name} ${local.ssh_options} ${path.module}/scripts/destroy/delete_gluster.sh ${var.ssh_user}@${local.heketi_ip}:/tmp/"
  }

  provisioner "local-exec" {
    when    = "destroy"
    command = "ssh -i ${var.key_pair_name} ${local.ssh_options} ${var.ssh_user}@${local.heketi_ip} \"chmod +x /tmp/delete_gluster.sh; /tmp/delete_gluster.sh ${self.private_ip} ${var.heketi_admin_pwd}\"; echo done"
  }
}

resource "null_resource" "copy_delete_worker" {
  connection {
    host        = "${local.icp_boot_node_ip}"
    user        = "${var.ssh_user}"
    private_key = "${tls_private_key.ssh.private_key_pem}"
  }

  provisioner "file" {
    source      = "${path.module}/scripts/destroy/delete_node.sh"
    destination = "/tmp/delete_node.sh"
  }
}

resource "null_resource" "copy_delete_gluster" {
  connection {
    host        = "${local.heketi_ip}"
    user        = "${var.ssh_user}"
    private_key = "${tls_private_key.ssh.private_key_pem}"
  }

  provisioner "file" {
    source      = "${path.module}/scripts/destroy/delete_gluster.sh"
    destination = "/tmp/delete_gluster.sh"
  }
}

module "icpprovision" {
  #source = "github.com/pjgunadi/terraform-module-icp-deploy"

  source = "github.com/pjgunadi/terraform-module-icp-deploy?ref=2.1.0.3"

  //Connection IPs
  #icp-ips   = "${concat(aws_instance.master.*.public_ip, aws_instance.proxy.*.public_ip, aws_instance.management.*.public_ip, aws_instance.va.*.public_ip, aws_instance.worker.*.public_ip)}"
  icp-ips = "${concat(aws_instance.master.*.public_ip)}"

  boot-node = "${element(aws_instance.master.*.public_ip, 0)}"

  //Configuration IPs
  icp-master     = ["${aws_instance.master.*.private_ip}"]
  icp-worker     = ["${aws_instance.worker.*.private_ip}"]
  icp-proxy      = ["${split(",",var.proxy["nodes"] == 0 ? join(",",aws_instance.master.*.private_ip) : join(",",aws_instance.proxy.*.private_ip))}"]
  icp-management = ["${split(",",var.management["nodes"] == 0 ? "" : join(",",aws_instance.management.*.private_ip))}"]
  icp-va         = ["${split(",",var.va["nodes"] == 0 ? "" : join(",",aws_instance.va.*.private_ip))}"]

  # Workaround for terraform issue #10857
  cluster_size    = "${var.master["nodes"]}"
  worker_size     = "${var.worker["nodes"]}"
  proxy_size      = "${var.proxy["nodes"]}"
  management_size = "${var.management["nodes"]}"
  va_size         = "${var.va["nodes"]}"

  icp_source_server   = "${var.icp_source_server}"
  icp_source_user     = "${var.icp_source_user}"
  icp_source_password = "${var.icp_source_password}"
  image_file          = "${var.icp_source_path}"

  icp-version = "${var.icp_version}"

  icp_configuration = {
    "cluster_name"                   = "${var.cluster_name}"
    "network_cidr"                   = "${var.network_cidr}"
    "service_cluster_ip_range"       = "${var.cluster_ip_range}"
    "ansible_user"                   = "${var.ssh_user}"
    "ansible_become"                 = "true"
    "default_admin_password"         = "${var.icpadmin_password}"
    "calico_ipip_enabled"            = "true"
    "docker_log_max_size"            = "10m"
    "docker_log_max_file"            = "10"
    "cluster_lb_address"             = "${aws_instance.master.0.public_ip}"
    "proxy_lb_address"               = "${element(split(",",var.proxy["nodes"] == 0 ? join(",",aws_instance.master.*.public_ip) : join(",",aws_instance.proxy.*.public_ip)), 0)}"
    "calico_ip_autodetection_method" = "can-reach=${aws_instance.master.0.private_ip}"
    "disabled_management_services"   = ["${split(",",var.va["nodes"] != 0 ? join(",",var.disable_management) : join(",",concat(list("vulnerability-advisor"),var.disable_management)))}"]

    #"kibana_install"                 = "${var.kibana_install}"

    #"cluster_access_ip"        = "${aws_instance.master.0.public_ip}"
    #"proxy_access_ip"          = "${aws_instance.proxy.0.public_ip}"
    #"proxy_access_ip"          = "${aws_instance.master.0.public_ip}"
  }

  #Gluster
  #Gluster and Heketi nodes are set to worker nodes for demo. Use separate nodes for production
  install_gluster = "${var.install_gluster}"

  gluster_size        = "${var.gluster["nodes"]}"
  gluster_ips         = ["${aws_instance.gluster.*.public_ip}"]
  gluster_svc_ips     = ["${aws_instance.gluster.*.private_ip}"]
  device_name         = "/dev/xvdf"                              #update according to the device name provided by cloud provider
  heketi_ip           = "${aws_instance.gluster.0.public_ip}"
  heketi_svc_ip       = "${aws_instance.gluster.0.private_ip}"
  cluster_name        = "${var.cluster_name}.icp"
  gluster_volume_type = "${var.gluster_volume_type}"
  heketi_admin_pwd    = "${var.heketi_admin_pwd}"
  generate_key        = true

  #icp_pub_keyfile = "${tls_private_key.ssh.public_key_openssh}"
  #icp_priv_keyfile = "${tls_private_key.ssh.private_key_pem"}"

  ssh_user = "${var.ssh_user}"
  ssh_key  = "${tls_private_key.ssh.private_key_pem}"
}
