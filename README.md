#Terraform Template for ICP Deployment in AWS

##Before you start
You need an AWS account and be aware that **applying this template may incur charges to your AWS account**.

##Summary
This terraform template perform the following tasks:
- Provision AWS environment for IBM Cloud Private
- [Call ICP Provisioning Module](https://github.com/pjgunadi/terraform-module-icp-deploy)

##Input
| Variable      | Description    | Sample Value |
| ------------- | -------------- | ------------ |
| access_key    | AWS Acces Key  | xxxxxxxxxxxx |
| secret_key    | AWS Secret Key | xxxxxxxxxxxx |
| region        | AWS Region     | ap-southeast-1 |
| image_id      | AWS Image ID (AMI). Choose only Ubuntu or RHEL Image | ami-10acfb73 (ubuntu), ami-10bb2373 (rhel) |
| key_pair_name | Public key label to be added in AWS | aws-key |
| public_key_path | Local path to your public key file | /home/myuser/.ssh/aws-key.pub |
| ssh_user | Login user to ICP instances | ubuntu or ec2-user (RHEL) |
| master | Master nodes information | {nodes="1", name="master", instance_type="t2.large"} |
| proxy | Proxy node information | {nodes="1", name="proxy", instance_type="t2.medium"} |
| worker | Worker node information | {nodes="3", name="worker", instance_type="t2.medium"} |
| management | Management node information | {nodes="1", name="management", instance_type="t2.large"} |

##Deployment step
1. Clone this repository: `git clone https://github.com/pjgunadi/ibm-cloud-private-terraform-aws.git`
2. [Download terraform](https://www.terraform.io/) if you don't have one
3. Create terraform variable file with your input value e.g. `terraform.tfvars`
4. Apply the template
```
terraform init
terraform plan
terraform apply
```
##ICP Provisioning Module
This [ICP Provisioning module](https://github.com/pjgunadi/terraform-module-icp-deploy) is forked from [IBM Cloud Architecture](https://github.com/ibm-cloud-architecture/terraform-module-icp-deploy)
with few modifications:
- Added Management nodes section
- Separate Local IP and Public IP variables
- Added boot-node IP variable

##Limitations
1. Current template attach fixed size of additional block storage. It can be set as variable in the future. In the mean time, you can update in the template directly
2. Security Group rules still require enhancement
