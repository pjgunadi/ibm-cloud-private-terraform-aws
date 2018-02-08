output "icp_url" {
  value = "https://${aws_instance.master.0.public_ip}:8443"
}
