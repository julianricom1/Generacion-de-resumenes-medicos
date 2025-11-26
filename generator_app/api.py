from typing import Any
import os
# Imports que funcionan tanto localmente (generator_app) como en Docker (/app)
import sys
from pathlib import Path
from dotenv import load_dotenv

from fastapi import APIRouter, HTTPException
from loguru import logger

from generator_app.helpers.external_model_source import ExternalModel
from generator_app.helpers.finned_tunned_model import FinnedTunnedModel
from generator_app.schemas.supported_models import SupportedModels
from generator_app import __version__, schemas
from generator_app.config import settings


MODEL_VERSION = "0.1.0"
###

api_router = APIRouter()


# Ruta para verificar que la API se esté ejecutando correctamente
@api_router.get("/health", response_model=schemas.Health, status_code=200)
def health() -> dict:
    """
    Health check detallado de la API
    """
    health = schemas.Health(
        name=settings.PROJECT_NAME, api_version=__version__, model_version=MODEL_VERSION
    )

    return health.dict()

@api_router.post("/generate", response_model=schemas.GenerationResults, status_code=200)
async def generate(input_data: schemas.MultipleDataInputs) -> Any:
    texts = [str(t) for t in input_data.inputs]
    model_name = input_data.model
    logger.info(f"Making generation on inputs: {texts}")

    try:
        # Call OpenAI API to generate text based on classification
        if model_name not in SupportedModels._value2member_map_:
                raise HTTPException(status_code=400, detail=f"Modelo no soportado: {model_name}")
        generated_texts = []
        for i, text in enumerate(texts):
            if model_name == SupportedModels.OLLAMA_FINNED_TUNNED.value:
                model = FinnedTunnedModel()
            else:
                model = ExternalModel(
                    model_name=model_name
                )

            generated_text = model.generate(text)
            generated_texts.append(generated_text)
    except Exception as e:
        logger.warning(f"Generation error: {e}")
        raise HTTPException(status_code=500, detail=f"Generation failed: {e}")

    metrics = {
        "accuracy": 0.0,
        "recall": 0.0,
        "f1": 0.0,
        "pr_auc": 0.0,
        "roc_auc": 0.0,
    }
    return {
        "generation": generated_texts,
        "errors": None,
        "version": MODEL_VERSION,
        "metadata": {
            "model_version": MODEL_VERSION,
            "metrics": {
                "accuracy": metrics["accuracy"],
                "recall": metrics["recall"],
                "f1_score": metrics["f1"],
                "pr_auc": metrics["pr_auc"],
                "roc_auc": metrics["roc_auc"],
            },
        },
    }
