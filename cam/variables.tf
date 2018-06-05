# variable access_key {
#   description = "AWS Access Key"
# }

# variable secret_key {
#   description = "AWS Secret Key"
# }

variable region {
  description = "AWS Region"
  default     = "ap-southeast-1"
}

variable image_id {
  description = "Image ID, Ubuntu: ami-10acfb73, RHEL: ami-10bb2373"
  default     = "ami-10acfb73"
}

variable key_pair_name {
  description = "AWS Key Pair Name"
  default     = "aws-key"
}

variable public_key {
  description = "AWS Public Key"
  default     = ""
}

variable aws_vpc_cidr {
  default = "10.10.0.0/16"
}

variable aws_subnet {
  default = "10.10.0.0/24"
}

variable "ssh_user" {
  description = "SSH User ubuntu: ubuntu, rhel: ec2-user"
  default     = "ubuntu"
}

##### ICP Instance details ######
variable "icp_version" {
  description = "ICP Version"
  default     = "2.1.0.3"
}

variable "network_cidr" {
  default = "172.16.0.0/16"
}

variable "cluster_ip_range" {
  default = "10.10.1.1/24"
}

variable "cluster_name" {
  default = "mycluster"
}

variable icp_source_server {
  default = ""
}

variable icp_source_user {
  default = ""
}

variable icp_source_password {
  default = ""
}

variable icp_source_path {
  default = ""
}

variable install_gluster {
  default = false
}

variable "instance_prefix" {
  default = "icp"
}

variable "icpadmin_password" {
  description = "ICP admin password"
  default     = "admin"
}

variable "disable_management" {
  default = ["istio", "custom-metrics-adapter"]
}

variable "gluster_volume_type" {
  default = "none"
}

variable "heketi_admin_pwd" {
  default = "none"
}

variable "installer_size" {
  default = "20"
}

variable "master" {
  type = "map"

  default = {
    nodes         = "1"
    name          = "master"
    instance_type = "t2.xlarge"
    kubelet_lv    = "10"
    docker_lv     = "50"
    registry_lv   = "35"
    etcd_lv       = "4"
    management_lv = "100"
  }
}

variable "proxy" {
  type = "map"

  default = {
    nodes         = "0"
    name          = "proxy"
    instance_type = "t2.medium"
    kubelet_lv    = "10"
    docker_lv     = "39"
  }
}

variable "management" {
  type = "map"

  default = {
    nodes         = "0"
    name          = "management"
    instance_type = "t2.xlarge"
    kubelet_lv    = "10"
    docker_lv     = "39"
    management_lv = "100"
  }
}

variable "va" {
  type = "map"

  default = {
    nodes         = "1"
    name          = "va"
    instance_type = "t2.xlarge"
    kubelet_lv    = "10"
    docker_lv     = "39"
    va_lv         = "100"
  }
}

variable "worker" {
  type = "map"

  default = {
    nodes         = "2"
    name          = "worker"
    instance_type = "t2.xlarge"
    kubelet_lv    = "10"
    docker_lv     = "89"
    glusterfs     = "100"
  }
}

variable "gluster" {
  type = "map"

  default = {
    nodes         = "3"
    name          = "gluster"
    instance_type = "t2.medium"
    glusterfs     = "100"
  }
}
