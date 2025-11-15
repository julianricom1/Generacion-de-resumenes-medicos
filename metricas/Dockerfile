FROM python:3.10-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

# instalar AlignScore desde GitHub
RUN apt-get update && apt-get install -y --no-install-recommends \
    git build-essential curl && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Instalar deps
COPY requirements.txt /app/
RUN pip install --upgrade pip && pip install -r requirements.txt

# Copiar el modelo ANTES del COPY . /app (para evitar .dockerignore)
RUN mkdir -p /models
# Usar COPY con --from para evitar .dockerignore, o copiar directamente
COPY --chmod=644 models/AlignScore-base.ckpt /models/AlignScore-base.ckpt

# Copiar el código
COPY . /app

# Defaults 
ENV ALIGNSCORE_MODEL=roberta-base \
    ALIGNSCORE_CKPT=/models/AlignScore-base.ckpt \
    ALIGNSCORE_EVAL_MODE=nli_sp \
    ALIGNSCORE_BATCH=4 \
    TORCH_NUM_THREADS=4 \
    BERTSCORE_MODEL=roberta-large \
    TARGETS_FILE=targets.json \
    PORT=8008

# Copy entrypoint script
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

EXPOSE 8008
ENTRYPOINT ["/app/entrypoint.sh"]
