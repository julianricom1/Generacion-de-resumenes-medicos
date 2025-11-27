#!/bin/bash
set -e

MODEL_S3_BUCKET="${MODEL_S3_BUCKET:-modelo-factualidad-g3}"
MODEL_S3_KEY="AlignScore-base.ckpt"
MODEL_LOCAL_PATH="/models/AlignScore-base.ckpt"

echo "Verificando si el modelo ya está descargado en ${MODEL_LOCAL_PATH}..."
if [ -f "${MODEL_LOCAL_PATH}" ]; then
    echo "Modelo ya está descargado, saltando descarga desde S3"
else
    echo "Descargando modelo desde S3: s3://${MODEL_S3_BUCKET}/${MODEL_S3_KEY}"
    
    mkdir -p /models
    
    if command -v aws &> /dev/null; then
        aws s3 cp "s3://${MODEL_S3_BUCKET}/${MODEL_S3_KEY}" "${MODEL_LOCAL_PATH}" --no-progress || {
            echo "ERROR: No se pudo descargar el modelo desde S3"
            echo "Verifica que:"
            echo "  1. El modelo esté en s3://${MODEL_S3_BUCKET}/${MODEL_S3_KEY}"
            echo "  2. Las credenciales AWS estén configuradas"
            echo "  3. El contenedor tenga permisos para acceder a S3"
            exit 1
        }
        echo "Modelo descargado exitosamente desde S3"
    else
        echo "ERROR: AWS CLI no está disponible en el contenedor"
        echo "El modelo debe estar pre-descargado o AWS CLI debe estar instalado"
        exit 1
    fi
fi

# Start the application
echo "Iniciando aplicación..."
exec uvicorn app:app --host 0.0.0.0 --port ${PORT:-8008}

