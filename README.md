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

## Despliegue en AWS

El proyecto incluye un Makefile con comandos para desplegar los servicios de métricas y generación en AWS usando Terraform y ECS Fargate.

### Comandos principales

#### Despliegue completo
```bash
# PASO 1: Merge y subida a S3 (hacer una vez, localmente en Windows con Jupyter)
# Abre y ejecuta el notebook: generator_app/merge_and_upload_to_s3.ipynb

# PASO 2: Desplegar toda la infraestructura (métricas + generador)
make startall MODEL_NAME=meta-llama__Llama-3.2-3B-Instruct-6_epocas

# Destruir toda la infraestructura
make destroyall
```

#### Servicios individuales

Los servicios son completamente independientes y pueden desplegarse por separado o juntos.

**Métricas:**
```bash
# Desplegar servicio de métricas (incluye toda la infraestructura necesaria)
make deploy-metricas

# Destruir servicio (elimina completamente)
make destroy-metricas

# Detener servicio (preserva imagen en ECR, elimina solo el servicio ECS)
make stop-metricas

# Restaurar servicio (usa imagen existente en ECR, no reconstruye)
make restore-metricas

# Re-desplegar (reconstruir imagen y actualizar servicio)
make redeploy-metricas
```

**Generador:**
```bash
# PASO 1: Merge y subida a S3 (hacer una vez, localmente en Windows con Jupyter)
# Abre y ejecuta el notebook: generator_app/merge_and_upload_to_s3.ipynb
# Este notebook:
#   - Hace el merge del LoRA con el modelo base
#   - Sube el modelo mergeado a S3: s3://modelo-generador-maia-g8/merged-models/{MODEL_NAME}/

# PASO 2: Desplegar servicio generador (después del merge)
make deploy-generador MODEL_NAME=meta-llama__Llama-3.2-3B-Instruct-6_epocas

# Destruir servicio (elimina completamente)
make destroy-generador

# Detener servicio (preserva imagen en ECR, elimina solo el servicio ECS)
make stop-generador MODEL_NAME=meta-llama__Llama-3.2-3B-Instruct-6_epocas

# Restaurar servicio (usa imagen existente en ECR, no reconstruye)
make restore-generador MODEL_NAME=meta-llama__Llama-3.2-3B-Instruct-6_epocas

# Re-desplegar (reconstruir imagen y actualizar servicio)
make redeploy-generador MODEL_NAME=meta-llama__Llama-3.2-3B-Instruct-6_epocas
```

**Comandos para todos los servicios:**
```bash
# Detener todos los servicios, load balancers y cluster ECS (preserva imágenes en ECR)
make stopall

# Restaurar toda la infraestructura (cluster ECS + servicios + load balancers)
make restoreall MODEL_NAME=meta-llama__Llama-3.2-3B-Instruct-6_epocas
```

**Nota sobre stop vs destroy:**
- `stop-*` / `stopall`: Elimina solo el servicio ECS (y load balancers/cluster en `stopall`), preserva las imágenes en ECR. Útil para ahorrar costos sin perder las imágenes Docker.
- `destroy-*` / `destroyall`: Elimina completamente el servicio y todos sus recursos. Útil para limpiar completamente.
- `restore-*` / `restoreall`: Restaura el servicio usando las imágenes existentes en ECR (no reconstruye las imágenes). Más rápido que `deploy-*`.

**Nota importante sobre el generador:**

**PASO 1: Merge y subida a S3 (local, una vez)**

1. **Configura `KEYS.py`** (en la raíz del proyecto):
   ```python
   # Token de Hugging Face para acceder a modelos gated
   HF_TOKEN = "tu_token_aqui"
   
   # Bucket S3 para modelos
   MODEL_S3_BUCKET = "modelo-generador-maia-g8"
   ```

2. **Abre el notebook**: `generator_app/merge_and_upload_to_s3.ipynb`

3. **Ajusta los parámetros en el notebook:**
   - `LORA_PATH`: Ruta al directorio `final` del LoRA entrenado
   - `MODEL_NAME`: Se detecta automáticamente, pero puedes especificarlo manualmente
   - `AWS_REGION`: Región de AWS (por defecto: `us-east-1`)

4. **Ejecuta todas las celdas** en orden

