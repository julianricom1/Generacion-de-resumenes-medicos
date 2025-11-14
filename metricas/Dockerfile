FROM python:3.10-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

# instalar AlignScore desde GitHub y AWS CLI para descargar modelos
RUN apt-get update && apt-get install -y --no-install-recommends \
    git build-essential curl unzip && \
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install && \
    rm -rf awscliv2.zip aws /var/lib/apt/lists/*

WORKDIR /app

# Instalar deps
COPY requirements.txt /app/
RUN pip install --upgrade pip && pip install -r requirements.txt

# Copiar el código
COPY . /app

# Defaults 
ENV ALIGNSCORE_MODEL=roberta-base \
    ALIGNSCORE_CKPT=/models/AlignScore-base.ckpt \
    ALIGNSCORE_EVAL_MODE=nli_sp \
    ALIGNSCORE_BATCH=8 \
    BERTSCORE_MODEL=roberta-large \
    TARGETS_FILE=targets.json \
    PORT=8008

# Path donde montar el .ckpt
RUN mkdir -p /models

# Copy entrypoint script
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

EXPOSE 8008
ENTRYPOINT ["/app/entrypoint.sh"]
