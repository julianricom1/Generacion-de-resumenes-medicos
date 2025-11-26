# Outputs para generador (puerto 8000) - usando NLB compartido
output "nlb_generador_arn"          { value = aws_lb.shared_nlb.arn }
output "nlb_generador_dns_name"     { value = aws_lb.shared_nlb.dns_name }
output "nlb_generador_target_group_arn" { value = aws_lb_target_group.generador.arn }
output "nlb_generador_listener_arn"     { value = aws_lb_listener.generador.arn }

# Outputs para métricas (puerto 8001) - usando NLB compartido
output "nlb_metricas_arn"          { value = aws_lb.shared_nlb.arn }
output "nlb_metricas_dns_name"     { value = aws_lb.shared_nlb.dns_name }
output "nlb_metricas_target_group_arn" { value = aws_lb_target_group.metricas.arn }
output "nlb_metricas_listener_arn"     { value = aws_lb_listener.metricas.arn }

# Outputs para clasificador-api (puerto 8002) - usando NLB compartido
output "nlb_clasificador_arn"          { value = aws_lb.shared_nlb.arn }
output "nlb_clasificador_dns_name"     { value = aws_lb.shared_nlb.dns_name }
output "nlb_clasificador_target_group_arn" { value = aws_lb_target_group.clasificador.arn }
output "nlb_clasificador_listener_arn"     { value = aws_lb_listener.clasificador.arn }

# Outputs legacy (para compatibilidad con web stack que puede necesitar ALB)
output "alb_arn"          { value = aws_lb.shared_nlb.arn }
output "alb_dns_name"     { value = aws_lb.shared_nlb.dns_name }
output "alb_sg_id"        { value = "" }  # NLB no usa security groups
output "target_group_arn" { value = aws_lb_target_group.metricas.arn }
output "listener_arn"     { value = aws_lb_listener.generador.arn }
output "dns_name"         { value = aws_lb.shared_nlb.dns_name }
output "alb_dns"          { value = aws_lb.shared_nlb.dns_name }
