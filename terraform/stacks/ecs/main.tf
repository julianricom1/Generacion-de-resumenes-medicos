terraform {
  required_version = ">= 1.6"
  required_providers { aws = { source = "hashicorp/aws", version = ">= 5.0" } }
}

provider "aws" { region = var.region }

module "ecs" {
  source              = "./../../modules/ecs"
  name                = var.cluster_name
  log_group_retention = var.log_retention_days
  execution_role_arn = var.execution_role_arn

}