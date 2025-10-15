# app.py
import os
import json
import numpy as np
import pandas as pd
from fastapi import FastAPI, HTTPException
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

# =========================
# TARGETS (defaults)
# =========================
TARGET_RELEVANCE = 0.5
TARGET_FACTUALITY = 0.5
TARGET_FKGL = 8.0
TARGET_SMOG = 8.0
TARGET_DALECHALL = 6.0

def load_targets(path: str) -> bool:
    """Carga TARGET_* desde un JSON si existe. Devuelve True si cargó."""
    if not os.path.isfile(path):
        return False
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
    globals().update({
        "TARGET_RELEVANCE":  float(data.get("TARGET_RELEVANCE",  TARGET_RELEVANCE)),
        "TARGET_FACTUALITY": float(data.get("TARGET_FACTUALITY", TARGET_FACTUALITY)),
        "TARGET_FKGL":       float(data.get("TARGET_FKGL",       TARGET_FKGL)),
        "TARGET_SMOG":       float(data.get("TARGET_SMOG",       TARGET_SMOG)),
        "TARGET_DALECHALL":  float(data.get("TARGET_DALECHALL",  TARGET_DALECHALL)),
    })
    return True

def calibrateTargets(path: str, update_globals: bool = True, save_to: str | None = None):
    """
    Lee un CSV con columnas: 'original' y 'plain' (texto humano),
    calcula promedios y opcionalmente:
      - actualiza los TARGET_* en memoria (update_globals=True)
      - guarda a JSON (save_to='targets.json')
    Devuelve siempre un dict con los nuevos valores calculados.
    """
    df = pd.read_csv(path)
    required = {"original", "plain"}
    if not required.issubset(df.columns):
        raise ValueError(f"Faltan columnas requeridas: {required - set(df.columns)}")

    df = df[["original", "plain"]].dropna()
    df = df[(df["original"].str.strip() != "") & (df["plain"].str.strip() != "")]
    if df.empty:
        raise ValueError("No hay filas válidas después de limpieza.")

    originals = df["original"].tolist()
    humans    = df["plain"].tolist()

    relevances = compute_relevance(humans, originals)        # List[float] en [0,1]
    factuals   = compute_factuality(originals, humans)       # List[float] en [0,1]
    rdict      = compute_readability(humans)                 # Dict[str, List[float]]
    fkgls      = rdict["fkgl"]
    smogs      = rdict["smog"]
    dales      = rdict["dale_chall"]

    new_vals = {
        "TARGET_RELEVANCE":  float(np.mean(relevances)),
        "TARGET_FACTUALITY": float(np.mean(factuals)),
        "TARGET_FKGL":       float(np.mean(fkgls)),
        "TARGET_SMOG":       float(np.mean(smogs)),
        "TARGET_DALECHALL":  float(np.mean(dales)),
        "n_samples":         int(len(df)),
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
            "relevance": TARGET_RELEVANCE,
            "factuality": TARGET_FACTUALITY,
            "fkgl": TARGET_FKGL,
            "smog": TARGET_SMOG,
            "dale_chall": TARGET_DALECHALL,
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
    scores = compute_relevance(req.texts_generated, req.texts_human)
    return {"scores": scores, "model": BERTSCORE_MODEL, "device": BERT_DEVICE}

@app.post("/metrics/factuality")
async def factuality(req: FactualityRequest):
    scores = compute_factuality(req.texts_original, req.texts_generated)
    return {"scores": scores, "model": ALIGNSCORE_MODEL, "device": ALIGN_DEVICE}

@app.post("/metrics/readability")
async def readability(req: ReadabilityRequest):
    scores = compute_readability(req.texts)
    return {"fkgl": scores["fkgl"], "smog": scores["smog"], "dale_chall": scores["dale_chall"]}

# =========================
# LOSS
# =========================
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

    # Métricas crudas 
    rel  = np.asarray(compute_relevance(req.texts_generated, req.texts_human), dtype=np.float32)      # [0,1]
    fac  = np.asarray(compute_factuality(req.texts_original, req.texts_generated), dtype=np.float32)  # [0,1]
    rd   = compute_readability(req.texts_generated)
    fkgl = np.asarray(rd["fkgl"], dtype=np.float32)           # [0, +inf)
    smog = np.asarray(rd["smog"], dtype=np.float32)           # [0, +inf)
    dale = np.asarray(rd["dale_chall"], dtype=np.float32)     # ~[0,10]

    # Pérdidas por métrica:
    # Relevance / Factuality: L2 directo contra su target
    l_rel = (rel - float(TARGET_RELEVANCE))**2
    l_fac = (fac - float(TARGET_FACTUALITY))**2

    # Legibilidad: error cuadrático estandarizado respecto a su centro (TARGET_* = centros)
    # b = tolerancia en unidades de la métrica (sin crear nuevas constantes)
    l_fkgl = ((fkgl - float(TARGET_FKGL)) / 2.0)**2
    l_smog = ((smog - float(TARGET_SMOG)) / 2.0)**2
    l_dale = ((dale - float(TARGET_DALECHALL)) / 1.0)**2

    L = np.stack([l_rel, l_fac, l_fkgl, l_smog, l_dale], axis=1)   # (n,5)
    loss_per_sample = (L @ w).astype(float)                        # (n,)

    return float(loss_per_sample[0]) if n == 1 else loss_per_sample.tolist()