output "service_name"       { value = module.front.service_name }
output "task_definition_arn"{ value = module.front.task_definition_arn }
output "nlb_dns_name"       { value = data.terraform_remote_state.alb.outputs.nlb_web_dns_name }
