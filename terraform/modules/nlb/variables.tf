variable "name" {
  type        = string
  description = "Name of the Network Load Balancer"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID where the NLB will be deployed"
}

variable "public_subnets" {
  type        = list(string)
  description = "List of public subnet IDs for the NLB"
}

variable "target_port" {
  type        = number
  description = "Port on which targets receive traffic"
  default     = 8000
}

variable "listener_port" {
  type        = number
  description = "Port on which the load balancer is listening"
  default     = 80
}

