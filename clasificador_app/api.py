from typing import Any

###
# import textclf_logreg as clasificador
import textclf_svm as clasificador
from fastapi import APIRouter, HTTPException
from loguru import logger

# from model import __version__ as model_version
# from model.predict import make_prediction
from clasificador_app import __version__, schemas
from clasificador_app.config import settings

MODEL_VERSION = "0.1.0"
###

api_router = APIRouter()


# Ruta para verificar que la API se esté ejecutando correctamente
@api_router.get("/health", response_model=schemas.Health, status_code=200)
def health() -> dict:
    """
    Root Get
    """
    health = schemas.Health(
        name=settings.PROJECT_NAME, api_version=__version__, model_version=MODEL_VERSION
    )

    return health.dict()


# Ruta para realizar las predicciones
@api_router.post("/predict", response_model=schemas.PredictionResults, status_code=200)
async def predict(input_data: schemas.MultipleDataInputs) -> Any:
    texts = [str(t) for t in input_data.inputs]
    logger.info(f"Making prediction on inputs: {texts}")

    try:
        output = clasificador.predict(texts)
    except Exception as e:
        logger.warning(f"Prediction error: {e}")
        raise HTTPException(status_code=500, detail=f"Prediction failed: {e}")
    logger.info(f"outputs: {output['scores']}")

    metrics = clasificador.metrics()
    return {
        "predictions": output["labels"],
        "scores": output["scores"],
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
