provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      Environment = "dev"
      Component   = "ConfigRecorder"
      ManagedBy   = "Terraform"
    }
  }
}
