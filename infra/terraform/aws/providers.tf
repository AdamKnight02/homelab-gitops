terraform {
  backend "s3" {
    bucket  = "homelab-terraform-state-962500057493"
    key     = "aws/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}
