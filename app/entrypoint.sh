#!/bin/bash
set -e

MODEL_S3_BUCKET="${MODEL_S3_BUCKET:-modelo-generador-maia-g8}"
MODEL_S3_KEY="merged-models/${MODEL_NAME}"

if [ -z "$MODEL_NAME" ]; then
    echo "ERROR: MODEL_NAME no está definido"
    exit 1
fi

MODEL_LOCAL_PATH="/models/${MODEL_NAME}"

echo "Verificando si el modelo ya está descargado en ${MODEL_LOCAL_PATH}..."
if [ -f "${MODEL_LOCAL_PATH}/config.json" ]; then
    echo "Modelo ya está descargado, saltando descarga desde S3"
else
    echo "Descargando modelo desde S3: s3://${MODEL_S3_BUCKET}/${MODEL_S3_KEY}/"
    
    mkdir -p "${MODEL_LOCAL_PATH}"
    
    if command -v aws &> /dev/null; then
        aws s3 sync "s3://${MODEL_S3_BUCKET}/${MODEL_S3_KEY}/" "${MODEL_LOCAL_PATH}/" --no-progress || {
            echo "ERROR: No se pudo descargar el modelo desde S3"
            echo "Verifica que:"
            echo "  1. El modelo esté en s3://${MODEL_S3_BUCKET}/${MODEL_S3_KEY}/"
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

echo "Iniciando aplicación..."
exec "$@"

