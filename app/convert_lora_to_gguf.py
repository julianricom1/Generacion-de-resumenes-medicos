#!/usr/bin/env python3
"""
Script para convertir un modelo LoRA a formato GGUF optimizado para CPU.

Proceso:
1. Mergea el LoRA con el modelo base (usando PEFT)
2. Convierte el modelo mergeado a GGUF usando llama.cpp

Uso:
    python app/convert_lora_to_gguf.py --lora_dir generacion/ollama/outputs/meta-llama__Llama-3.2-3B-Instruct-6_epocas/final --output_gguf app/models/llama-3.2-3b-instruct.gguf
"""

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path

def merge_lora_with_base(lora_dir: str, output_dir: str):
    """Mergea el LoRA con el modelo base usando PEFT"""
    print(f"Mergeando LoRA desde {lora_dir}...")
    
    try:
        from peft import PeftModel
        from transformers import AutoModelForCausalLM, AutoTokenizer
        import torch
    except ImportError:
        print("ERROR: Se requieren transformers y peft. Instala con:")
        print("  pip install transformers peft torch")
        sys.exit(1)
    
    lora_path = Path(lora_dir)
    cfg_path = lora_path / "adapter_config.json"
    
    if not cfg_path.exists():
        raise FileNotFoundError(f"No se encontró adapter_config.json en {lora_dir}")
    
    adapter_cfg = json.loads(cfg_path.read_text(encoding="utf-8"))
    base_model_name = adapter_cfg.get("base_model_name_or_path")
    
    if not base_model_name:
        raise ValueError("adapter_config.json no contiene 'base_model_name_or_path'")
    
    print(f"   Modelo base: {base_model_name}")
    
    # Cargar modelo base
    print("   Cargando modelo base desde HuggingFace...")
    base_model = AutoModelForCausalLM.from_pretrained(
        base_model_name,
        torch_dtype=torch.float16,
        trust_remote_code=True,
        device_map="auto" if torch.cuda.is_available() else None,
    )
    
    # Cargar tokenizer
    print("   Cargando tokenizer...")
    tokenizer = AutoTokenizer.from_pretrained(str(lora_path), use_fast=True, trust_remote_code=True)
    if tokenizer.pad_token is None:
        tokenizer.pad_token = tokenizer.eos_token
    
    # Cargar y mergear LoRA
    print("   Cargando LoRA...")
    model = PeftModel.from_pretrained(base_model, str(lora_path))
    
    print("   Mergeando LoRA con modelo base (esto puede tardar)...")
    merged_model = model.merge_and_unload()
    
    # Guardar modelo mergeado
    output_path = Path(output_dir)
    output_path.mkdir(parents=True, exist_ok=True)
    
    print(f"   Guardando modelo mergeado en {output_path}...")
    merged_model.save_pretrained(
        str(output_path),
        safe_serialization=True,
        max_shard_size="5GB"
    )
    tokenizer.save_pretrained(str(output_path))
    
    print("Modelo mergeado guardado exitosamente")
    return str(output_path)

def convert_to_gguf(hf_model_dir: str, output_gguf: str, quantization: str = "Q4_K_M"):
    """
    Convierte un modelo HuggingFace a GGUF usando llama.cpp
    
    quantization: Q4_K_M (recomendado para CPU), Q5_K_M, Q8_0, F16, etc.
    """
    print(f"\nConvirtiendo {hf_model_dir} a GGUF...")
    
    # Verificar si llama.cpp convert-hf-to-gguf.py está disponible
    # Primero intentar con llama-cpp-python
    try:
        import llama_cpp
        print("   Usando llama-cpp-python para conversión...")
        # llama-cpp-python no tiene conversión directa, necesitamos llama.cpp
        print("   WARNING: llama-cpp-python no incluye el script de conversión")
        print("   Necesitas instalar llama.cpp manualmente")
    except ImportError:
        pass
    
    # Intentar usar llama.cpp directamente si está disponible
    llama_cpp_path = Path("llama.cpp")
    convert_script = llama_cpp_path / "convert-hf-to-gguf.py"
    
    if convert_script.exists():
        print(f"   Usando llama.cpp local: {convert_script}")
        cmd = [
            "python", str(convert_script),
            str(hf_model_dir),
            "--outdir", str(Path(output_gguf).parent),
            "--outtype", quantization
        ]
    else:
        print("   WARNING: llama.cpp no encontrado localmente")
        print("\n   Para convertir el modelo, necesitas:")
        print("   1. Clonar llama.cpp: git clone https://github.com/ggerganov/llama.cpp")
        print("   2. Instalar dependencias: pip install -r llama.cpp/requirements.txt")
        print("   3. Ejecutar manualmente:")
        print(f"      python llama.cpp/convert-hf-to-gguf.py {hf_model_dir} --outdir {Path(output_gguf).parent} --outtype {quantization}")
        print(f"\n   O usar el modelo mergeado directamente y convertir después")
        return False
    
    print(f"   Ejecutando: {' '.join(cmd)}")
    result = subprocess.run(cmd, check=False)
    
    if result.returncode == 0:
        # El script genera un archivo con nombre basado en el directorio
        # Buscar el archivo GGUF generado
        output_dir = Path(output_gguf).parent
        gguf_files = list(output_dir.glob("*.gguf"))
        if gguf_files:
            generated_file = gguf_files[0]
            if generated_file.name != Path(output_gguf).name:
                # Renombrar al nombre deseado
                generated_file.rename(output_gguf)
            print(f"Modelo convertido a {output_gguf}")
            return True
        else:
            print("WARNING: Conversión completada pero no se encontró el archivo GGUF")
            return False
    else:
        print("ERROR en la conversión")
        return False

