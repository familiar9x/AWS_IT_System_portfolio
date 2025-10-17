provider "aws" {
  region = var.region

  default_tags {
    tags = {
      ManagedBy = "Terraform"
      Layer     = "Foundation"
      Component = "ConfigRecorder"
    }
  }
}
