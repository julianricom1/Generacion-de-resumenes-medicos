# app.py
import os
from pathlib import Path
from fastapi import FastAPI
from llama_cpp import Llama
from app.schemas.schemas import SummaryRequest

app = FastAPI(title="Text Generation API", version="0.1.0")

SYSTEM_PROMPT = (
    "You simplify clinical trial protocol text into a plain-language summary for the general public. "
    "Keep to 6–8th grade readability, avoid diagnoses and speculation, no hallucinations, "
    "and preserve key facts (objective, population, interventions, outcomes, timelines, safety)."
)
USER_PREFIX = "Using the following clinical trial protocol text as input, create a plain language summary.\n\n"

# Path al modelo GGUF
MODEL_PATH = os.getenv(
    "MODEL_PATH",
    "/models/llama-3.2-3b-instruct.gguf"
)

# Configuración de generación
MAX_NEW_TOKENS = int(os.getenv("MAX_NEW_TOKENS", "512"))
TEMPERATURE = float(os.getenv("TEMPERATURE", "0.2"))
TOP_P = float(os.getenv("TOP_P", "0.9"))
REPEAT_PENALTY = float(os.getenv("REPEAT_PENALTY", "1.015"))

# Threads para CPU (optimización)
N_THREADS = int(os.getenv("N_THREADS", "4"))
N_CTX = int(os.getenv("N_CTX", "4096"))  # Context window

def load_model(model_path: str):
    """Carga el modelo GGUF usando llama-cpp-python"""
    if not Path(model_path).exists():
        raise FileNotFoundError(f"Modelo no encontrado en: {model_path}")
    
    print(f"Cargando modelo GGUF desde {model_path}...")
    
    # Cargar modelo con optimizaciones para CPU
    model = Llama(
        model_path=model_path,
        n_ctx=N_CTX,
        n_threads=N_THREADS,
        n_gpu_layers=0,  # CPU only
        verbose=False,
        use_mmap=True,  # Memory mapping para modelos grandes
        use_mlock=False,  # No bloquear memoria
    )
    
    print("Modelo cargado exitosamente")
    return model

# Cargar modelo al iniciar
llm = load_model(MODEL_PATH)

def build_prompt(src: str) -> str:
    """Construye el prompt usando el formato de chat de Llama 3.2"""
    # Llama 3.2 format: <|begin_of_text|><|start_header_id|>system<|end_header_id|>\n\n{system}<|eot_id|><|start_header_id|>user<|end_header_id|>\n\n{user}<|eot_id|><|start_header_id|>assistant<|end_header_id|>\n\n
    system_msg = f"<|begin_of_text|><|start_header_id|>system<|end_header_id|>\n\n{SYSTEM_PROMPT}<|eot_id|>"
    user_msg = f"<|start_header_id|>user<|end_header_id|>\n\n{USER_PREFIX}{src}<|eot_id|>"
    assistant_start = "<|start_header_id|>assistant<|end_header_id|>\n\n"
    
    return system_msg + user_msg + assistant_start

#==========================================
# ENDPOINTS
#==========================================

@app.get("/healthz")
def healthz():
    return {
        "status": "ok", 
        "device": "cpu", 
        "model": Path(MODEL_PATH).name,
        "threads": N_THREADS
    }

@app.post("/generate")
def generate_summary(req: SummaryRequest):
    """Genera un resumen usando el modelo GGUF"""
    prompt = build_prompt(req.text)
    
    # Generar con llama-cpp-python
    response = llm(
        prompt,
        max_tokens=MAX_NEW_TOKENS,
        temperature=TEMPERATURE,
        top_p=TOP_P,
        repeat_penalty=REPEAT_PENALTY,
        stop=["<|eot_id|>", "<|end_of_text|>"],  # Stop tokens de Llama 3.2
        echo=False,  # No incluir el prompt en la respuesta
    )
    
    # Extraer el texto generado
    if "choices" in response and len(response["choices"]) > 0:
        summary = response["choices"][0]["text"].strip()
    else:
        # Fallback si la estructura es diferente
        summary = str(response).strip()
    
    return {"summary": summary}
