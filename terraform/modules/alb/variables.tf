variable "name"         { type = string }
variable "vpc_id"       { type = string }
variable "public_subnets" { type = list(string) }
variable "target_port" {
  type    = number
  default = 8000
}

variable "health_path" {
  type    = string
  default = "/health"
}
