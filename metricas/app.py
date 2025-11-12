# app.py
import os
import json
import numpy as np
import pandas as pd
from tqdm.auto import tqdm
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from schemas.schemas import RelevanceRequest, FactualityRequest, ReadabilityRequest, LossRequest
from utils.relevance import (
    compute_relevance,
    BERTSCORE_MODEL,
    DEVICE as BERT_DEVICE,
    warmup_relevance,
    is_warmed_up as rel_ready,
)
from utils.factuality import (
    compute_factuality,
    warmup_factuality,
    DEVICE as ALIGN_DEVICE,
    ALIGNSCORE_MODEL,
    is_warmed_up as fac_ready,
)
from utils.readability import (
    compute_readability,
    warmup_readability,
    is_warmed_up as rea_ready,
)

app = FastAPI(title="Text Metrics API", version="0.1.0")
origins = ["*"]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# =========================
# TARGETS (defaults)
# =========================
TARGET_RELEVANCE = 0.853
TARGET_FACTUALITY = 0.436
TARGET_FKGL = 9#13.707
TARGET_SMOG = 15.109
TARGET_DALECHALL = 11.624

SIGMA_RELEVANCE = 0.0167
SIGMA_FACTUALITY = 0.125
SIGMA_FKGL = 2.0793
SIGMA_SMOG = 1.6875
SIGMA_DALECHALL = 0.7911

def load_targets(path: str) -> bool:
    """Carga TARGET_* y SIGMA_* desde un JSON si existe. Devuelve True si cargó."""
    if not os.path.isfile(path):
        return False
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
    globals().update({
        # medias
        "TARGET_RELEVANCE":  float(data.get("TARGET_RELEVANCE",  TARGET_RELEVANCE)),
        "TARGET_FACTUALITY": float(data.get("TARGET_FACTUALITY", TARGET_FACTUALITY)),
        "TARGET_FKGL":       float(data.get("TARGET_FKGL",       TARGET_FKGL)),
        "TARGET_SMOG":       float(data.get("TARGET_SMOG",       TARGET_SMOG)),
        "TARGET_DALECHALL":  float(data.get("TARGET_DALECHALL",  TARGET_DALECHALL)),
        # sigmas (si faltan en el JSON, conserva defaults actuales)
        "SIGMA_RELEVANCE":   float(data.get("SIGMA_RELEVANCE",   SIGMA_RELEVANCE)),
        "SIGMA_FACTUALITY":  float(data.get("SIGMA_FACTUALITY",  SIGMA_FACTUALITY)),
        "SIGMA_FKGL":        float(data.get("SIGMA_FKGL",        SIGMA_FKGL)),
        "SIGMA_SMOG":        float(data.get("SIGMA_SMOG",        SIGMA_SMOG)),
        "SIGMA_DALECHALL":   float(data.get("SIGMA_DALECHALL",   SIGMA_DALECHALL)),
    })
    return True

