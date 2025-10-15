# Generacion-de-resumenes.-medicos

https://huggingface.co/yzha/AlignScore/tree/main


BERTScore is a metric for evaluating the quality of machine-generated text, such as summaries or translations.

AlignScore is a metric for evaluating factual consistency between text pairs. It uses a transformer architecture and accepts input in the form of tokenized text sequences.

.\.venv_metrics\Scripts\Activate.ps1

uvicorn app:app --host 0.0.0.0 --port 8000

docker build -t text-metrics:latest metricas


docker run --rm -p 8008:8008 `
  -e PORT=8008 `
  -e ALIGNSCORE_CKPT=/models/AlignScore-base.ckpt `
  -v "D:\OneDrive\Documents\MAIA\Semestre 4\Despliegue de Soluciones\__REPOS__\Generacion-de-resumenes.-medicos\metricas\models:/models" `
  text-metrics:latest