# metrics_client.py
from __future__ import annotations
import os
from typing import Sequence, Union, List, Dict, Any
import requests
from urllib3.util.retry import Retry
from requests.adapters import HTTPAdapter

Json = Dict[str, Any]
StrOrSeq = Union[str, Sequence[str]]

_DEFAULT_URL = os.getenv("METRICS_API_URL", "http://127.0.0.1:8000")

# ---- Session robusta (retries + pool + backoff) ----
_session = requests.Session()
_retry = Retry(
    total=5,               # reintentos totales
    connect=3,             # errores de conexión
    read=3,                # errores de lectura
    backoff_factor=0.5,    # 0.5, 1.0, 2.0, ...
    status_forcelist=[502, 503, 504],
    allowed_methods=["GET", "POST"],
    raise_on_status=False,
)
_adapter = HTTPAdapter(max_retries=_retry, pool_connections=10, pool_maxsize=20)
_session.mount("http://", _adapter)
_session.mount("https://", _adapter)

# Siempre cerramos la conexión para evitar sockets colgados en Windows
_DEFAULT_HEADERS = {"Connection": "close", "Accept": "application/json"}

def _to_list(x: StrOrSeq) -> List[str]:
    if isinstance(x, str):
        return [x]
    return list(x)

def _post(base_url: str, path: str, payload: Json, timeout: float = 180.0) -> Any:
    url = f"{base_url.rstrip('/')}{path}"
    try:
        r = _session.post(url, json=payload, timeout=timeout, headers=_DEFAULT_HEADERS)
        r.raise_for_status()
    except requests.RequestException as e:
        raise RuntimeError(f"POST {url} failed: {e}") from e
    try:
        return r.json()
    except ValueError:
        return r.text

def getHealth(base_url: str = _DEFAULT_URL, timeout: float = 30.0) -> Json:
    url = f"{base_url.rstrip('/')}/healthz"
    try:
        r = _session.get(url, timeout=timeout, headers=_DEFAULT_HEADERS)
        r.raise_for_status()
    except requests.RequestException as e:
        raise RuntimeError(f"GET {url} failed: {e}") from e
    return r.json()

def getRelevance(
    originals: StrOrSeq,
    generated: StrOrSeq,
    base_url: str = _DEFAULT_URL,
    timeout: float = 180.0,
) -> List[float]:
    o, g = _to_list(originals), _to_list(generated)
    if len(o) != len(g):
        raise ValueError("originals y generated deben tener la misma longitud")
    payload = {"texts_original": o, "texts_generated": g}
    out = _post(base_url, "/metrics/relevance", payload, timeout)
    return list(out["relevance"])

def getFactuality(
    originals: StrOrSeq,
    generated: StrOrSeq,
    base_url: str = _DEFAULT_URL,
    timeout: float = 900.0,
) -> List[float]:
    o, g = _to_list(originals), _to_list(generated)
    if len(o) != len(g):
        raise ValueError("originals y generated deben tener la misma longitud")
    payload = {"texts_original": o, "texts_generated": g}
    out = _post(base_url, "/metrics/factuality", payload, timeout)
    return list(out["factuality"])

def getReadability(
    texts: StrOrSeq,
    base_url: str = _DEFAULT_URL,
    timeout: float = 120.0,
) -> Dict[str, List[float]]:
    t = _to_list(texts)
    payload = {"texts": t}
    out = _post(base_url, "/metrics/readability", payload, timeout)
    return {"fkgl": list(out["fkgl"]), "smog": list(out["smog"]), "dale_chall": list(out["dale_chall"])}

def getLoss(
    originals: StrOrSeq,
    humans: StrOrSeq,
    generated: StrOrSeq,
    weights: Sequence[float] | None = None,
    base_url: str = _DEFAULT_URL,
    timeout: float = 900.0,
) -> Union[float, List[float]]:
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

# Alias útil sólo cuando comparas dos listas: 'humans' y 'generated' (misma longitud).
def getLossPair(humans: StrOrSeq, generated: StrOrSeq, **kwargs) -> float | List[float]:
    """
    Calcula la loss usando solo 'human vs generated' (sin originals).
    Requiere que el backend soporte omitir originals o lo derive internamente.
    """
    return getLoss(originals=[], humans=humans, generated=generated, **kwargs)
