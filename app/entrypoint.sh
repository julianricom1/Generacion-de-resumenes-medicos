#!/bin/bash
set -e

# Verificar que el modelo existe
if [ ! -f "${MODEL_PATH}" ]; then
    echo "ERROR: Modelo no encontrado en ${MODEL_PATH}"
    echo "Por favor, asegúrate de que el modelo GGUF esté en el directorio /models/"
    echo "Archivos disponibles en /models/:"
    ls -lh /models/ || echo "  (directorio vacío o no existe)"
    exit 1
fi

echo "=========================================="
echo "Iniciando servidor FastAPI de generación"
echo "=========================================="
echo "Modelo: ${MODEL_PATH}"
echo "Puerto: ${PORT}"
echo "Threads: ${N_THREADS}"
echo "Context Window: ${N_CTX}"
echo "=========================================="

# Iniciar uvicorn
exec uvicorn app:app --host 0.0.0.0 --port ${PORT}

