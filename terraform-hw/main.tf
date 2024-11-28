terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.70.0"
    }
  }
}

provider "aws" {
  region                 = "eu-north-1"
  shared_credentials_files = ["$HOME/.aws/credentials"]
}
