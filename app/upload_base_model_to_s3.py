#!/usr/bin/env python3
"""
Script para subir el modelo base a S3 para acelerar builds futuros.

Uso:
    python app/upload_base_model_to_s3.py <modelo_base> [bucket] [key_prefix]

Ejemplo:
    python app/upload_base_model_to_s3.py meta-llama/Llama-3.2-3B-Instruct

El modelo se subirá a s3://modelo-generador-maia-g8/base-models/meta-llama--Llama-3.2-3B-Instruct/
"""

import sys
import os
from pathlib import Path

try:
    import boto3
    from transformers import AutoModelForCausalLM, AutoTokenizer
    from huggingface_hub import login
except ImportError as e:
    print(f"ERROR: Faltan dependencias: {e}")
    print("Instala con: pip install boto3 transformers huggingface-hub")
    sys.exit(1)

def upload_model_to_s3(model_name: str, bucket: str = "modelo-generador-maia-g8", key_prefix: str = None):
    """Descarga el modelo desde Hugging Face y lo sube a S3"""
    if key_prefix is None:
        key_prefix = f"base-models/{model_name.replace('/', '--')}"
    
    print(f"Descargando modelo {model_name} desde Hugging Face...")
    
    # Autenticarse con Hugging Face si hay token
    hf_token = os.environ.get("HF_TOKEN") or os.environ.get("HUGGING_FACE_HUB_TOKEN")
    if hf_token:
        print("Autenticándose con Hugging Face...")
        login(token=hf_token, add_to_git_credential=False)
    
    # Descargar modelo a un directorio temporal
    import tempfile
    with tempfile.TemporaryDirectory() as tmpdir:
        print(f"Descargando modelo a {tmpdir}...")
        model_path = Path(tmpdir) / "model"
        tokenizer = AutoTokenizer.from_pretrained(model_name)
        model = AutoModelForCausalLM.from_pretrained(
            model_name,
            torch_dtype="float16",
            low_cpu_mem_usage=True,
        )
        
        print(f"Guardando modelo en {model_path}...")
        model.save_pretrained(str(model_path))
        tokenizer.save_pretrained(str(model_path))
        
        # Subir a S3
        print(f"Subiendo modelo a s3://{bucket}/{key_prefix}/...")
        s3_client = boto3.client('s3', region_name=os.environ.get('AWS_REGION', 'us-east-1'))
        
        for file_path in model_path.rglob('*'):
            if file_path.is_file():
                relative_path = file_path.relative_to(model_path)
                s3_key = f"{key_prefix}/{relative_path}".replace('\\', '/')
                print(f"  Subiendo {relative_path} -> {s3_key}")
                s3_client.upload_file(str(file_path), bucket, s3_key)
        
        print(f"Modelo subido exitosamente a s3://{bucket}/{key_prefix}/")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    
    model_name = sys.argv[1]
    bucket = sys.argv[2] if len(sys.argv) > 2 else "modelo-generador-maia-g8"
    key_prefix = sys.argv[3] if len(sys.argv) > 3 else None
    
    upload_model_to_s3(model_name, bucket, key_prefix)

