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


# NLB para generador (puerto 8000)
module "nlb_generador" {
  source         = "./../../modules/nlb"
  name           = "${var.alb_name}-generador"
  vpc_id         = data.terraform_remote_state.vpc.outputs.vpc_id
  public_subnets = data.terraform_remote_state.vpc.outputs.public_subnets
  target_port    = 8000
  listener_port  = 8000
}

# NLB para métricas (puerto 8001)
module "nlb_metricas" {
  source         = "./../../modules/nlb"
  name           = "${var.alb_name}-metricas"
  vpc_id         = data.terraform_remote_state.vpc.outputs.vpc_id
  public_subnets = data.terraform_remote_state.vpc.outputs.public_subnets
  target_port    = 8001
  listener_port  = 8001
}
