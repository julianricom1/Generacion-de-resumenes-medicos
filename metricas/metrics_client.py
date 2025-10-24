# metrics_client.py
from __future__ import annotations
import os
from typing import Sequence, Union, List, Dict, Any
import requests

Json = Dict[str, Any]
StrOrSeq = Union[str, Sequence[str]]

_DEFAULT_URL = os.getenv("METRICS_API_URL", "http://localhost:8000")
_session = requests.Session()

def _to_list(x: StrOrSeq) -> List[str]:
    if isinstance(x, str):
        return [x]
    return list(x)

def _post(base_url: str, path: str, payload: Json, timeout: float = 60.0) -> Any:
    url = f"{base_url.rstrip('/')}{path}"
    r = _session.post(url, json=payload, timeout=timeout)
    if r.status_code >= 400:
        try:
            detail = r.json()
        except Exception:
            detail = r.text
        raise RuntimeError(f"POST {url} failed [{r.status_code}]: {detail}")
    try:
        return r.json()
    except Exception:
        return r.text

def getHealth(base_url: str = _DEFAULT_URL, timeout: float = 30.0) -> Json:
    url = f"{base_url.rstrip('/')}/healthz"
    r = _session.get(url, timeout=timeout)
    if r.status_code >= 400:
        try:
            detail = r.json()
        except Exception:
            detail = r.text
        raise RuntimeError(f"GET {url} failed [{r.status_code}]: {detail}")
    return r.json()

def getRelevance(originals: StrOrSeq, generated: StrOrSeq, base_url: str = _DEFAULT_URL, timeout: float = 120.0) -> List[float]:
    o, g = _to_list(originals), _to_list(generated)
    if len(o) != len(g): raise ValueError("originals y generated deben tener la misma longitud")
    payload = {"texts_original": o, "texts_generated": g}
    out = _post(base_url, "/metrics/relevance", payload, timeout)
    return list(out["relevance"])

def getFactuality(originals: StrOrSeq, generated: StrOrSeq, base_url: str = _DEFAULT_URL, timeout: float = 900.0) -> List[float]:
    o, g = _to_list(originals), _to_list(generated)
    if len(o) != len(g): raise ValueError("originals y generated deben tener la misma longitud")
    payload = {"texts_original": o, "texts_generated": g}
    out = _post(base_url, "/metrics/factuality", payload, timeout)
    return list(out["factuality"])

def getReadability(texts: StrOrSeq, base_url: str = _DEFAULT_URL, timeout: float = 60.0) -> Dict[str, List[float]]:
    t = _to_list(texts)
    payload = {"texts": t}
    out = _post(base_url, "/metrics/readability", payload, timeout)
    return {"fkgl": list(out["fkgl"]), "smog": list(out["smog"]), "dale_chall": list(out["dale_chall"])}

def getLoss(originals: StrOrSeq, humans: StrOrSeq, generated: StrOrSeq, weights: Sequence[float] | None = None, base_url: str = _DEFAULT_URL, timeout: float = 900.0) -> Union[float, List[float]]:
    o, h, g = _to_list(originals), _to_list(humans), _to_list(generated)
    if not (len(o) == len(h) == len(g)):
        raise ValueError("originals, humans y generated deben tener la misma longitud")
    w = list(weights) if weights is not None else [0.2, 0.2, 0.2, 0.2, 0.2]
    if len(w) != 5:
        raise ValueError("weights debe tener longitud 5")
    s = sum(w)
    if abs(s - 1.0) > 1e-6:
        w = [wi / s for wi in w]

    payload = {
        "texts_original": o,
        "texts_human": h,
        "texts_generated": g,
        "weights": w,
    }
    out = _post(base_url, "/loss", payload, timeout)
    return out  # float si n==1, list si n>1


# Alias corto solicitado
def getLossPair(A: str, B: str, **kwargs) -> float:
    return float(getLoss(A, B, **kwargs))
