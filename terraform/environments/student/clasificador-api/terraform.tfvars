region         = "us-east-1"
backend_bucket = "infrastructura-maia-g8"

service_name   = "clasificador-api"
image          = "clasificador-api:latest"
container_port = 8002
cpu            = 2048
memory         = 4096
desired_count  = 1
target_group_arn = "arn:aws:elasticloadbalancing:us-east-1:868544149964:targetgroup/metricas-nlb-clasificador-tg/2a24bafefbf209e7"
alb_sg_id      = ""     # NLB no usa security groups
env_vars = { 
  PORT = "8002"
}

