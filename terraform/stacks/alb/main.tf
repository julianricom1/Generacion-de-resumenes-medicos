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


module "alb" {
  source         = "./../../modules/alb"
  name           = var.alb_name
  vpc_id         = data.terraform_remote_state.vpc.outputs.vpc_id
  public_subnets = data.terraform_remote_state.vpc.outputs.public_subnets
  target_port    = var.target_port       # 8000
  health_path    = var.health_path       # "/health"
}
