output "alb_sg_id"        { value = module.alb.alb_sg_id }
output "target_group_arn" { value = module.alb.target_group_arn }
output "alb_arn"          { value = module.alb.alb_arn }

output "alb_dns" {
  value = module.alb.dns_name
}