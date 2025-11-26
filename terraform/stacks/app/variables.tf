variable "region"         { type = string }
variable "backend_bucket" { type = string }

variable "service_name"   { type = string }
variable "image"          { type = string }
variable "container_port" { type = number }
variable "cpu"            { type = number }
variable "memory"         { type = number }
variable "desired_count"  { type = number }
variable "env_vars" {
  type    = map(string)
  default = {}
}
variable "target_group_arn" {
  type    = string
  default = ""
  description = "ARN del target group. Si está vacío, usa el NLB de métricas por defecto."
}
variable "alb_sg_id" {
  type    = string
  default = ""
  description = "Security Group ID del ALB. Si está vacío, se asume NLB (sin security groups)."
}


