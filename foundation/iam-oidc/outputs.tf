output "oidc_provider_arn" {
  description = "ARN of GitHub OIDC provider"
  value       = aws_iam_openid_connect_provider.github.arn
}

output "github_actions_role_dev_arn" {
  description = "ARN of GitHub Actions role for dev environment"
  value       = aws_iam_role.github_actions_dev.arn
}

output "github_actions_role_stg_arn" {
  description = "ARN of GitHub Actions role for stg environment"
  value       = aws_iam_role.github_actions_stg.arn
}

output "github_actions_role_prod_arn" {
  description = "ARN of GitHub Actions role for prod environment"
  value       = aws_iam_role.github_actions_prod.arn
}
