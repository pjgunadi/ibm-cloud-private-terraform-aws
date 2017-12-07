variable access_key {
    description = "AWS Access Key"
}
variable secret_key {
    description = "AWS Secret Key"
}
variable region {
    description = "AWS Region"
    default = "ap-southeast-1"
}
variable image_id {
    description = "Image ID, Ubuntu: ami-10acfb73, RHEL: ami-10bb2373"
    default = "ami-10acfb73"
}
variable key_pair_name {
    description = "AWS Key Pair Name"
    default = "aws-key"
}
variable public_key {
    description = "AWS Public Key"
    default = ""
}
variable "ssh_user" {
    description = "SSH User ubuntu: ubuntu, rhel: ec2-user"
    default = "ubuntu"
}
variable "icpadmin_password" {
    description = "ICP admin password"
    default = "admin"
}
variable "master" {
    type = "map"
    default = {
        nodes = "1"
        name = "master"
        instance_type = "t2.large"
    }
}
variable "proxy" {
    type = "map"
    default = {
        nodes = "1"
        name = "proxy"
        instance_type = "t2.medium"
    }
}
variable "worker" {
    type = "map"
    default = {
        nodes = "3"
        name = "worker"
        instance_type = "t2.medium"
    }
}
variable "management" {
    type = "map"
    default = {
        nodes = "1"
        name = "management"
        instance_type = "t2.large"
    }
}
