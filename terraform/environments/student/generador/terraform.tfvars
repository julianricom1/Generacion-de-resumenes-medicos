region         = "us-east-1"
backend_bucket = "infrastructura-maia-g8"

service_name   = "generador"
image          = "generador-api:latest"
container_port = 8000
cpu            = 16384
memory         = 122880
desired_count  = 1
env_vars = { 
  PORT = "8000"
  MODEL_NAME = "meta-llama__Llama-3.2-3B-Instruct-6_epocas"
  DEVICE = "cpu"
  MAX_NEW_TOKENS = "512"
  TEMPERATURE = "0.2"
  TOP_P = "0.9"
  REPEAT_PENALTY = "1.015"
}

