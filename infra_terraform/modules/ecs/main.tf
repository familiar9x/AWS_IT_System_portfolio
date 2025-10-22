variable "name" { type = string }
resource "aws_ecs_cluster" "this" { name = var.name }

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals { type = "Service", identifiers = ["ecs-tasks.amazonaws.com"] }
  }
}

resource "aws_iam_role" "exec" {
  name               = "${var.name}-task-exec"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}
resource "aws_iam_role_policy_attachment" "exec" {
  role       = aws_iam_role.exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "task" {
  name               = "${var.name}-task-role"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

output "cluster_arn"        { value = aws_ecs_cluster.this.arn }
output "cluster_name"       { value = aws_ecs_cluster.this.name }
output "task_exec_role_arn" { value = aws_iam_role.exec.arn }
output "task_role_arn"      { value = aws_iam_role.task.arn }
