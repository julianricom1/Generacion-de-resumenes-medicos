# Generacion-de-resumenes.-medicos

**En este sub-sistema se implementan 5 métricas que son relevantes para el problema de PLS**

## Qué mide cada métrica

- **Relevancia (BERTScore)**: similitud semántica entre **original** y **generado**.  
- **Factualidad (AlignScore)**: consistencia factual del **generado** con respecto al **original**.  
- **Readability** (legibilidad) :
  - **FKGL** (Flesch-Kincaid Grade Level): nivel de grado escolar (↓ más simple).
  - **SMOG**: años de educación requeridos (↓ más simple).
  - **Dale-Chall**: dificultad basada en palabras poco frecuentes (↓ más simple).

Las métricas de Relevancia y Factualidad requieren un modelo de lenguaje que soporte su operación
En el caso de AlignScore, este requiere unos modelos especificos en formato **.ckpt** el cual debe ser 
guardado en la carpeta **models**. Estos modelos están disponibles en el repositorio oficial de la 
implementación de la métrica:


**https://huggingface.co/yzha/AlignScore/tree/main**


## Para ejecutar el sistema localmente se pueden usar los siguientes comandos:

- Ubicarse en la raiz del repositorio
- python -m venv .venv_metricas
- .\.venv_metrics\Scripts\Activate.ps1
- pip install -r requirements.txt
- uvicorn app:app --host 0.0.0.0 --port 8000


## En caso de querer ejecutar esto en un contenedor de Docker:

- Ubicarse en la raiz del repositorio
- docker build -t text-metrics:latest metricas
- docker run --rm -p 8008:8008 `
    -e PORT=8008 `
    -e ALIGNSCORE_CKPT=/models/AlignScore-base.ckpt `
    -v "D:\OneDrive\Documents\MAIA\Semestre 4\Despliegue de Soluciones\__REPOS__\Generacion-de-resumenes.-medicos\metricas\models:/models" `
    text-metrics:latest


## Calibración (para la función de pérdida)

- Para emular los textos creados por humanos expertos se propone una aproximación estadística en la que se calculan cada una de las métricas
para el conjunto de entrenamiento. Esto con el objetivo de establecer valores objetivos a cumplir en las métricas del texto generado y con los
cuales guiar el entrenamiento.

- calibrateTargets(path = path_data, save_to = "targets.json", subset = 0.5, chunk_size = 16)

donde:
- path : ubicación de los datos de entrenamiento
- save_to : nombre de archivo donde se guardarán los resultados de la calibración
- subset : (0,1] porcentaje de los datos a utilizar en la calibración
- chunk_size : indica cada cuantos pasos se actualiza la barra de progreso

## Uso 
- Para facilidad se incluye un wrapper para que en fases de complejidad (como el entrenamiento), se simplifique el proceso ed obtener las métricas
y la pérdida

from metrics_client import getLoss, getRelevance, getFactuality, getReadability

O = ["orig1", "orig2"]
G = ["gen1", "gen2"]

print(getLoss(O, G, weights=[0.25,0.25,0.2,0.15,0.15]))
print(getRelevance(O, G))
print(getFactuality(O, G))
print(getReadability(G))
