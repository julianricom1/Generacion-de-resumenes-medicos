from pydantic import BaseModel
from typing import List

class SummaryRequest(BaseModel):
    texts_original: str