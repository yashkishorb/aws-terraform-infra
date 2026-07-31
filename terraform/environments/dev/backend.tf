# Remote state, stored encrypted in S3 with DynamoDB state locking so two
# people (or two CI runs) can never apply at the same time and clobber
# each other's state.
#
# NOTE: the bucket and table below must exist before running `terraform
# init` here. See README.md "Prerequisites" for the one-time bootstrap
# commands (kept out of Terraform itself to avoid the classic chicken-and-
# egg problem of using Terraform to create its own backend).
terraform {
  backend "s3" {
    bucket         = "REPLACE_ME-terraform-state-dev"
    key            = "aws-terraform-infra/dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
