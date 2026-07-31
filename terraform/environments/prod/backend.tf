# Separate state file/key from dev so a mistake in one environment can never
# touch the other's state. Same S3 bucket/DynamoDB table can be reused
# across environments since the `key` path is what isolates them, but
# using a dedicated prod bucket is also a reasonable, more conservative
# choice - swap REPLACE_ME below if you go that route.
terraform {
  backend "s3" {
    bucket         = "REPLACE_ME-terraform-state-prod"
    key            = "aws-terraform-infra/prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
