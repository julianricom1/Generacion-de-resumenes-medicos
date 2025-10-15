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
    texts_generated: lista de resúmenes/claims
    texts_original:  lista de textos fuente (misma longitud)
    return: lista de puntajes float
    """
    assert len(texts_generated) == len(texts_original), "texts_generated y texts_original deben tener la misma longitud"
    scorer = _get_scorer()
    return scorer.score(contexts=texts_original, claims=texts_generated)

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
