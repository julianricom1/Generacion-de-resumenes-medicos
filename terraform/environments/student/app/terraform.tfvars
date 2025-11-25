region         = "us-east-1"
backend_bucket = "infrastructura-maia-g8"

service_name   = "metricas"
image          = "metricas-api:latest"
container_port = 8001
cpu            = 4096
memory         = 16384
desired_count  = 1
env_vars = { 
  PORT = "8001"
  TARGETS_FILE = "targets.json"
}

