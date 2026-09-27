#!/bin/bash
# Initialize Azure backend for Terraform
# This script is designed to be used in GitHub Actions workflows.
# It validates backend configuration and initializes the azurerm backend.

set -euo pipefail

# Function to print usage
usage() {
    echo "Usage: $0 <state_key>"
    echo "  state_key: The Terraform state key to use for this deployment"
    exit 1
}

# Check if state key is provided
if [ $# -ne 1 ]; then
    echo "Error: State key is required"
    usage
fi

STATE_KEY="$1"

# Check if required environment variables are set
if [ -z "${AZURE_TFSTATE_RESOURCE_GROUP:-}" ]; then
    echo "Error: AZURE_TFSTATE_RESOURCE_GROUP is not set"
    exit 1
fi

if [ -z "${AZURE_TFSTATE_STORAGE_ACCOUNT:-}" ]; then
    echo "Error: AZURE_TFSTATE_STORAGE_ACCOUNT is not set"
    exit 1
fi

if [ -z "${AZURE_TFSTATE_CONTAINER:-}" ]; then
    echo "Error: AZURE_TFSTATE_CONTAINER is not set"
    exit 1
fi

if [ -z "$STATE_KEY" ]; then
    echo "Error: State key is not set"
    exit 1
fi

# Initialize the Azure backend with the provided state key
# Using explicit azurerm backend parameters for OIDC authentication
# Note: No credentials or tokens are printed

echo "Initializing Azure backend with state key: $STATE_KEY"
terraform init \
    -backend-config="resource_group_name=$AZURE_TFSTATE_RESOURCE_GROUP" \
    -backend-config="storage_account_name=$AZURE_TFSTATE_STORAGE_ACCOUNT" \
    -backend-config="container_name=$AZURE_TFSTATE_CONTAINER" \
    -backend-config="key=$STATE_KEY" \
    -backend-config="use_oidc=true" \
    -backend-config="use_azuread_auth=true" \
    -input=false

echo "Azure backend initialized successfully"