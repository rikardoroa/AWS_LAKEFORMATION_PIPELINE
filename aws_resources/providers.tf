terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.7.1"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2.4"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.6.2"
    }
  }

  backend "s3" {
    encrypt        = true
    key            = "terraform/state/terraform.tfstate"
    dynamodb_table = "terraform-coinbase-data-state"
    region         = "us-east-2"
  }
}

provider "aws" {
  region = "us-east-2"

  assume_role {
    role_arn     =  module.lambda_utils.lambda_role
    session_name = "terraform-lakeformation"
  }
}


# provider "aws" {
#   region = "us-east-2"

#   assume_role {
#     role_arn     =  module.lambda_utils.lambda_arn
#     session_name = "terraform-lakeformation"
#   }
# }