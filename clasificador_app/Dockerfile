# -------- Stage 1: builder --------
FROM python:3.11-slim AS builder
ENV PIP_NO_CACHE_DIR=1 PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
RUN echo ">> [Stage 1] Actualizando paquetes del sistema..." && \
    apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        gfortran \
        libblas-dev \
        liblapack-dev \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app

COPY clasificador_app/requirements.txt ./
COPY model-pkg/textclf_svm-0.1.0-py3-none-any.whl ./model-pkg/
RUN echo ">> [Stage 1] Creando entorno virtual..." && \
    python -m venv /opt/venv && \
    echo ">> [Stage 1] Actualizando pip..." && \
    /opt/venv/bin/pip install --upgrade pip && \
    echo ">> [Stage 1] Instalando dependencias base (numpy, scipy, scikit-learn)..." && \
    echo ">> NOTA: scikit-learn y scipy requieren compilación C/C++, esto puede tardar 5-10 minutos..." && \
    /opt/venv/bin/pip install --no-cache-dir numpy scipy scikit-learn && \
    echo ">> [Stage 1] Instalando resto de dependencias..." && \
    /opt/venv/bin/pip install --no-cache-dir -r requirements.txt && \
    echo ">> [Stage 1] Dependencias instaladas exitosamente"

# -------- Stage 2: runtime --------
FROM python:3.11-slim AS runtime
ENV PATH="/opt/venv/bin:$PATH" PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
RUN echo ">> [Stage 2] Creando usuario de aplicación..." && \
    useradd -m appuser
WORKDIR /app
RUN echo ">> [Stage 2] Copiando entorno virtual desde builder..."
COPY --from=builder /opt/venv /opt/venv
# Copiar el código manteniendo la estructura de módulo (clasificador_app)
RUN echo ">> [Stage 2] Copiando código de la aplicación..."
COPY clasificador_app/ ./clasificador_app/
RUN echo ">> [Stage 2] Build completado. Imagen lista."
EXPOSE 8002
ENV PYTHONPATH=/app
USER appuser
CMD ["uvicorn","clasificador_app.main:app","--host","0.0.0.0","--port","8002"]
