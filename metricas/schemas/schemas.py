from pydantic import BaseModel
from typing import List

class RelevanceRequest(BaseModel):
    texts_original: List[str]
    texts_generated: List[str]


class FactualityRequest(BaseModel):
    texts_original: List[str]
    texts_generated: List[str]

class ReadabilityRequest(BaseModel):
    texts: List[str]

class LossRequest(BaseModel):
    texts_original: List[str]
    texts_human: List[str]
    texts_generated: List[str]
    weights: List[float]
