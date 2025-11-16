region         = "us-east-1"
backend_bucket = "infrastructura-maia-g8"

service_name   = "metricas"
image          = "metricas-api:latest"
container_port = 8008
cpu            = 512
memory         = 1024
desired_count  = 1
env_vars = { 
  PORT = "8008"
  TARGETS_FILE = "targets.json"
}

