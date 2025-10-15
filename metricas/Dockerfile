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

EXPOSE 8008
CMD ["bash", "-lc", "uvicorn app:app --host 0.0.0.0 --port ${PORT}"]
