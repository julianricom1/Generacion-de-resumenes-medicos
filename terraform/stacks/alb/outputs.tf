# Outputs para generador (puerto 8000)
output "nlb_generador_arn"          { value = module.nlb_generador.nlb_arn }
output "nlb_generador_dns_name"     { value = module.nlb_generador.nlb_dns_name }
output "nlb_generador_target_group_arn" { value = module.nlb_generador.target_group_arn }
output "nlb_generador_listener_arn"     { value = module.nlb_generador.listener_arn }

# Outputs para métricas (puerto 8001)
output "nlb_metricas_arn"          { value = module.nlb_metricas.nlb_arn }
output "nlb_metricas_dns_name"     { value = module.nlb_metricas.nlb_dns_name }
output "nlb_metricas_target_group_arn" { value = module.nlb_metricas.target_group_arn }
output "nlb_metricas_listener_arn"     { value = module.nlb_metricas.listener_arn }

# Outputs legacy (para compatibilidad)
output "alb_arn"          { value = module.nlb_generador.nlb_arn }
output "alb_dns_name"     { value = module.nlb_generador.nlb_dns_name }
output "alb_sg_id"        { value = "" }  # NLB no usa security groups
output "target_group_arn" { value = module.nlb_metricas.target_group_arn }
output "listener_arn"     { value = module.nlb_generador.listener_arn }
output "dns_name"         { value = module.nlb_generador.dns_name }
output "alb_dns"          { value = module.nlb_generador.dns_name }
