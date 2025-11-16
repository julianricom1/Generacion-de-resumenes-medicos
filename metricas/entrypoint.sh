#!/bin/bash
set -e

# Verificar que el modelo existe (debe estar incluido en la imagen)
MODEL_PATH="/models/AlignScore-base.ckpt"

if [ ! -f "$MODEL_PATH" ]; then
    echo "ERROR: Model file not found at ${MODEL_PATH}"
    echo "The model should be included in the Docker image."
    exit 1
else
    echo "Model found at ${MODEL_PATH} (included in image)"
fi

# Start the application
exec uvicorn app:app --host 0.0.0.0 --port ${PORT:-8008}

