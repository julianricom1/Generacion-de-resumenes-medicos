# -------- Stage 1: builder --------
FROM python:3.11-slim AS builder
ENV PIP_NO_CACHE_DIR=1 PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
RUN apt-get update && apt-get install -y --no-install-recommends build-essential \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /app

COPY clasificador_app/requirements.txt ./
COPY model-pkg/textclf_svm-0.1.0-py3-none-any.whl ./model-pkg/
RUN python -m venv /opt/venv \
 && /opt/venv/bin/pip install --upgrade pip \
 && /opt/venv/bin/pip install --no-cache-dir -r requirements.txt

# -------- Stage 2: runtime --------
FROM python:3.11-slim AS runtime
ENV PATH="/opt/venv/bin:$PATH" PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
RUN useradd -m appuser
WORKDIR /app
COPY --from=builder /opt/venv /opt/venv
# desde la RAÍZ copiamos el código (clasificador_app se copia como app/ para mantener imports)
COPY clasificador_app/ ./app/
EXPOSE 8002
USER appuser
CMD ["uvicorn","app.main:app","--host","0.0.0.0","--port","8002"]