def main():
    parser = argparse.ArgumentParser(
        description="Convertir modelo LoRA a GGUF para inferencia CPU optimizada",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Ejemplos:
  # Convertir modelo completo
  python app/convert_lora_to_gguf.py \\
    --lora_dir generacion/ollama/outputs/meta-llama__Llama-3.2-3B-Instruct-6_epocas/final \\
    --output_gguf app/models/llama-3.2-3b-instruct.gguf

  # Solo mergear (sin convertir a GGUF)
  python app/convert_lora_to_gguf.py \\
    --lora_dir generacion/ollama/outputs/meta-llama__Llama-3.2-3B-Instruct-6_epocas/final \\
    --skip_gguf
        """
    )
    parser.add_argument("--lora_dir", required=True, 
                       help="Directorio del LoRA (debe contener adapter_config.json)")
    parser.add_argument("--merged_dir", default="./merged_model", 
                       help="Directorio temporal para modelo mergeado")
    parser.add_argument("--output_gguf", 
                       help="Ruta del archivo GGUF de salida (ej: app/models/modelo.gguf)")
    parser.add_argument("--quantization", default="Q4_K_M", 
                       choices=["F16", "Q8_0", "Q5_K_M", "Q4_K_M", "Q4_0"],
                       help="Tipo de cuantización (Q4_K_M recomendado para CPU)")
    parser.add_argument("--skip_merge", action="store_true", 
                       help="Omitir merge (asume modelo ya mergeado en --merged_dir)")
    parser.add_argument("--skip_gguf", action="store_true",
                       help="Solo mergear, no convertir a GGUF")
    
    args = parser.parse_args()
    
    # Paso 1: Mergear LoRA
    if not args.skip_merge:
        merged_dir = merge_lora_with_base(args.lora_dir, args.merged_dir)
    else:
        merged_dir = args.merged_dir
        if not Path(merged_dir).exists():
            print(f"ERROR: {merged_dir} no existe")
            sys.exit(1)
    
    # Paso 2: Convertir a GGUF
    if not args.skip_gguf:
        if not args.output_gguf:
            # Generar nombre automático
            model_name = Path(args.lora_dir).parent.name
            output_dir = Path("app/models")
            output_dir.mkdir(parents=True, exist_ok=True)
            args.output_gguf = str(output_dir / f"{model_name}.gguf")
        
        success = convert_to_gguf(merged_dir, args.output_gguf, args.quantization)
        
        if success:
            print(f"\nConversión completada!")
            print(f"   Modelo GGUF: {args.output_gguf}")
            print(f"   Cuantización: {args.quantization}")
            print(f"\n   El modelo está listo para usar en Docker")
        else:
            print(f"\nWARNING: Merge completado pero conversión a GGUF requiere llama.cpp")
            print(f"   Modelo mergeado en: {merged_dir}")
            print(f"   Convierte manualmente usando llama.cpp")
    else:
        print(f"\nMerge completado (conversión a GGUF omitida)")
        print(f"   Modelo mergeado en: {merged_dir}")

if __name__ == "__main__":
    main()

