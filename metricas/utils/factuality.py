# utils/factuality.py
import os
from typing import List
import torch

# Importa la clase tal cual está en tu paquete AlignScore instalado
from alignscore.alignscore import AlignScore as AlignScorer  

# Config por env (opcional)
ALIGNSCORE_MODEL = os.getenv("ALIGNSCORE_MODEL", "roberta-large")
ALIGNSCORE_CKPT = os.getenv("ALIGNSCORE_CKPT",os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "models", "AlignScore-base.ckpt")))
ALIGNSCORE_BATCH = int(os.getenv("ALIGNSCORE_BATCH", "8"))
ALIGNSCORE_EVAL_MODE = os.getenv("ALIGNSCORE_EVAL_MODE", "nli_sp")

DEVICE = "cuda" if torch.cuda.is_available() else "cpu"

_scorer = None

def _get_scorer():
    global _scorer
    if _scorer is None:
        _scorer = AlignScorer(
            model=ALIGNSCORE_MODEL,
            batch_size=ALIGNSCORE_BATCH,
            device=DEVICE,
            ckpt_path=ALIGNSCORE_CKPT,
            evaluation_mode=ALIGNSCORE_EVAL_MODE,
            verbose=False,
        )
    return _scorer

def compute_factuality(texts_original: List[str], texts_generated: List[str]) -> List[float]:
    """
    Devuelve puntajes AlignScore en [0,1] por par. 
    Si algún texto está vacío (tras strip) o AlignScore falla en un par, retorna 0.0 para ese caso.
    """
    assert len(texts_generated) == len(texts_original), "texts_generated y texts_original deben tener la misma longitud"
    scorer = _get_scorer()

    # Normalización básica y detección de pares válidos
    ctx = [(c or "").strip() for c in texts_original]
    hyp = [(h or "").strip() for h in texts_generated]
    n = len(ctx)

    valid_idx = [i for i in range(n) if ctx[i] and hyp[i]]
    scores = [0.0] * n  # Para pares inválidos o con error

    if not valid_idx:
        return scores  

    try:
        # Evalúa sólo pares válidos y reubica resultados
        out = scorer.score(
            contexts=[ctx[i] for i in valid_idx],
            claims=[hyp[i] for i in valid_idx]
        )
        for j, i in enumerate(valid_idx):
            scores[i] = float(out[j])
    except Exception as e:
        print(f"[factuality] AlignScore error: {e}")

    return scores

def warmup_factuality():
    """Descarga recursos necesarios."""
    import nltk
    try:
        nltk.data.find("tokenizers/punkt")
    except LookupError:
        nltk.download("punkt", quiet=True)
    # Algunas versiones de NLTK requieren también 'punkt_tab'
    try:
        nltk.data.find("tokenizers/punkt_tab")
    except LookupError:
        try:
            nltk.download("punkt_tab", quiet=True)
        except Exception:
            pass

    # spaCy model
    try:
        import spacy
        spacy.load("en_core_web_sm")
    except Exception:
        import subprocess, sys
        subprocess.run([sys.executable, "-m", "spacy", "download", "en_core_web_sm"], check=False)

    # fuerza la creación del scorer
    _ = _get_scorer()

def is_warmed_up() -> bool:
    return _scorer is not None
