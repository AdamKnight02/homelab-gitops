# Workflow Findings

## Critical Findings

### .github/workflows/argo-sync-check.yaml
- [schema] The workflow file is valid YAML but contains a step with a 'run' command that only prints expected checks instead of actually performing them. This appears to be a placeholder or documentation step.

## Warning Findings

### .github/workflows/aws-deploy-addon.yml
- [security] Workflow uses AWS credentials with role assumption. Ensure that AWS_DEPLOY_ROLE_ARN is properly restricted with least privilege IAM policies.
- [security] Job 'plan' uses 'TF_STATE_KEY' with customer ID and environment in the state key. Ensure proper encryption and access control for Terraform state files.
- [security] Job 'deploy-addon' uses 'terraform apply' with '-auto-approve'. Ensure this is intentional and safe for production environments.
- [security] Job 'report' generates a report with sensitive information such as customer ID, environment, and addon type. Ensure this report is not exposed to unauthorized users.

### .github/workflows/aws-deploy-customer.yml
- [security] The workflow uses 'AWS_ROLE_ARN' secret for AWS credential configuration.
- [security] The workflow uses 'ARGOCD_SERVER' and 'ARGOCD_AUTH_TOKEN' secrets for ArgoCD configuration.
- [security] The workflow uses 'TF_DIR' environment variable that is not validated for security.
- [security] The workflow uses multiple 'TF_VAR_*' environment variables that are set from user inputs without validation.
- [defect] The 'approval' job references needs.validate.outputs.* but only declares 'needs: plan', so those values evaluate empty. The 'needs' list should include 'validate'.

### .github/workflows/azure-deploy-addon.yml
- The workflow uses a local script '.github/scripts/init-azure-backend.sh' which does not exist in the repository
- The workflow references secrets: AZURE_CLIENT_ID, AZURE_TENANT_ID, AZURE_SUBSCRIPTION_ID
- The workflow uses a variable 'AZURE_TFSTATE_RESOURCE_GROUP' which is referenced from GitHub vars but not defined in the workflow
- The workflow uses a variable 'AZURE_TFSTATE_STORAGE_ACCOUNT' which is referenced from GitHub vars but not defined in the workflow
- The workflow uses a variable 'AZURE_TFSTATE_CONTAINER' which is referenced from GitHub vars but not defined in the workflow
- The workflow references 'gitops/external-ca-gateway/${PROVIDER}/' which could potentially be a non-existent directory structure
- The workflow uses multiple kubectl commands that require a valid cluster connection
- The workflow uses multiple terraform commands that require a valid backend configuration
- The workflow has a hardcoded path 'infra/terraform/azure' for Terraform working directory

### .github/workflows/azure-deploy-customer.yml
- [incomplete_implementation] In job 'deploy-platform', the 'Configure kubeconfig' step has a placeholder comment and no actual implementation.
- [incomplete_implementation] In job 'deploy-platform', the 'Argo CD Sync' step has a placeholder comment and no actual implementation.
- [incomplete_implementation] In job 'deploy-platform', the 'Wait for Apps Synced' step has a placeholder comment and no actual implementation.
- [incomplete_implementation] In job 'deploy-platform', the 'Verify Pods' step has a placeholder comment and no actual implementation.
- [incomplete_implementation] In job 'deploy-platform', the 'Configure External CA' step has a placeholder comment and no actual implementation.
- [incomplete_implementation] In job 'smoke-tests', the 'Static Validation' step has a placeholder comment and no actual implementation.
- [incomplete_implementation] In job 'smoke-tests', the 'Infrastructure Tests' step has a placeholder comment and no actual implementation.
- [incomplete_implementation] In job 'smoke-tests', the 'Kubernetes Tests' step has a placeholder comment and no actual implementation.
- [incomplete_implementation] In job 'smoke-tests', the 'Platform Tests' step has a placeholder comment and no actual implementation.
- [incomplete_implementation] In job 'smoke-tests', the 'PKI Tests' step has a placeholder comment and no actual implementation.
- [incomplete_implementation] In job 'smoke-tests', the 'Monitoring Tests' step has a placeholder comment and no actual implementation.
- [incomplete_implementation] In job 'smoke-tests', the 'External CA Tests' step has a placeholder comment and no actual implementation.
- [incomplete_implementation] In job 'report', the 'Publish Results' step has a placeholder comment and no actual implementation.
- [incomplete_implementation] In job 'report', the 'Notify Stakeholders' step has a placeholder comment and no actual implementation.
- [secret_usage] Secrets used: AZURE_CREDENTIALS, ARM_CLIENT_ID, ARM_CLIENT_SECRET, ARM_SUBSCRIPTION_ID, ARM_TENANT_ID

### .github/workflows/deploy-customer.yml
- [yaml_schema_issue] In the 'configure' job, the script directory 'configuration' does not exist on disk, but is referenced in steps.

### .github/workflows/terraform-apply.yml
- The script '.github/scripts/init-azure-backend.sh' referenced in the 'Initialize Azure Backend' step does not exist on disk.
- The workflow uses a 'workflow_call' trigger, which means it can be called by other workflows, but it's not explicitly defined in the repository's workflows directory.
- The workflow uses environment variables that are set from secrets (e.g., ARM_CLIENT_ID, ARM_TENANT_ID, etc.) but no validation is performed to ensure these secrets are properly configured.
- The 'verify' job has a placeholder for 'Infrastructure Health Check' that needs to be implemented with actual checks.
- The 'apply' job uses 'terraform apply' with '-auto-approve', which can be dangerous if not properly controlled.
- The 'apply' job uses 'terraform output -json' and then processes the output with Python, which could be a security risk if the output is not properly sanitized.

## Info Findings

### .github/workflows/destroy.yml
- [secret_usage] AZURE_CLIENT_ID
- [secret_usage] AZURE_TENANT_ID
- [secret_usage] AZURE_SUBSCRIPTION_ID
- [secret_usage] AWS_ACCESS_KEY_ID
- [secret_usage] AWS_SECRET_ACCESS_KEY
- [secret_usage] AWS_DEFAULT_REGION

# README Drift

## Missing workflows

- [aws-deploy-addon.yml] AWS addon deployment workflow
- [azure-deploy-addon.yml] Azure addon deployment workflow
- [deploy-aws-lab.yml] AWS lab deployment workflow
- [aws-deploy-customer.yml] AWS customer deployment workflow
- [azure-deploy-customer.yml] Azure customer deployment workflow
