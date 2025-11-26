terraform {
  required_version = ">= 1.6"
  required_providers { aws = { source = "hashicorp/aws", version = ">= 5.0" } }
}

provider "aws" { region = var.region }

data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    bucket = var.state_bucket
    key = var.vpc_state_key
    region = var.region
  }
}


# Un solo NLB compartido para todos los servicios
# Cada servicio tiene su propio target group y listener en puertos diferentes
resource "aws_lb" "shared_nlb" {
  name               = "${var.alb_name}-shared"
  internal           = false
  load_balancer_type = "network"
  subnets            = data.terraform_remote_state.vpc.outputs.public_subnets

  enable_deletion_protection = false

  tags = {
    Name = "${var.alb_name}-shared"
  }
}

# Target Group para generador (puerto 8000)
resource "aws_lb_target_group" "generador" {
  name        = "${var.alb_name}-generador-tg"
  port        = 8000
  protocol    = "TCP"
  vpc_id      = data.terraform_remote_state.vpc.outputs.vpc_id
  target_type = "ip"

  health_check {
    protocol            = "TCP"
    port                = "traffic-port"
    interval            = 30
    timeout             = 10
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  deregistration_delay = 30

  lifecycle {
    create_before_destroy = true
  }
}

# Target Group para métricas (puerto 8001)
resource "aws_lb_target_group" "metricas" {
  name        = "${var.alb_name}-metricas-tg"
  port        = 8001
  protocol    = "TCP"
  vpc_id      = data.terraform_remote_state.vpc.outputs.vpc_id
  target_type = "ip"

  health_check {
    protocol            = "TCP"
    port                = "traffic-port"
    interval            = 30
    timeout             = 10
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  deregistration_delay = 30

  lifecycle {
    create_before_destroy = true
  }
}

# Target Group para clasificador (puerto 8002)
resource "aws_lb_target_group" "clasificador" {
  name        = "${var.alb_name}-clasificador-tg"
  port        = 8002
  protocol    = "TCP"
  vpc_id      = data.terraform_remote_state.vpc.outputs.vpc_id
  target_type = "ip"

  health_check {
    protocol            = "TCP"
    port                = "traffic-port"
    interval            = 30
    timeout             = 10
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  deregistration_delay = 30

  lifecycle {
    create_before_destroy = true
  }
}

# Listener para generador (puerto 8000)
resource "aws_lb_listener" "generador" {
  load_balancer_arn = aws_lb.shared_nlb.arn
  port              = 8000
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.generador.arn
  }
}

# Listener para métricas (puerto 8001)
resource "aws_lb_listener" "metricas" {
  load_balancer_arn = aws_lb.shared_nlb.arn
  port              = 8001
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.metricas.arn
  }
}

# Listener para clasificador (puerto 8002)
resource "aws_lb_listener" "clasificador" {
  load_balancer_arn = aws_lb.shared_nlb.arn
  port              = 8002
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.clasificador.arn
  }
}