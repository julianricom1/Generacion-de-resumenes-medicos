from typing import List, Dict

import textstat

_WARMED = False

def compute_readability(texts: List[str]) -> Dict[str, List[float]]:
    """Compute FKGL, SMOG (short-text) and Dale-Chall for each text.

    Returns a dict with arrays aligned to input order:
    {
      "fkgl": [...],
      "smog": [...],
      "dale_chall": [...]
    }
    """
    fkgl: List[float] = []
    smog: List[float] = []
    dale: List[float] = []

    for text in texts:
        fkgl.append(float(textstat.flesch_kincaid_grade(text)))
        smog.append(float(textstat.smog_index(text)))
        dale.append(float(textstat.dale_chall_readability_score(text)))

    return {"fkgl": fkgl, "smog": smog, "dale_chall": dale}


def warmup_readability() -> None:
    _ = textstat.flesch_kincaid_grade("warmup")
    _ = textstat.smog_index("warmup")
    _ = textstat.dale_chall_readability_score("warmup")
    global _WARMED
    _WARMED = True

def is_warmed_up() -> bool:
    return _WARMED
