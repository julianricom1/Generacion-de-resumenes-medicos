from typing import Any, List, Optional

from pydantic import BaseModel

# from model.processing.validation import DataInputSchema


class GenerationResults(BaseModel):
    errors: Optional[Any]
    version: str
    generation: Optional[List[str]]
    scores: Optional[List[float]]
    metadata: Optional[dict]

# Esquema para inputs múltiples
class MultipleDataInputs(BaseModel):
    inputs: List[str]
    model: str
    class Config:
        schema_extra = {"example": {"inputs": ["Sample text for prediction"], "model": "your_model_name"}}

class GenerationRequest(BaseModel):
    prompt: str
    model: str