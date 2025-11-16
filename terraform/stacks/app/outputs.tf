output "service_name" {
  value = module.app.service_name
}

output "task_definition_arn" {
  value = module.app.task_definition_arn
}

output "app_sg_id" {
  value = module.app.app_sg_id
}