5. **El notebook:**
   - Hace el merge del LoRA con el modelo base localmente
   - Sube el modelo mergeado a S3: `s3://modelo-generador-maia-g8/merged-models/{MODEL_NAME}/`
   - Muestra el `MODEL_NAME` que debes usar en el siguiente paso

**PASO 2: Build y deploy**

- El build de la imagen Docker se hace **localmente** (no requiere EC2)
- Durante el build:
  - La imagen Docker se construye localmente
  - El modelo mergeado se descarga desde S3 al iniciar el contenedor (usando `entrypoint.sh`)
- **Ventajas del nuevo enfoque:**
  - No requiere permisos de EC2
  - Build más rápido (local)
  - El merge se hace una sola vez
  - El modelo se descarga de S3 solo cuando se necesita

**Configuración de recursos y parámetros del generador:**

Los recursos (CPU, memoria) y parámetros de generación (MAX_NEW_TOKENS, TEMPERATURE) se configuran en el archivo `terraform/environments/student/generador/terraform.tfvars`:

```terraform
cpu            = 4096      # CPU en unidades (1024 = 1 vCPU, 4096 = 4 vCPU)
memory         = 16384     # Memoria en MB (16384 = 16 GB)
desired_count  = 1
env_vars = { 
  PORT = "8000"
  MODEL_NAME = "meta-llama__Llama-3.2-3B-Instruct-6_epocas"
  DEVICE = "cpu"
  MAX_NEW_TOKENS = "512"   # Máximo de tokens a generar
  TEMPERATURE = "0.2"      # Temperatura para sampling (0.0-2.0, menor = más determinista)
  TOP_P = "0.9"
  REPEAT_PENALTY = "1.015"
}
```

**Para modificar estos valores:**

1. Edita `terraform/environments/student/generador/terraform.tfvars`
2. Ajusta los valores deseados:
   - `cpu`: CPU en unidades (1024 = 1 vCPU). Valores comunes: 1024, 2048, 4096, 8192
   - `memory`: Memoria en MB. Debe ser compatible con Fargate según el CPU elegido
   - `MAX_NEW_TOKENS`: Número máximo de tokens a generar (ej: "256", "512", "1024")
   - `TEMPERATURE`: Controla la aleatoriedad (0.0-2.0). Valores más bajos = más determinista
3. Aplica los cambios:
   ```bash
   make generador-plan
   make generador-apply
   ```

**Nota sobre combinaciones CPU/Memoria válidas en Fargate:**
- 1 vCPU (1024): 2048, 3072, 4096 MB
- 2 vCPU (2048): 4096, 5120, 6144, 7168, 8192, 10240, 12288, 16384 MB
- 4 vCPU (4096): 8192, 16384, 30720, 32768 MB
- 8 vCPU (8192): 16384, 30720, 32768, 61440, 65536 MB

### Utilidades

```bash
# Obtener URLs del NLB
make alb-dns

# Ver estado del servicio de métricas
make metricas-status

# Ver estado del servicio generador
make generador-status
```

### Endpoints de la API

Una vez desplegados los servicios, puedes obtener las URLs usando `make alb-dns`. Los servicios están disponibles en puertos diferentes usando Network Load Balancers (NLB):

**Servicio de Métricas** (puerto 8001):
- Base URL: `http://{nlb-metricas-dns}:8001`
- Health check: `GET http://{nlb-metricas-dns}:8001/healthz`
- Relevancia: `POST http://{nlb-metricas-dns}:8001/metrics/relevance`
  ```json
  {
    "texts_original": ["texto original 1", "texto original 2"],
    "texts_generated": ["texto generado 1", "texto generado 2"]
  }
  ```
- Factualidad: `POST http://{nlb-metricas-dns}:8001/metrics/factuality`
  ```json
  {
    "texts_original": ["texto original 1", "texto original 2"],
    "texts_generated": ["texto generado 1", "texto generado 2"]
  }
  ```
- Legibilidad: `POST http://{nlb-metricas-dns}:8001/metrics/readability`
  ```json
  {
    "texts": ["texto 1", "texto 2", "texto 3"]
  }
  ```
- Loss combinado: `POST http://{nlb-metricas-dns}:8001/loss`
  ```json
  {
    "texts_original": ["texto original 1"],
    "texts_human": ["texto humano 1"],
    "texts_generated": ["texto generado 1"],
    "weights": [0.25, 0.25, 0.2, 0.15, 0.15]
  }
  ```

