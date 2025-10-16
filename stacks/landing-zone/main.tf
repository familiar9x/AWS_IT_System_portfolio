# AWS Organizations
resource "aws_organizations_organization" "main" {
  aws_service_access_principals = [
    "cloudtrail.amazonaws.com",
    "config.amazonaws.com",
    "ram.amazonaws.com",
    "servicecatalog.amazonaws.com",
    "sso.amazonaws.com",
    "tagpolicies.tag.amazonaws.com",
  ]

  enabled_policy_types = [
    "SERVICE_CONTROL_POLICY",
    "TAG_POLICY",
  ]

  feature_set = "ALL"
}

# Organizational Units
resource "aws_organizations_organizational_unit" "ou" {
  for_each = var.organizational_units

  name      = each.value.name
  parent_id = each.value.parent == "root" ? aws_organizations_organization.main.roots[0].id : aws_organizations_organizational_unit.ou[each.value.parent].id
}

# Service Control Policies
resource "aws_organizations_policy" "scp" {
  for_each = var.scp_policies

  name        = each.value.name
  description = each.value.description
  type        = "SERVICE_CONTROL_POLICY"
  content     = each.value.policy
}

resource "aws_organizations_policy_attachment" "scp_attachment" {
  for_each = { for k, v in var.scp_policies : k => v if length(v.targets) > 0 }

  policy_id = aws_organizations_policy.scp[each.key].id
  target_id = each.value.targets[0]
}

# Tagging Policies Module
module "tagging_policies" {
  source = "../../modules/tagging_policies"

  organization_id = aws_organizations_organization.main.id
  root_id         = aws_organizations_organization.main.roots[0].id
  environment     = var.environment
}
