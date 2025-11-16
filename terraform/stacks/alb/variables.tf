variable "region"        { type = string }
variable "state_bucket"  { type = string }
variable "vpc_state_key" { type = string }
variable "alb_name"      { type = string }
variable "target_port" {
  type    = number
  default = 8000
}

variable "health_path"   { 
    type = string
    default = "/health" 
}
