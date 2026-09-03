# Teardown Guide — Multi-Cloud PKI Lab

> **CRITICAL**: Ensure ALL project resources are destroyed and independently verified.

## Azure Teardown

### Method 1: Terraform Destroy (if applied)

```bash
cd infra/terraform/azure
terraform destroy
```

### Method 2: Manual Cleanup (if Terraform state is lost)

```bash
# Delete resource group (deletes all contained resources)
az group delete --name pki-cloudlab-lab-rg --yes

# Verify deletion
az group list --query "[?name=='pki-cloudlab-lab-rg']"
```

### Independent Verification

```bash
# List all resources with project tag
az resource list --tag "project=pki-cloudlab" --output table

# Check for lingering resources
az resource list --resource-group pki-cloudlab-lab-rg
```

## AWS Teardown

### Method 1: Terraform Destroy (if applied)

```bash
cd infra/terraform/aws
terraform destroy
```

### Method 2: Manual Cleanup (if Terraform state is lost)

```bash
# Terminate EC2 instance
aws ec2 terminate-instances --instance-ids <INSTANCE_ID>

# Delete EBS volumes (if not deleted automatically)
aws ec2 delete-volume --volume-id <VOLUME_ID>

# Delete security group
aws ec2 delete-security-group --group-id <SG_ID>

# Delete subnet
aws ec2 delete-subnet --subnet-id <SUBNET_ID>

# Delete route table
aws ec2 delete-route-table --route-table-id <RT_ID>

# Detach and delete internet gateway
aws ec2 detach-internet-gateway --internet-gateway-id <IGW_ID> --vpc-id <VPC_ID>
aws ec2 delete-internet-gateway --internet-gateway-id <IGW_ID>

# Delete VPC
aws ec2 delete-vpc --vpc-id <VPC_ID>

# Delete IAM instance profile
aws iam remove-role-from-instance-profile --instance-profile-name <PROFILE_NAME> --role-name <ROLE_NAME>
aws iam delete-instance-profile --instance-profile-name <PROFILE_NAME>

# Delete IAM role policy
aws iam delete-role-policy --role-name <ROLE_NAME> --policy-name <POLICY_NAME>

# Delete IAM role
aws iam delete-role --role-name <ROLE_NAME>

# Delete key pair
aws ec2 delete-key-pair --key-name <KEY_NAME>
```

### Independent Verification

```bash
# EC2 instances
aws ec2 describe-instances --filters "Name=tag:Project,Values=pki-cloudlab" --query 'Reservations[*].Instances[*].InstanceId'

# EBS volumes
aws ec2 describe-volumes --filters "Name=tag:Project,Values=pki-cloudlab" --query 'Volumes[*].VolumeId'

# VPCs
aws ec2 describe-vpcs --filters "Name=tag:Project,Values=pki-cloudlab" --query 'Vpcs[*].VpcId'

# Security groups
aws ec2 describe-security-groups --filters "Name=tag:Project,Values=pki-cloudlab" --query 'SecurityGroups[*].GroupId'

# IAM roles
aws iam list-roles --query 'Roles[?contains(Tags[?Key==`Project`].Value, `pki-cloudlab`)].RoleName'
```

## Verification Checklist

- [ ] All EC2 instances terminated
- [ ] All EBS volumes deleted
- [ ] All snapshots deleted
- [ ] All Elastic IPs released
- [ ] All ENIs deleted
- [ ] All security groups deleted
- [ ] All VPCs deleted
- [ ] All subnets deleted
- [ ] All route tables deleted
- [ ] All internet gateways deleted
- [ ] All IAM roles deleted
- [ ] All IAM instance profiles deleted
- [ ] All key pairs deleted
- [ ] All Azure VMs deleted
- [ ] All Azure disks deleted
- [ ] All Azure resource groups deleted
- [ ] All Azure VNets deleted
- [ ] All Azure NSGs deleted
- [ ] All Azure public IPs deleted

## Final State

```
Azure project resources remaining: 0
AWS project resources remaining: 0
Local homelab: unchanged and healthy
```
