output "icp_url" {
  value = "https://${element(aws_instance.master.*.public_ip, 0)}:8443"
}
