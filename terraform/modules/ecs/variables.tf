variable "name"                { type = string }
variable "log_group_retention" {
  type    = number
  default = 14
}

variable "execution_role_arn" {
  type = string
}
