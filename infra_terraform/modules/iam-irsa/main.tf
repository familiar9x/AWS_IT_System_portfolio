variable "name" { type = string }
variable "cluster_oidc_provider_arn" { type = string }
variable "service_account_namespace" { type = string }
variable "service_account_name" { type = string }
variable "policy_json" { type = string }

resource "aws_iam_role" "sa" {
  name = var.name
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Federated = var.cluster_oidc_provider_arn },
      Action = "sts:AssumeRoleWithWebIdentity",
      Condition = { StringEquals = { "oidc.eks.amazonaws.com/id/<OIDC_ID>:sub" : "system:serviceaccount:${var.service_account_namespace}:${var.service_account_name}" } }
    }]
  })
}

resource "aws_iam_policy" "inline" {
  name   = "${var.name}-policy"
  policy = var.policy_json
}

resource "aws_iam_role_policy_attachment" "attach" {
  role       = aws_iam_role.sa.name
  policy_arn = aws_iam_policy.inline.arn
}

output "role_arn" { value = aws_iam_role.sa.arn }
