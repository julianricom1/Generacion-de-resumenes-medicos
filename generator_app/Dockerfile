FROM python:3.10-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

# Instalar dependencias Python
COPY requirements.txt /app/
# Instalar PyTorch desde el índice de PyTorch para CPU
RUN pip install --upgrade pip --root-user-action=ignore && \
    pip install torch==2.6.0 --index-url https://download.pytorch.org/whl/cpu --root-user-action=ignore && \
    pip install -r requirements.txt --root-user-action=ignore

# Instalar AWS CLI para descargar modelos de S3
RUN apt-get update && apt-get install -y --no-install-recommends \
    awscli \
    && rm -rf /var/lib/apt/lists/*

# Crear directorio para modelos
RUN mkdir -p /models

# ARG para el nombre del modelo
ARG MODEL_NAME

# Copiar el código manteniendo la estructura de directorios
# Copiar todo el contenido a /app/generator_app para que los imports funcionen
COPY . /app/generator_app

# Variables de entorno por defecto
ENV MODEL_PATH=/models \
    MODEL_NAME=${MODEL_NAME} \
    MAX_NEW_TOKENS=512 \
    TEMPERATURE=0.2 \
    TOP_P=0.95 \
    REPEAT_PENALTY=1.015 \
    DEVICE=cpu \
    PORT=8000 \
    MODEL_S3_BUCKET=modelo-generador-maia-g8 \
    TORCH_NUM_THREADS=16 \
    OMP_NUM_THREADS=16 \
    MKL_NUM_THREADS=16 \
    TORCH_COMPILE_DEBUG=0 \
    PYTHONPATH=/app

EXPOSE 8000

# El modelo se descargará de S3 al iniciar el contenedor
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

ENTRYPOINT ["/app/entrypoint.sh"]
# El código está en /app/generator_app, así que los imports from generator_app.* funcionan
# Usar main.py en producción (soporta modelos comerciales + fine-tuned, endpoints en /api/v1/* y /healthz)
# gen_app.py es versión simple solo para modelo local (no soporta comerciales)
CMD ["uvicorn", "generator_app.main:app", "--host", "0.0.0.0", "--port", "8000"]
