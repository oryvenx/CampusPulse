terraform {
  required_version = ">= 1.7.0"

  backend "s3" {
    bucket         = "campuspulse-tfstate-5e26c4b7" # ← paste your bucket from Step 2
    key            = "campuspulse/terraform.tfstate"
    region         = "eu-west-3"
    dynamodb_table = "campuspulse-tfstate-lock"
    encrypt        = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {
  state = "available"
}