def calibrateTargets(path: str, update_globals: bool = True, save_to: str | None = None, *, subset: float = 1.0, seed: int = 42, chunk_size: int = 16, progress: bool = True):
    """
    Lee un CSV con columnas: 'source_text', 'target_text' y 'split'.
    Usa EXCLUSIVAMENTE el split 'train' para evitar data leak.
    Toma un subconjunto (subset ∈ (0,1]) y calcula promedios y desviaciones estándar.
    Opcionalmente actualiza TARGET_* en memoria y guarda a JSON.
    """
    if not (0.0 < subset <= 1.0):
        raise ValueError("subset debe estar en (0, 1].")

    df = pd.read_csv(path)
    required = {"source_text", "target_text", "split"}
    if not required.issubset(df.columns):
        raise ValueError(f"Faltan columnas requeridas (incluida 'split'): {required - set(df.columns)}")

    # usar SOLO el split de entrenamiento para evitar data leak
    df = df[df["split"].astype(str).str.lower() == "train"]
    if df.empty:
        raise ValueError("No hay filas con split=='train' tras filtrar.")

    # limpieza mínima
    df = df[["source_text", "target_text"]].dropna()
    df = df[
        (df["source_text"].astype(str).str.strip() != "") &
        (df["target_text"].astype(str).str.strip() != "")
    ]
    if df.empty:
        raise ValueError("No hay filas válidas después de limpieza en split=='train'.")

    # muestreo
    if subset < 1.0:
        df = df.sample(frac=subset, random_state=seed).reset_index(drop=True)

    originals = df["source_text"].tolist()
    humans    = df["target_text"].tolist()
    n = len(df)

    def _tqdm(total, desc):
        return tqdm(total=total, desc=desc, unit="txt", disable=not progress)

    # --- Relevance ---
    rel_all = []
    with _tqdm(n, "relevance") as bar:
        for i in range(0, n, chunk_size):
            j = min(i + chunk_size, n)
            rel_all.extend(compute_relevance(originals[i:j], humans[i:j]))
            bar.update(j - i)

    # --- Factuality ---
    fac_all = []
    with _tqdm(n, "factuality") as bar:
        for i in range(0, n, chunk_size):
            j = min(i + chunk_size, n)
            fac_all.extend(compute_factuality(originals[i:j], humans[i:j]))
            bar.update(j - i)

    # --- Readability ---
    fkgl_all, smog_all, dale_all = [], [], []
    with _tqdm(n, "readability") as bar:
        for i in range(0, n, chunk_size):
            j = min(i + chunk_size, n)
            rd = compute_readability(humans[i:j])
            fkgl_all.extend(rd["fkgl"])
            smog_all.extend(rd["smog"])
            dale_all.extend(rd["dale_chall"])
            bar.update(j - i)

    # arrays
    rel_arr  = np.asarray(rel_all, dtype=float)
    fac_arr  = np.asarray(fac_all, dtype=float)
    fkgl_arr = np.asarray(fkgl_all, dtype=float)
    smog_arr = np.asarray(smog_all, dtype=float)
    dale_arr = np.asarray(dale_all, dtype=float)

    new_vals = {
        # medias (targets)
        "TARGET_RELEVANCE":  float(np.mean(rel_arr)),
        "TARGET_FACTUALITY": float(np.mean(fac_arr)),
        "TARGET_FKGL":       float(np.mean(fkgl_arr)),
        "TARGET_SMOG":       float(np.mean(smog_arr)),
        "TARGET_DALECHALL":  float(np.mean(dale_arr)),
        # desviaciones estándar (muestral)
        "SIGMA_RELEVANCE":   float(np.std(rel_arr,  ddof=1)) if rel_arr.size  > 1 else 0.0,
        "SIGMA_FACTUALITY":  float(np.std(fac_arr,  ddof=1)) if fac_arr.size  > 1 else 0.0,
        "SIGMA_FKGL":        float(np.std(fkgl_arr, ddof=1)) if fkgl_arr.size > 1 else 0.0,
        "SIGMA_SMOG":        float(np.std(smog_arr, ddof=1)) if smog_arr.size > 1 else 0.0,
        "SIGMA_DALECHALL":   float(np.std(dale_arr, ddof=1)) if dale_arr.size > 1 else 0.0,
        "n_samples":         int(n),
    }

    if update_globals:
        globals().update({
            "TARGET_RELEVANCE":  new_vals["TARGET_RELEVANCE"],
            "TARGET_FACTUALITY": new_vals["TARGET_FACTUALITY"],
            "TARGET_FKGL":       new_vals["TARGET_FKGL"],
            "TARGET_SMOG":       new_vals["TARGET_SMOG"],
            "TARGET_DALECHALL":  new_vals["TARGET_DALECHALL"],
        })

    if save_to:
        with open(save_to, "w", encoding="utf-8") as f:
            json.dump({k: v for k, v in new_vals.items() if k != "n_samples"}, f, ensure_ascii=False, indent=2)

    return new_vals

# =========================
# STARTUP
# =========================
@app.on_event("startup")
async def _startup():
    # 1) Cargar targets desde JSON si existe
    targets_file = os.getenv("TARGETS_FILE", "targets.json")
    if load_targets(targets_file):
        print(f"[targets] loaded from {targets_file}")
    else:
        print(f"[targets] using defaults (no {targets_file})")

    # 2) Warmups
    try:
        warmup_relevance();  print("[relevance warmup] OK")
    except Exception as e:
        print(f"[relevance warmup] {e}")
    try:
        warmup_factuality(); print("[factuality warmup] OK")
    except Exception as e:
        print(f"[factuality warmup] {e}")
    try:
        warmup_readability(); print("[readability warmup] OK")
    except Exception as e:
        print(f"[readability warmup] {e}")

# =========================
# HEALTH
# =========================
@app.get("/healthz")
async def healthz():
    status = {
        "relevance":  {"model": BERTSCORE_MODEL,   "device": BERT_DEVICE,   "ready": rel_ready()},
        "factuality": {"model": ALIGNSCORE_MODEL,  "device": ALIGN_DEVICE,  "ready": fac_ready()},
        "readability":{"ready": rea_ready()},
        "targets": {
            "relevance": round(float(TARGET_RELEVANCE), 3),
            "factuality": round(float(TARGET_FACTUALITY), 3),
            "fkgl":       round(float(TARGET_FKGL), 3),
            "smog":       round(float(TARGET_SMOG), 3),
            "dale_chall": round(float(TARGET_DALECHALL), 3),
        }
    }
    if not all((status["relevance"]["ready"], status["factuality"]["ready"], status["readability"]["ready"])):
        from fastapi import Response
        return Response(content=json.dumps(status), media_type="application/json", status_code=503)
    return status

