data "aws_region" "current" {}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/ecs/${var.name}"
  retention_in_days = var.log_group_retention
}


resource "aws_ecs_cluster" "this" {
  name = var.name
}