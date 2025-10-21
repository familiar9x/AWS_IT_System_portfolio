variable "repos" { type = list(string) }
variable "tags"  { type = map(string) default = {} }

resource "aws_ecr_repository" "repo" {
  for_each = toset(var.repos)
  name = each.value
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration { scan_on_push = true }
  tags = var.tags
}

output "repo_urls" {
  value = { for k, v in aws_ecr_repository.repo : k => v.repository_url }
}
