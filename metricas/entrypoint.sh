#!/bin/bash
set -e

# Download model checkpoint from S3 if not already present
MODEL_BUCKET="${MODEL_BUCKET:-maia-align-score-model}"
MODEL_KEY="${MODEL_KEY:-AlignScore-base.ckpt}"
MODEL_PATH="/models/${MODEL_KEY}"

if [ ! -f "$MODEL_PATH" ]; then
    echo "Downloading model from s3://${MODEL_BUCKET}/${MODEL_KEY}..."
    if aws s3 cp "s3://${MODEL_BUCKET}/${MODEL_KEY}" "$MODEL_PATH" 2>&1; then
        echo "Model downloaded successfully to ${MODEL_PATH}"
    else
        echo "WARNING: Failed to download model from S3. This may be due to missing IAM permissions."
        echo "The model file should be included in the Docker image or permissions added to LabRole."
        echo "Continuing startup - the service may fail if the model is required..."
    fi
else
    echo "Model already exists at ${MODEL_PATH}, skipping download"
fi

# Start the application
exec uvicorn app:app --host 0.0.0.0 --port ${PORT:-8008}

