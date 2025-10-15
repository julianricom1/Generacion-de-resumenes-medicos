from pydantic import BaseModel
from typing import List

class RelevanceRequest(BaseModel):
    # Relevancia: generado vs humano
    texts_generated: List[str]
    texts_human: List[str]

class FactualityRequest(BaseModel):
    # Factualidad: generado vs original
    texts_generated: List[str]
    texts_original: List[str]

class ReadabilityRequest(BaseModel):
    # Legibilidad del texto
    texts: List[str]

class LossRequest(BaseModel):
    texts_original: List[str]
    texts_human: List[str]
    texts_generated: List[str]
    weights: List[float]
