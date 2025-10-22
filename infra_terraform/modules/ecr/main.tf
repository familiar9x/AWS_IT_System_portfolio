variable "repos" { type = list(string) }
resource "aws_ecr_repository" "repo" {
  for_each = toset(var.repos)
  name = each.value
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration { scan_on_push = true }
}
output "repo_urls" { value = { for k, v in aws_ecr_repository.repo : k => v.repository_url } }
