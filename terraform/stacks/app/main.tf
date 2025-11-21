terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
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
  # var.image debe venir como "repo:tag" (p.ej. "metricas-api:latest")
  container_image  = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com/metricas-api:latest"
  container_port   = var.container_port
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
  target_group_arn = data.terraform_remote_state.alb.outputs.target_group_arn
  env_vars         = var.env_vars
}

