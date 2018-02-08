# Terraform Template for ICP Deployment in AWS

## Before you start
You need an AWS account and be aware that **applying this template may incur charges to your AWS account**.

## Summary
This terraform template perform the following tasks:
- Provision AWS environment for IBM Cloud Private (ICP)
- [Provision ICP and GlusterFS from external module](https://github.com/pjgunadi/terraform-module-icp-deploy)

## Deployment step from Terraform CLI
1. Clone this repository: `git clone https://github.com/pjgunadi/ibm-cloud-private-terraform-aws.git`
2. [Download terraform](https://www.terraform.io/) if you don't have one
3. Login to AWS and create an API access and secret key. [Reference](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_access-keys.html)
4. Rename [terraform_tfvars.sample](terraform_tfvars.sample) file as `terraform.tfvars` and update the input values as needed.
5. Initialize Terraform
```
terraform init
```
6. Review Terraform plan
```
terraform plan
```
7. Apply Terraform template
```
terraform apply
```

## ICP and Gluster Provisioning Module
The ICP and GlusterFS Installation is performed by [ICP Provisioning module](https://github.com/pjgunadi/terraform-module-icp-deploy) 
