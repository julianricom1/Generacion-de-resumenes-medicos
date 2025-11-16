variable "region"            { type = string }
variable "cluster_name"      { type = string }
variable "log_retention_days" {
  type    = number
  default = 14
}

variable "execution_role_arn" {
  type = string
}
