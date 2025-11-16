output "service_name"       { value = module.front.service_name }
output "task_definition_arn"{ value = module.front.task_definition_arn }
output "front_tg_arn"       { value = aws_lb_target_group.front.arn }
