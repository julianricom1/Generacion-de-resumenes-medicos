# app.py
import os, json
from pathlib import Path
import torch
from fastapi import FastAPI
from transformers import AutoTokenizer, AutoModelForCausalLM
from peft import PeftModel
from app.schemas.schemas import SummaryRequest

app = FastAPI(title="Text Generation API", version="0.1.0")

DEVICE = "cuda" if torch.cuda.is_available() else "cpu"

SYSTEM_PROMPT = (
    "You simplify clinical trial protocol text into a plain-language summary for the general public. "
    "Keep to 6–8th grade readability, avoid diagnoses and speculation, no hallucinations, "
    "and preserve key facts (objective, population, interventions, outcomes, timelines, safety)."
)
USER_PREFIX = "Using the following clinical trial protocol text as input, create a plain language summary.\n\n"

MODEL_DIR = os.getenv(
    "MODEL_DIR",
    "generacion/ollama/outputs/meta-llama__Llama-3.2-3B-Instruct-lora-fp16/final",
)


GEN_CFG = dict(
    max_new_tokens=int(os.getenv("MAX_NEW_TOKENS", "512")),
    do_sample=True,
    temperature=float(os.getenv("TEMPERATURE", "0.2")),
    top_p=0.9,
    no_repeat_ngram_size=0,
    repetition_penalty=1.015,
)

def load_model_and_tokenizer(model_dir: str, device: str = DEVICE):
    model_dir = str(Path(model_dir).resolve())
    cfg_path = Path(model_dir) / "adapter_config.json"
    if not cfg_path.exists():
        raise FileNotFoundError(f"No existe {cfg_path}")

    adapter_cfg = json.loads(Path(cfg_path).read_text(encoding="utf-8"))
    base = adapter_cfg.get("base_model_name_or_path")
    if not base:
        raise ValueError("adapter_config.json no contiene 'base_model_name_or_path'.")

    tok = AutoTokenizer.from_pretrained(model_dir, use_fast=True, trust_remote_code=True)
    if tok.pad_token is None:
        tok.pad_token = tok.eos_token
    tok.padding_side = "left"

    base_model = AutoModelForCausalLM.from_pretrained(
        base,
        torch_dtype=torch.float16 if device.startswith("cuda") else torch.float32,
        trust_remote_code=True,
    ).to(device)

    base_model.resize_token_embeddings(len(tok))
    model = PeftModel.from_pretrained(base_model, model_dir)
    model.eval()
    model.config.pad_token_id = tok.pad_token_id

    eos_id = None
    try:
        eid = tok.convert_tokens_to_ids("<|sentence_end|>")
        if eid is not None and eid != tok.unk_token_id:
            eos_id = eid
    except Exception:
        pass

    return model, tok, eos_id

model, tokenizer, EOS_ID = load_model_and_tokenizer(MODEL_DIR, DEVICE)

def build_prompt(src: str) -> str:
    return tokenizer.apply_chat_template(
        [{"role": "system", "content": SYSTEM_PROMPT},
         {"role": "user",   "content": USER_PREFIX + str(src)}],
        tokenize=False, add_generation_prompt=True
    )

#==========================================
# ENDPOINTS
#==========================================

@app.get("/healthz")
def healthz():
    return {"status": "ok", "device": DEVICE}

@app.post("/generate")
@torch.no_grad()
def generate_summary(req: SummaryRequest):
    cfg = GEN_CFG.copy()
    if EOS_ID is not None:
        cfg["eos_token_id"] = EOS_ID
    cfg["pad_token_id"] = tokenizer.pad_token_id

    prompt = build_prompt(req.text)
    inputs = tokenizer(prompt, return_tensors="pt", padding=True, truncation=True).to(DEVICE)
    gen = model.generate(**inputs, **cfg)
    cut = inputs["input_ids"].shape[1]
    summary = tokenizer.decode(gen[0, cut:], skip_special_tokens=True).strip()
    return {"summary": summary}