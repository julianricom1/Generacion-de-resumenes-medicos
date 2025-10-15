import os
from typing import List
from fastapi import HTTPException
from bert_score import score as bertscore
import torch

BERTSCORE_MODEL = os.getenv("BERTSCORE_MODEL", "roberta-large")
DEVICE = "cuda" if torch.cuda.is_available() else "cpu"

_WARMED = False

def compute_relevance(texts_generated: List[str], texts_human: List[str]) -> List[float]:
    if len(texts_generated) != len(texts_human):
        raise HTTPException(status_code=400, detail="los conjuntos deben tener la misma longitud.")
    _, _, F1 = bertscore(
        texts_generated, texts_human,
        lang="en",
        model_type=BERTSCORE_MODEL,
        device=DEVICE,
        verbose=False
    )
    return [float(x) for x in F1]

def warmup_relevance() -> None:
    """Carga pesos y cachea."""
    global _WARMED
    if _WARMED:
        return
    try:
        bertscore(["warmup"], ["warmup"], lang="en",
                  model_type=BERTSCORE_MODEL, device=DEVICE, verbose=False)
        _WARMED = True
    except Exception as e:
        # No abortes el arranque; deja el log y sigue.
        print(f"[relevance warmup] {type(e).__name__}: {e}")

def is_warmed_up() -> bool:
    return _WARMED
