terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # Backend local por padrao. Para trabalho em equipe, migre para S3 + DynamoDB lock.
  # backend "s3" {
  #   bucket = "injurydetector-tfstate"
  #   key    = "service/terraform.tfstate"
  #   region = "us-east-1"
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "InjuryDetector"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

# Nome-base padronizado para recursos: injurydetector-<env>
locals {
  name_prefix = "${var.project_name}-${var.environment}"
}
