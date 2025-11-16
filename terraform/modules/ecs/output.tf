output "cluster_arn"    { value = aws_ecs_cluster.this.arn }
output "exec_role_arn" { value = var.execution_role_arn }
output "log_group_name" { value = aws_cloudwatch_log_group.this.name }
