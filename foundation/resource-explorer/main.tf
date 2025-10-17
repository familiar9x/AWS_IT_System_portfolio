# Foundation: AWS Resource Explorer
# Index & View toàn org để query tài nguyên

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Resource Explorer Index (aggregator region)
resource "aws_resourceexplorer2_index" "aggregator" {
  type = "AGGREGATOR"

  tags = {
    Name        = "Resource Explorer Aggregator"
    Environment = "foundation"
    ManagedBy   = "Terraform"
  }
}

# Default View
resource "aws_resourceexplorer2_view" "default" {
  name         = "default-view"
  default_view = true

  included_property {
    name = "tags"
  }

  filters {
    filter_string = ""
  }

  tags = {
    Name        = "Default Resource Explorer View"
    Environment = "foundation"
    ManagedBy   = "Terraform"
  }

  depends_on = [aws_resourceexplorer2_index.aggregator]
}

# Application-specific view
resource "aws_resourceexplorer2_view" "applications" {
  name = "applications-view"

  included_property {
    name = "tags"
  }

  filters {
    filter_string = "tag.key:awsApplication"
  }

  tags = {
    Name        = "Applications Resource Explorer View"
    Environment = "foundation"
    ManagedBy   = "Terraform"
  }

  depends_on = [aws_resourceexplorer2_index.aggregator]
}
