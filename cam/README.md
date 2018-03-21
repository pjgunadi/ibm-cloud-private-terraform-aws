# ICP Deployment in AWS with IBM CAM

## Before you start
You need an AWS account and be aware that **applying this template may incur charges to your AWS account**.

## Summary
This terraform template perform the following tasks:
- Provision IBM Cloud Private (ICP) in AWS
- [Provision ICP and GlusterFS from external module](https://github.com/pjgunadi/terraform-module-icp-deploy)

## Deployment step from IBM CAM
1. Login into IBM CAM
2. Login to AWS and create an API access and secret key. [Reference](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_access-keys.html)
3. Create Template with the following details:
  - From GitHub
  - GitHub Repository URL: `https://github.com/pjgunadi/ibm-cloud-private-terraform-aws`
  - GitHub Repository sub-directory: `cam`
4. Click `Create` and `Save`
5. Deploy the template

## Add/Remove Worker Nodes
1. Open Deployed Instance in CAM
2. Open `Modify` tab
3. Click `Next`
4. Increase/decrease the **Worker Node** `nodes` attribute
5. Click `Plan Changes`
6. Review the plan in the Log Output and click `Apply Changes`

**Note:** The data disk size is the sume of LV variables + 1 (e.g kubelet_lv + docker_lv + 1).  

## ICP and Gluster Provisioning Module
The ICP and GlusterFS Installation is performed by [ICP Provisioning module](https://github.com/pjgunadi/terraform-module-icp-deploy) 
