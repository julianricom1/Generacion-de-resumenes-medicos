import os
from typing import List
from fastapi import HTTPException
from bert_score import score as bertscore
import torch

BERTSCORE_MODEL = os.getenv("BERTSCORE_MODEL", "roberta-large")
DEVICE = "cuda" if torch.cuda.is_available() else "cpu"

_WARMED = False

def compute_relevance(texts_original: List[str], texts_generated: List[str]) -> List[float]:
    """
    Relevance anclada al ORIGINAL:
    comparamos cands=generated vs refs=original. Devuelve F1 en [0,1].
    """
    if len(texts_original) != len(texts_generated):
        raise HTTPException(status_code=400, detail="los conjuntos deben tener la misma longitud.")

    _, _, F1 = bertscore(
        cands=texts_generated,
        refs=texts_original,
        model_type=BERTSCORE_MODEL,
        device=DEVICE,
        lang="en",
        idf=False,                 
        rescale_with_baseline=False,
        verbose=False
    )
    return [float(x) for x in F1]

def warmup_relevance() -> None:
    global _WARMED
    if _WARMED:
        return
    try:
        bertscore(["warmup"], ["warmup"], model_type=BERTSCORE_MODEL, device=DEVICE, lang="en",
                  idf=False, rescale_with_baseline=False, verbose=False)
        _WARMED = True
    except Exception as e:
        print(f"[relevance warmup] {type(e).__name__}: {e}")

def is_warmed_up() -> bool:
    return _WARMED
