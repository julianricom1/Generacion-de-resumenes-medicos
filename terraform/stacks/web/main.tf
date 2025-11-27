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
  front_image  = "${local.account_id}.dkr.ecr.${var.region}.amazonaws.com/web:latest"
  front_port   = 80
}

# Servicio ECS (reusa tu módulo app)
module "front" {
  source            = "./../../modules/app"
  name              = var.service_name

  region            = var.region
  vpc_id            = data.terraform_remote_state.vpc.outputs.vpc_id
  subnet_ids        = data.terraform_remote_state.vpc.outputs.private_subnets
  alb_sg_id         = ""  # NLB no usa security groups
  cluster_arn       = data.terraform_remote_state.ecs.outputs.cluster_arn

  container_image   = local.front_image
  container_port    = local.front_port
  task_cpu          = var.cpu
  task_memory       = var.memory
  desired_count     = var.desired_count
  target_group_arn  = data.terraform_remote_state.alb.outputs.nlb_web_target_group_arn
  env_vars          = var.env_vars
}