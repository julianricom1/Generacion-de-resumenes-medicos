terraform {
  required_version = ">= 1.6"
  required_providers { aws = { source = "hashicorp/aws", version = ">= 5.0" } }
}

provider "aws" { region = var.region }

data "aws_caller_identity" "current" {}

# Estados remotos
data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    bucket = var.backend_bucket
    key    = "vpc/terraform.tfstate"
    region = var.region
  }
}

data "terraform_remote_state" "ecs" {
  backend = "s3"
  config = {
    bucket = var.backend_bucket
    key    = "ecs/terraform.tfstate"
    region = var.region
  }
}

data "terraform_remote_state" "alb" {
  backend = "s3"
  config = {
    bucket = var.backend_bucket
    key    = "alb/terraform.tfstate"
    region = var.region
  }
}

locals {
  account_id   = data.aws_caller_identity.current.account_id
  labrole_arn  = "arn:aws:iam::${local.account_id}:role/LabRole"

  front_image  = "${local.account_id}.dkr.ecr.${var.region}.amazonaws.com/clasificador-front:latest"
  front_port   = 80
}

# TG del FRONT
resource "aws_lb_target_group" "front" {
  name        = "${var.service_name}-tg"
  port        = local.front_port
  protocol    = "HTTP"
  vpc_id      = data.terraform_remote_state.vpc.outputs.vpc_id
  target_type = "ip"

  health_check {
    path                = "/"
    matcher             = "200"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 15
    timeout             = 5
  }
}

# Listener:80 del ALB existente
data "aws_lb_listener" "http80" {
  load_balancer_arn = data.terraform_remote_state.alb.outputs.alb_arn
  port              = 80
}

# Regla API (/api/*) -> TG de la API (ya creado en el stack alb)
resource "aws_lb_listener_rule" "api_rule" {
  listener_arn = data.aws_lb_listener.http80.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = data.terraform_remote_state.alb.outputs.target_group_arn
  }

  condition {
    path_pattern { values = ["/api/*"] }
  }
}

# Regla FRONT (/*) -> TG del FRONT
resource "aws_lb_listener_rule" "front_rule" {
  listener_arn = data.aws_lb_listener.http80.arn
  priority     = 20

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.front.arn
  }

  condition {
    path_pattern { values = ["/*"] }
  }
}

# Servicio ECS (reusa tu módulo app)
module "front" {
  source            = "./../../modules/app"
  name              = var.service_name

  region            = var.region
  vpc_id            = data.terraform_remote_state.vpc.outputs.vpc_id
  subnet_ids        = data.terraform_remote_state.vpc.outputs.private_subnets
  alb_sg_id         = data.terraform_remote_state.alb.outputs.alb_sg_id
  cluster_arn       = data.terraform_remote_state.ecs.outputs.cluster_arn
  execution_role_arn = local.labrole_arn
  log_group_name    = "/ecs/clasificador-logs"

  container_image   = local.front_image
  container_port    = local.front_port
  task_cpu          = var.cpu
  task_memory       = var.memory
  desired_count     = var.desired_count
  target_group_arn  = aws_lb_target_group.front.arn
  env_vars          = var.env_vars
}