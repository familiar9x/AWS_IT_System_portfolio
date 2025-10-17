provider "aws" {
  region = "ap-southeast-1"

  default_tags {
    tags = {
      Environment = "dev"
      Component   = "ConfigRecorder"
      ManagedBy   = "Terraform"
    }
  }
}
