# app.py
import os
import json
import numpy as np
import pandas as pd
from pathlib import Path
from fastapi import FastAPI, HTTPException
from schemas.schemas import SummaryRequest
from transformers import AutoTokenizer, AutoModelForCausalLM

DEVICE = "cuda" if torch.cuda.is_available() else "cpu"

# =========================
# SETUP
# =========================

# Prompts (usa los mismos que en entrenamiento)
SYSTEM_PROMPT = (
    "You simplify clinical trial protocol text into a plain-language summary for the general public. "
    "Keep to 6–8th grade readability, avoid diagnoses and speculation, no hallucinations, "
    "and preserve key facts (objective, population, interventions, outcomes, timelines, safety)."
)
USER_PREFIX = "Using the following clinical trial protocol text as input, create a plain language summary.\n\n"

MODEL_DIR = os.getenv("MODEL_DIR","ollama/outputs/meta-llama__Llama-3.2-3B-Instruct-lora-fp16/final")

# generación 
GEN_CFG = dict(
    max_new_tokens= int(os.getenv("MAX_NEW_TOKENS", "512")),
    do_sample=True,
    temperature=int(os.getenv("TEMPERATURE", "0.2")),
    top_p=0.9,
    no_repeat_ngram_size=0,
    repetition_penalty=1.015,
)

def load_model_and_tokenizer(model_dir: str, device: str = DEVICE):
    model_dir = str(Path(model_dir).resolve())
    cfg_path = Path(model_dir) / "adapter_config.json"
    if not cfg_path.exists():
        raise FileNotFoundError(f"No existe {cfg_path}")

    with open(cfg_path, "r", encoding="utf-8") as f:
        adapter_cfg = json.load(f)
    base = adapter_cfg.get("base_model_name_or_path")
    if not base:
        raise ValueError("adapter_config.json no contiene 'base_model_name_or_path'.")

    # Tokenizer desde el directorio del adapter (incluye el token extra)
    tok = AutoTokenizer.from_pretrained(model_dir, use_fast=True, trust_remote_code=True)
    if tok.pad_token is None:
        tok.pad_token = tok.eos_token
    tok.padding_side = "left"

    # Modelo base
    base_model = AutoModelForCausalLM.from_pretrained(
        base,
        torch_dtype=torch.float16 if device.startswith("cuda") else torch.float32,
        trust_remote_code=True
    ).to(device)

    #  alinear tamaño de vocab del base al del tokenizer usado en el adapter
    base_model.resize_token_embeddings(len(tok))

    # Cargar adapters LoRA
    model = PeftModel.from_pretrained(base_model, model_dir)
    model.eval()
    model.config.pad_token_id = tok.pad_token_id

    # token de fin de oración personalizado
    eos_id = None
    try:
        eid = tok.convert_tokens_to_ids("<|sentence_end|>")
        if eid is not None and eid != tok.unk_token_id:
            eos_id = eid
    except Exception:
        pass

    return model, tok, eos_id

def build_prompt(src: str) -> str:
    return tokenizer.apply_chat_template(
        [{"role":"system","content":SYSTEM_PROMPT},
         {"role":"user","content":USER_PREFIX + str(src)}],
        tokenize=False, add_generation_prompt=True
    )

model, tokenizer, EOS_ID = load_model_and_tokenizer(MODEL_DIR, DEVICE)
print("EOS_ID (custom):", EOS_ID)

app = FastAPI(title="Text Generation API", version="0.1.0")

# =========================
# HEALTH
# =========================
@app.get("/healthz")
async def healthz():
    return "ok"


# =========================
# GENERACION
# =========================
@app.post("/generate")
@torch.no_grad()
async def generateSummary(prompt: str) -> str:
    """
    Devuelve un str correspondiente al resúmen.
    """
    base_cfg = GEN_CFG.copy()
    if EOS_ID is not None:
        base_cfg["eos_token_id"] = EOS_ID
    base_cfg["pad_token_id"] = tokenizer.pad_token_id

    prompt_complete = build_prompt(prompt)

    inputs = tokenizer(prompt_complete, return_tensors="pt", padding=True, truncation=True).to(DEVICE)
    gen = model.generate(**inputs, **base_cfg)
    cut = inputs["input_ids"].shape[1]
    summary = tokenizer.batch_decode(gen[:, cut:], skip_special_tokens=True)
  
    return {"Resumen": summary}
