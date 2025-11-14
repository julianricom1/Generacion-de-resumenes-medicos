variable "region"         { type = string }
variable "backend_bucket" { type = string }

variable "service_name"   { type = string }
variable "cpu"            { type = number }
variable "memory"         { type = number }
variable "desired_count"  { type = number }

variable "env_vars" {
  type    = map(string)
  default = {}
}
