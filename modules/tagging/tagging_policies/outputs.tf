output "tag_policy_id" {
  description = "Tag Policy ID"
  value       = aws_organizations_policy.mandatory_tags.id
}

output "tag_policy_arn" {
  description = "Tag Policy ARN"
  value       = aws_organizations_policy.mandatory_tags.arn
}
