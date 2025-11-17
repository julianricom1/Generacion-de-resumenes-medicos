#!/usr/bin/env python3
"""
Script simple para mergear un LoRA con el modelo base.
Este es el primer paso antes de convertir a GGUF.
"""

import sys
from pathlib import Path

# Agregar el directorio raíz al path para importar
sys.path.insert(0, str(Path(__file__).parent.parent))

from peft import PeftModel
from transformers import AutoModelForCausalLM, AutoTokenizer
import torch

def merge_lora(lora_dir: str, output_dir: str = "./merged_model"):
    """Mergea un LoRA con su modelo base"""
    print(f"Mergeando LoRA desde: {lora_dir}")
    
    lora_path = Path(lora_dir)
    if not (lora_path / "adapter_config.json").exists():
        print(f"ERROR: No se encontró adapter_config.json en {lora_dir}")
        return False
    
    # Leer configuración
    import json
    with open(lora_path / "adapter_config.json") as f:
        config = json.load(f)
    
    base_model_name = config.get("base_model_name_or_path")
    print(f"Modelo base: {base_model_name}")
    
    # Cargar modelo base
    print("Cargando modelo base (esto puede tardar y requiere descargar ~6GB)...")
    try:
        base_model = AutoModelForCausalLM.from_pretrained(
            base_model_name,
            torch_dtype=torch.float16 if torch.cuda.is_available() else torch.float32,
            device_map="auto" if torch.cuda.is_available() else None,
            trust_remote_code=True,
        )
    except Exception as e:
        print(f"ERROR cargando modelo base: {e}")
        print("   Asegúrate de tener acceso a HuggingFace y espacio suficiente (~6GB)")
        return False
    
    # Cargar tokenizer
    print("Cargando tokenizer...")
    tokenizer = AutoTokenizer.from_pretrained(str(lora_path), use_fast=True, trust_remote_code=True)
    if tokenizer.pad_token is None:
        tokenizer.pad_token = tokenizer.eos_token
    
    # Cargar LoRA
    print("Cargando LoRA...")
    try:
        model = PeftModel.from_pretrained(base_model, str(lora_path))
    except Exception as e:
        print(f"ERROR cargando LoRA: {e}")
        return False
    
    # Mergear
    print("Mergeando LoRA con modelo base (esto puede tardar varios minutos)...")
    try:
        merged_model = model.merge_and_unload()
    except Exception as e:
        print(f"ERROR mergeando: {e}")
        return False
    
    # Guardar
    output_path = Path(output_dir)
    output_path.mkdir(parents=True, exist_ok=True)
    
    print(f"Guardando modelo mergeado en {output_path}...")
    try:
        merged_model.save_pretrained(
            str(output_path),
            safe_serialization=True,
            max_shard_size="5GB"
        )
        tokenizer.save_pretrained(str(output_path))
        print("Modelo mergeado guardado exitosamente!")
        print(f"   Ubicación: {output_path.absolute()}")
        print(f"\n   Próximo paso: Convertir a GGUF usando llama.cpp")
        return True
    except Exception as e:
        print(f"ERROR guardando: {e}")
        return False

if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description="Mergear LoRA con modelo base")
    parser.add_argument(
        "--lora_dir",
        default="generacion/ollama/outputs/meta-llama__Llama-3.2-3B-Instruct-6_epocas/final",
        help="Directorio del LoRA (debe contener adapter_config.json)"
    )
    parser.add_argument(
        "--output_dir",
        default="./merged_model",
        help="Directorio de salida para el modelo mergeado"
    )
    
    args = parser.parse_args()
    
    success = merge_lora(args.lora_dir, args.output_dir)
    sys.exit(0 if success else 1)

