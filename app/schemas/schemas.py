from pydantic import BaseModel

class SummaryRequest(BaseModel):
    text: str  # texto de entrada a resumir
