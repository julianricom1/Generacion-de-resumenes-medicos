region         = "us-east-1"
backend_bucket = "infrastructura-maia-g3"

service_name   = "clasificador-api"
image          = "clasificador-api:latest"
container_port = 8002
cpu            = 2048
memory         = 4096
desired_count  = 1
target_group_arn = "arn:aws:elasticloadbalancing:us-east-1:676326240241:targetgroup/metricas-nlb-clasificador-tg/e5a24a596c842504"
alb_sg_id      = ""     # NLB no usa security groups
env_vars = { 
  PORT = "8002"
}

