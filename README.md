# Terraform Template for ICP Deployment in AWS

## Before you start
You need an AWS account and be aware that **applying this template may incur charges to your AWS account**.

## Summary
This terraform template perform the following tasks:
- Provision IBM Cloud Private (ICP) in AWS
- [Provision ICP and GlusterFS from external module](https://github.com/pjgunadi/terraform-module-icp-deploy)

## Deployment step from Terraform CLI
1. Clone this repository: `git clone https://github.com/pjgunadi/ibm-cloud-private-terraform-aws.git`
2. [Download terraform](https://www.terraform.io/) if you don't have one
3. Login to AWS and create an API access and secret key. [Reference](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_access-keys.html)
4. Rename [terraform_tfvars.sample](terraform_tfvars.sample) file as `terraform.tfvars` and update the input values as needed.
5. Initialize Terraform to download and update the dependencies
```
terraform init -upgrade
```
6. Review Terraform plan
```
terraform plan
```
7. Apply Terraform template
```
terraform apply
```
## Add/Remove Worker Nodes
1. Edit existing deployed terraform variable e.g. `terraform.tfvars`
2. Increase/decrease the `nodes` under the `worker` map variable. Example:
```
worker = {
    nodes         = "4"
    name          = "worker"
    instance_type = "t2.xlarge"
    kubelet_lv    = "10"
    docker_lv     = "90"
}
```
**Note:** The data disk size is the sume of LV variables + 1 (e.g kubelet_lv + docker_lv + 1).  
3. Re-apply terraform template:
```
terraform plan
terraform apply -auto-approve
```
## ICP and Gluster Provisioning Module
The ICP and GlusterFS Installation is performed by [ICP Provisioning module](https://github.com/pjgunadi/terraform-module-icp-deploy) 
