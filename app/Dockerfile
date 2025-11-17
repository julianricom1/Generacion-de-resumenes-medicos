FROM python:3.10-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

# Instalar dependencias del sistema necesarias para compilar llama-cpp-python
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Instalar dependencias Python
COPY requirements.txt /app/
RUN pip install --upgrade pip && pip install -r requirements.txt

# Crear directorio para modelos
RUN mkdir -p /models

# Copiar el modelo GGUF ANTES del COPY . /app (para evitar .dockerignore)
# El modelo debe estar en app/models/*.gguf
COPY --chmod=644 models/*.gguf /models/ 2>/dev/null || true

# Copiar el código
COPY . /app

# Variables de entorno por defecto
ENV MODEL_PATH=/models/llama-3.2-3b-instruct.gguf \
    MAX_NEW_TOKENS=512 \
    TEMPERATURE=0.2 \
    TOP_P=0.9 \
    REPEAT_PENALTY=1.015 \
    N_THREADS=4 \
    N_CTX=4096 \
    PORT=8000

# Copiar entrypoint script
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

EXPOSE 8000
ENTRYPOINT ["/app/entrypoint.sh"]

