# Conversión de Modelo LoRA a GGUF

## Requisitos

1. Python 3.10+ con las siguientes librerías:
   ```bash
   pip install transformers peft torch
   ```

2. llama.cpp (para convertir a GGUF):
   ```bash
   git clone https://github.com/ggerganov/llama.cpp
   cd llama.cpp
   pip install -r requirements.txt
   ```

## Uso del Script

### Paso 1: Merge de LoRA con modelo base

```bash
python app/convert_lora_to_gguf.py \
  --lora_dir generacion/ollama/outputs/meta-llama__Llama-3.2-3B-Instruct-6_epocas/final \
  --skip_gguf
```

Esto creará un modelo mergeado en `./merged_model/`

### Paso 2: Convertir a GGUF

Una vez que tengas el modelo mergeado, convierte a GGUF usando llama.cpp:

```bash
python llama.cpp/convert-hf-to-gguf.py \
  ./merged_model \
  --outdir app/models \
  --outtype Q4_K_M
```

Esto generará un archivo `.gguf` en `app/models/`

### Paso 3: Construir Docker

```bash
docker build -t generacion-api:latest ./app
docker run -p 8000:8000 generacion-api:latest
```


