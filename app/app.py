import os
import sys
import multiprocessing
from pathlib import Path
from typing import Optional

import torch
from fastapi import FastAPI
from transformers import AutoModelForCausalLM, AutoTokenizer
from peft import PeftModel

# Optimizaciones de PyTorch para CPU
# Usar todos los cores disponibles
num_threads = int(os.getenv("TORCH_NUM_THREADS", multiprocessing.cpu_count()))
torch.set_num_threads(num_threads)
torch.set_num_interop_threads(num_threads)
# Deshabilitar cuDNN (no se usa en CPU)
torch.backends.cudnn.enabled = False

# Asegurar que el path local esté en sys.path para imports relativos
sys.path.insert(0, str(Path(__file__).parent))

from schemas.schemas import SummaryRequest

app = FastAPI(title="Generación de Resúmenes Médicos")

# Variables de entorno
MODEL_PATH = os.getenv("MODEL_PATH", "/models")
MODEL_NAME = os.getenv("MODEL_NAME", "")
DEVICE = os.getenv("DEVICE", "cpu")
MAX_NEW_TOKENS = int(os.getenv("MAX_NEW_TOKENS", "512"))
TEMPERATURE = float(os.getenv("TEMPERATURE", "0.2"))
TOP_P = float(os.getenv("TOP_P", "0.95"))
REPEAT_PENALTY = float(os.getenv("REPEAT_PENALTY", "1.015"))

# Variables globales para el modelo y tokenizer
model = None
tokenizer = None

def find_model_path():
    """Encuentra la ruta del modelo mergeado"""
    if MODEL_NAME:
        model_path = Path(MODEL_PATH) / MODEL_NAME
        if model_path.exists():
            return str(model_path)
    
    # Si no se especifica MODEL_NAME, buscar el primer subdirectorio en MODEL_PATH
    model_base = Path(MODEL_PATH)
    if model_base.exists():
        subdirs = [d for d in model_base.iterdir() if d.is_dir()]
        if subdirs:
            return str(subdirs[0])
    
    raise FileNotFoundError(f"No se encontró el modelo en {MODEL_PATH}")

def load_model_and_tokenizer():
    """Carga el modelo mergeado y el tokenizer"""
    global model, tokenizer
    
    model_path = find_model_path()
    print(f"Cargando modelo desde: {model_path}")
    
    # Cargar tokenizer
    tokenizer = AutoTokenizer.from_pretrained(model_path)
    
    # Cargar modelo base
    print("Cargando modelo base (esto puede tardar varios minutos)...")
    base_model = AutoModelForCausalLM.from_pretrained(
        model_path,
        torch_dtype=torch.float32,
        device_map="cpu",
        low_cpu_mem_usage=True
    )
    
    # El modelo ya está mergeado, así que no necesitamos aplicar LoRA
    model = base_model
    model.eval()
    
    # Aplicar cuantización INT8 dinámica para acelerar la inferencia
    print("Aplicando cuantización INT8 dinámica...")
    from torch.quantization import quantize_dynamic
    # Cuantizar solo las capas lineales (más efectivo)
    model = quantize_dynamic(
        model,
        {torch.nn.Linear},  # Solo cuantizar capas lineales
        dtype=torch.qint8
    )
    print("Cuantización INT8 aplicada exitosamente")
    
    print(f"Modelo cargado exitosamente en {DEVICE}")
    return model, tokenizer

def build_prompt(text: str) -> str:
    """Construye el prompt para el modelo"""
    messages = [
        {"role": "system", "content": "Eres un asistente médico especializado en generar resúmenes concisos y precisos de textos médicos."},
        {"role": "user", "content": f"Resume el siguiente texto médico de manera concisa y precisa:\n\n{text}"}
    ]
    return tokenizer.apply_chat_template(messages, tokenize=False, add_generation_prompt=True)

@app.on_event("startup")
async def startup_event():
    """Carga el modelo al iniciar la aplicación"""
    global model, tokenizer
    try:
        model, tokenizer = load_model_and_tokenizer()
    except Exception as e:
        print(f"ERROR al cargar el modelo: {e}")
        import traceback
        traceback.print_exc()
        raise

@app.get("/healthz")
async def healthz():
    """Health check endpoint"""
    try:
        model_path = find_model_path()
    except:
        model_path = str(Path(MODEL_PATH) / MODEL_NAME) if MODEL_NAME else str(Path(MODEL_PATH))
    return {
        "status": "healthy" if model is not None else "unhealthy",
        "device": DEVICE,
        "model_path": model_path,
        "model_loaded": model is not None
    }

@app.post("/generate")
async def generate(request: SummaryRequest):
    """Genera un resumen del texto de entrada"""
    if model is None or tokenizer is None:
        raise RuntimeError("Modelo no cargado")
    
    # Construir prompt
    prompt = build_prompt(request.text)
    
    # Tokenizar
    inputs = tokenizer(prompt, return_tensors="pt").to(DEVICE)
    
    # Generar con optimizaciones
    # Usar inference_mode (más rápido que no_grad)
    with torch.inference_mode():
        outputs = model.generate(
            **inputs,
            max_new_tokens=MAX_NEW_TOKENS,
            temperature=TEMPERATURE,
            top_p=TOP_P,
            repetition_penalty=REPEAT_PENALTY,
            do_sample=True,
            pad_token_id=tokenizer.eos_token_id
        )
    
    # Decodificar
    generated_text = tokenizer.decode(outputs[0], skip_special_tokens=True)
    
    # Extraer solo la respuesta generada (sin el prompt)
    if "assistant" in generated_text.lower():
        parts = generated_text.split("assistant", 1)
        if len(parts) > 1:
            generated_text = parts[-1].strip()
    
    return {"summary": generated_text}