# =========================
# METRICS
# =========================
@app.post("/metrics/relevance")
async def relevance(req: RelevanceRequest):
# handler
    scores = compute_relevance(req.texts_original, req.texts_generated)
    return {"relevance": scores, "model": BERTSCORE_MODEL, "device": BERT_DEVICE}


@app.post("/metrics/factuality")
async def factuality(req: FactualityRequest):
    scores = compute_factuality(req.texts_original, req.texts_generated)
    return {"factuality": scores, "model": ALIGNSCORE_MODEL, "device": ALIGN_DEVICE}

@app.post("/metrics/readability")
async def readability(req: ReadabilityRequest):
    scores = compute_readability(req.texts)
    return {"fkgl": scores["fkgl"], "smog": scores["smog"], "dale_chall": scores["dale_chall"]}

# =========================
# LOSS
# =========================
# --- Sigmoide calibrada por sigma ---
Y_AT_1SIGMA = 0.95  # pendiente deseada: valor de S(μ+σ)

def _k_from_sigma(sigma: float, y_at_1sigma: float = Y_AT_1SIGMA) -> float:
    sigma = float(sigma)
    if sigma <= 0:
        return 0.0  # evita división por cero; tratará como escalón plano
    return 10/sigma#float(np.log(y_at_1sigma / (1.0 - y_at_1sigma)) / sigma)

def _sigmoid_centered_err(x, mu, sigma, y_at_1sigma: float = Y_AT_1SIGMA):
    """
    Sigmoide centrada en mu con pendiente k derivada de σ:
      S(x) = 1 / (1 + exp(-k*(x-mu)))  con  S(mu+σ) = y_at_1sigma
    Error en [0,1]: 2*|S - 0.5|
    """
    x = np.asarray(x, dtype=np.float32)
    k = _k_from_sigma(sigma, y_at_1sigma)
    if k == 0.0:
        return np.zeros_like(x, dtype=np.float32)
    s = 1.0 / (1.0 + np.exp(-k * (x - float(mu))))
    return 2.0 * np.abs(s - 0.5)


@app.post("/loss")
async def loss(req: LossRequest):
    n = len(req.texts_generated)
    if not (len(req.texts_human) == len(req.texts_original) == n):
        raise HTTPException(status_code=400, detail="Las listas texts_* deben tener igual longitud.")
    if len(req.weights) != 5:
        raise HTTPException(status_code=400, detail="weights debe tener longitud 5.")
    w = np.asarray(req.weights, dtype=np.float32)
    if not np.isclose(w.sum(), 1.0, atol=1e-6):
        raise HTTPException(status_code=400, detail="La suma de weights debe ser 1.0.")

    # --- métricas crudas (orden armonizado) ---
    rel = np.asarray(compute_relevance(req.texts_original, req.texts_generated), dtype=np.float32) # [0,1]
    fac  = np.asarray(compute_factuality(req.texts_original, req.texts_generated), dtype=np.float32) # [0,1]

    rd   = compute_readability(req.texts_generated)
    fkgl = np.asarray(rd["fkgl"], dtype=np.float32)        # [0, +inf)
    smog = np.asarray(rd["smog"], dtype=np.float32)        # [0, +inf)
    dale = np.asarray(rd["dale_chall"], dtype=np.float32)  # ~[0,16]

    # --- errores normalizados en [0,1] ---
    # Relevance / Factuality: L2 directo contra su TARGET (ya en [0,1])
    e_rel = (rel - float(TARGET_RELEVANCE))**2
    e_fac = (fac - float(TARGET_FACTUALITY))**2

    # Legibilidad: sigmoide centrada en TARGET_* (0 en el centro)
    e_fkgl = _sigmoid_centered_err(fkgl, TARGET_FKGL, SIGMA_FKGL)
    e_smog = _sigmoid_centered_err(smog, TARGET_SMOG, SIGMA_SMOG)
    e_dale = _sigmoid_centered_err(dale, TARGET_DALECHALL, SIGMA_DALECHALL)

    E = np.stack([e_rel, e_fac, e_fkgl, e_smog, e_dale], axis=1)  # (n,5)
    loss_per_sample = (E @ w).astype(float)                       # ∈ [0,1]

    return float(loss_per_sample[0]) if n == 1 else loss_per_sample.tolist()