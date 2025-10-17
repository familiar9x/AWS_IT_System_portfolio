output "organization_id" {
  description = "AWS Organization ID"
  value       = aws_organizations_organization.main.id
}

output "organization_arn" {
  description = "AWS Organization ARN"
  value       = aws_organizations_organization.main.arn
}

output "root_id" {
  description = "Root organizational unit ID"
  value       = aws_organizations_organization.main.roots[0].id
}

output "organizational_units" {
  description = "Created organizational units"
  value = {
    for k, v in aws_organizations_organizational_unit.ou : k => {
      id   = v.id
      arn  = v.arn
      name = v.name
    }
  }
}