**Servicio Generador** (puerto 8000):
- Base URL: `http://{nlb-generador-dns}:8000`
- Health check: `GET http://{nlb-generador-dns}:8000/healthz`
- Generar resumen: `POST http://{nlb-generador-dns}:8000/generate`
  ```json
  {
    "text": "Texto médico a resumir..."
  }
  ```

**Nota:** Los NLB no tienen timeout de request (a diferencia del ALB que tiene 60 segundos), por lo que pueden manejar requests largas sin problemas.

### Proceso de merge y build del generador

El proceso del generador se divide en dos pasos:

#### PASO 1: Merge y subida a S3 (local, una vez)

1. **Abre el notebook Jupyter**: `generator_app/merge_and_upload_to_s3.ipynb`
2. **Configura el notebook:**
   - Ajusta `LORA_PATH` si es necesario (ya viene con un ejemplo)
   - El `MODEL_NAME` se detecta automáticamente del `LORA_PATH`
   - Asegúrate de tener el token de Hugging Face en `KEYS.py`
3. **Ejecuta todas las celdas:**
   - Hace el merge del LoRA con el modelo base localmente
   - Sube el modelo mergeado a S3: `s3://modelo-generador-maia-g8/merged-models/{MODEL_NAME}/`
4. **Tiempo estimado**: 15-30 minutos (depende de la velocidad de descarga y merge)

**Requisitos:**
- Token de Hugging Face en `KEYS.py` (archivo en la raíz del proyecto)
- Credenciales AWS configuradas para subir a S3
- Dependencias: `torch`, `transformers`, `peft`, `huggingface-hub`, `boto3`

#### PASO 2: Build y deploy (después del merge)

1. **Build local de la imagen Docker:**
   - Se construye localmente (no requiere EC2)
   - El modelo mergeado se descarga desde S3 al iniciar el contenedor
2. **Sube la imagen a ECR**
3. **Despliega el servicio en ECS**

**Ventajas del nuevo enfoque:**
- **No requiere permisos de EC2**: todo se hace localmente
- **Build más rápido**: no hay overhead de crear/destruir EC2
- **El merge se hace una sola vez**: el modelo mergeado se reutiliza
- **El modelo se descarga de S3 solo cuando se necesita**: más eficiente
- **No necesitas tener el LoRA localmente**: se descarga desde S3 durante el merge

**Configuración del bucket S3:**
- Bucket permanente: `modelo-generador-maia-g8`
- Modelos mergeados en S3: `s3://modelo-generador-maia-g8/merged-models/{MODEL_NAME}/`
- Este bucket no se modifica ni elimina por el proceso de deployment

### Notas importantes

- **El merge se hace localmente** usando el notebook `generator_app/merge_and_upload_to_s3.ipynb`
  - El notebook requiere el token de Hugging Face en `KEYS.py`
  - El `MODEL_NAME` se detecta automáticamente del `LORA_PATH` o puedes especificarlo manualmente
  - El modelo mergeado se sube a S3: `s3://modelo-generador-maia-g8/merged-models/{MODEL_NAME}/`
- El comando `startall` y `deploy-generador` requieren especificar `MODEL_NAME` (no `LORA_PATH`)
  - El `MODEL_NAME` es el nombre del modelo mergeado que está en S3
  - Ejemplo: `make deploy-generador MODEL_NAME=meta-llama__Llama-3.2-3B-Instruct-6_epocas`
- El modelo mergeado debe estar previamente en S3 antes de hacer el deploy
- Los servicios son independientes: puedes desplegar métricas o generador por separado
- Cada servicio despliega su propia infraestructura (VPC, ECS, ALB) si no existe
- Los servicios se despliegan en ECS Fargate con Network Load Balancers (NLB):
  - Métricas: `http://{nlb-metricas-dns}:8001`
  - Generador: `http://{nlb-generador-dns}:8000`
- **CloudWatch Logs no se usa**: los logs de los contenedores no se almacenan en CloudWatch
- **Manejo automático de Terraform**: Los comandos de destroy (`destroy-metricas`, `destroy-generador`, `destroyall`, etc.) manejan automáticamente los problemas de lock file inconsistentes, ejecutando `init` cuando es necesario
- **Bucket S3 del LoRA**: El bucket `modelo-generador-maia-g8` es permanente y no se modifica ni elimina por el proceso de deployment. Asegúrate de que el LoRA esté subido antes de ejecutar el build.