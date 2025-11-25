data "aws_region" "current" {}

resource "aws_ecs_cluster" "this" {
  name = var.name
}