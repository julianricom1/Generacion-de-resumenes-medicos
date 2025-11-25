from typing import Any, List, Optional

from pydantic import BaseModel

# from model.processing.validation import DataInputSchema


# Esquema de los resultados de predicción
class PredictionResults(BaseModel):
    errors: Optional[Any]
    version: str
    predictions: Optional[List[int]]
    scores: Optional[List[float]]
    metadata: Optional[dict]


# Esquema para inputs múltiples
class MultipleDataInputs(BaseModel):
    inputs: List[str]

    class Config:
        schema_extra = {"example": {"inputs": ["Sample text for prediction"]}}
