terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
  backend "s3" {
    # Configurado via -backend-config
  }
}

provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}

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
  account_id      = data.aws_caller_identity.current.account_id
  container_image = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com/app-api:latest"
  container_port   = var.container_port
}

# Crear target group adicional para el generador
resource "aws_lb_target_group" "generador" {
  name        = "generador-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = data.terraform_remote_state.vpc.outputs.vpc_id
  target_type = "ip"

  health_check {
    path                = "/generador/healthz"
    matcher             = "200-399"
    interval            = 60
    timeout             = 30
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
  
  deregistration_delay = 60
  
  # Nota: El timeout de request en ALB es de 60 segundos por defecto y no se puede cambiar
  # Para requests más largas, considera usar un patrón asíncrono o aumentar el timeout del cliente
}

# Obtener el listener del ALB - usar remote state si está disponible, sino data source
data "aws_lb" "main" {
  name = "metricas-alb"
}

# Buscar el listener HTTP en el puerto 80
data "aws_lb_listener" "http" {
  load_balancer_arn = data.aws_lb.main.arn
  port              = 80
}

locals {
  # Intentar usar listener_arn del remote state primero, luego data source
  listener_arn = try(
    data.terraform_remote_state.alb.outputs.listener_arn,
    data.aws_lb_listener.http.arn
  )
}

# Crear listener rule para routing basado en path
resource "aws_lb_listener_rule" "generador" {
  listener_arn = local.listener_arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.generador.arn
  }

  condition {
    path_pattern {
      values = ["/generador/*"]
    }
  }
}

module "app" {
  source  = "./../../modules/app"
  name    = var.service_name

  region           = var.region          
  vpc_id           = data.terraform_remote_state.vpc.outputs.vpc_id
  subnet_ids       = data.terraform_remote_state.vpc.outputs.private_subnets
  alb_sg_id        = data.terraform_remote_state.alb.outputs.alb_sg_id
  cluster_arn      = data.terraform_remote_state.ecs.outputs.cluster_arn

  container_image  = local.container_image
  container_port   = var.container_port
  task_cpu         = var.cpu
  task_memory      = var.memory
  desired_count    = var.desired_count
  target_group_arn = aws_lb_target_group.generador.arn
  env_vars         = var.env_vars
}

