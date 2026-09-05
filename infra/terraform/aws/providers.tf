terraform {
  required_version = ">= 1.0, < 2.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Local state for lab environment
  # For production, use remote backend:
  # backend "s3" {
  #   bucket         = "aws s3api head-bucket --bucket tfstate-pki-lab"
  #   key            = "aws/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "terraform-locks"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      project    = var.project_name
      managed_by = "terraform"
      ephemeral  = "true"
      owner      = "homelab"
    }
  }
}
