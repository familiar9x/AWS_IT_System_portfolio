# Tag Policy - Mandatory Tags
resource "aws_organizations_policy" "mandatory_tags" {
  name        = "MandatoryTags-${var.environment}"
  description = "Enforce mandatory tags across organization"
  type        = "TAG_POLICY"

  content = jsonencode({
    tags = {
      Application = {
        tag_key = {
          "@@assign" = "Application"
        }
        enforced_for = {
          "@@assign" = [
            "ec2:instance",
            "ec2:volume",
            "rds:db",
            "s3:bucket",
            "lambda:function",
            "dynamodb:table",
            "ecs:cluster",
            "ecs:service",
            "elasticloadbalancing:loadbalancer"
          ]
        }
      }
      Environment = {
        tag_key = {
          "@@assign" = "Environment"
        }
        tag_value = {
          "@@assign" = ["dev", "staging", "prod"]
        }
        enforced_for = {
          "@@assign" = [
            "ec2:instance",
            "ec2:volume",
            "rds:db",
            "s3:bucket",
            "lambda:function"
          ]
        }
      }
      Owner = {
        tag_key = {
          "@@assign" = "Owner"
        }
        enforced_for = {
          "@@assign" = [
            "ec2:instance",
            "rds:db",
            "s3:bucket"
          ]
        }
      }
      CostCenter = {
        tag_key = {
          "@@assign" = "CostCenter"
        }
        enforced_for = {
          "@@assign" = [
            "ec2:instance",
            "rds:db",
            "s3:bucket"
          ]
        }
      }
      BusinessUnit = {
        tag_key = {
          "@@assign" = "BusinessUnit"
        }
        enforced_for = {
          "@@assign" = [
            "ec2:instance",
            "rds:db",
            "s3:bucket"
          ]
        }
      }
      ManagedBy = {
        tag_key = {
          "@@assign" = "ManagedBy"
        }
        tag_value = {
          "@@assign" = ["IaC-Terraform", "Manual", "CloudFormation"]
        }
        enforced_for = {
          "@@assign" = [
            "ec2:instance",
            "rds:db",
            "s3:bucket"
          ]
        }
      }
      DataClass = {
        tag_key = {
          "@@assign" = "DataClass"
        }
        tag_value = {
          "@@assign" = ["Public", "Internal", "Confidential", "Restricted"]
        }
        enforced_for = {
          "@@assign" = [
            "rds:db",
            "s3:bucket",
            "dynamodb:table"
          ]
        }
      }
      Criticality = {
        tag_key = {
          "@@assign" = "Criticality"
        }
        tag_value = {
          "@@assign" = ["Low", "Medium", "High", "Critical"]
        }
        enforced_for = {
          "@@assign" = [
            "ec2:instance",
            "rds:db"
          ]
        }
      }
      DRTier = {
        tag_key = {
          "@@assign" = "DRTier"
        }
        tag_value = {
          "@@assign" = ["Bronze", "Silver", "Gold", "Platinum"]
        }
        enforced_for = {
          "@@assign" = [
            "ec2:instance",
            "rds:db"
          ]
        }
      }
    }
  })
}

# Attach Tag Policy to Root
resource "aws_organizations_policy_attachment" "mandatory_tags" {
  policy_id = aws_organizations_policy.mandatory_tags.id
  target_id = var.root_id
}
