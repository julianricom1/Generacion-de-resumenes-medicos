# Generacion-de-resumenes.-medicos

Sistema completo para generación, evaluación y clasificación de resúmenes médicos en lenguaje simple (PLS - Plain Language Summaries).

**Componentes del sistema:**
- **Métricas**: 5 métricas para evaluar la calidad de los resúmenes generados
- **Generador**: Servicio para generar resúmenes médicos usando modelos LLM fine-tuned
- **Clasificador**: Servicio para clasificar textos médicos
- **Web**: Interfaz de usuario React para interactuar con todos los servicios

## Estructura del Repositorio

```
Generacion-de-resumenes.-medicos/
├── clasificador_app/          # Servicio de clasificación de textos médicos
│   ├── api.py                  # Endpoints FastAPI (/predict, /health)
│   ├── main.py                 # Aplicación principal FastAPI
│   ├── config.py               # Configuración del servicio
│   ├── schemas/                 # Modelos Pydantic (request/response)
│   ├── Dockerfile              # Imagen Docker del clasificador
│   └── requirements.txt        # Dependencias Python
│
├── generator_app/              # Servicio de generación de resúmenes
│   ├── api.py                  # Endpoints FastAPI (/generate, /health)
│   ├── main.py                 # Aplicación principal FastAPI
│   ├── config.py               # Configuración del servicio
│   ├── helpers/                 # Utilidades (modelos fine-tuned, APIs externas)
│   ├── schemas/                 # Modelos Pydantic (request/response)
│   ├── merge_and_upload_to_s3.ipynb  # Notebook para merge y subida a S3
│   ├── Dockerfile              # Imagen Docker del generador
│   ├── entrypoint.sh           # Script de inicio (descarga modelo desde S3)
│   └── requirements.txt        # Dependencias Python
│
├── metricas/                   # Servicio de evaluación de métricas
│   ├── app.py                  # Aplicación principal FastAPI
│   ├── metrics_client.py       # Cliente wrapper para uso fácil
│   ├── utils/                   # Utilidades para cada métrica
│   ├── schemas/                 # Modelos Pydantic
│   ├── models/                  # Modelos AlignScore (.ckpt)
│   ├── targets.json            # Valores objetivo para calibración
│   ├── Dockerfile              # Imagen Docker de métricas
│   ├── entrypoint.sh           # Script de inicio (descarga modelo desde S3)
│   └── requirements.txt        # Dependencias Python
│
├── web/                        # Interfaz de usuario React
│   ├── src/                    # Código fuente React
│   │   ├── components/         # Componentes reutilizables
│   │   ├── containers/         # Páginas/vistas principales
│   │   ├── hooks/              # Custom hooks (useGeneration, useMetrics, etc.)
│   │   └── App.jsx             # Componente principal
│   ├── public/                 # Archivos estáticos
│   ├── Dockerfile              # Build multi-stage (React + Nginx)
│   ├── nginx.conf              # Configuración Nginx
│   └── package.json            # Dependencias Node.js
│
├── terraform/                  # Infraestructura como código (AWS)
│   ├── environments/           # Configuraciones por ambiente (student, prod)
│   │   └── student/            # Variables y backends por stack
│   ├── modules/                # Módulos reutilizables de Terraform
│   └── stacks/                 # Stacks de infraestructura
│       ├── vpc/                # VPC, subnets, NAT Gateway
│       ├── ecs/                # Cluster ECS Fargate
│       ├── registry/           # Repositorios ECR
│       ├── alb/                # Network Load Balancer compartido
│       └── app/                # Módulo genérico para servicios ECS
│
├── data/                       # Datasets y datos de entrenamiento
│   ├── cleaned_train_dataset.csv
│   ├── cleaned_val_dataset.csv
│   └── cleaned_test_dataset.csv
│
├── model-pkg/                  # Paquetes Python de modelos (wheels) para el despliegue del clasificador
│   └── textclf_svm-0.1.0-py3-none-any.whl
│
├── generacion/                 # Notebooks y resultados de experimentos
│   ├── ollama/                 # Entrenamientos con Ollama
│   ├── Qwen/                   # Entrenamientos con Qwen
│   ├── SummLlama/              # Entrenamientos con SummLlama
│   └── [varios notebooks de evaluación y auxiliares]
│
├── makefile                    # Comandos de automatización (build, deploy, etc.)
├── KEYS.py                     # Configuración sensible (tokens, buckets S3)  * Este archivo debe ser agregado por el usuario, no se sbe al repositorio onlie ya que contiene secretos (safety concern)
└── README.md                   # Este archivo
```

**Nota:** Los modelos entrenados no se encuentran en el repositorio online debido a su gran tamaño. Se provee como ejemplo el modelo utilizado en el despliegue en la nube: 
https://huggingface.co/julianricom/meta-llama__Llama-3.2-3B-Instruct-6_epocas

**Nota:** El servicio de clasificación (`clasificador_app/`) fue desarrollado y experimentado en un repositorio separado. Para más detalles sobre la experimentación, entrenamiento y evaluación del modelo de clasificación, consulta: [Clasificacion-de-textos-medicos](https://github.com/julianricom1/Clasificacion-de-textos-medicos)

## Dependencias del Sistema

### Herramientas requeridas para despliegue en AWS

- **GNU Make**: Automatización de comandos de despliegue
- **Docker**: Construcción de imágenes de contenedores
- **AWS CLI**: Interacción con servicios de AWS (versión 2.x recomendada)
- **Terraform**: Infraestructura como código (versión >= 1.6)
- **Python 3**: Versión 3.10 o superior (para scripts auxiliares)
- **Node.js**: Versión 22 o superior (para el servicio web)
- **WSL**: Opcional pero recomendado si se ejecuta desde Windows

### Dependencias por componente

**Servicio Generador** (`generator_app/`):
- Python 3.10+
- FastAPI 0.116.2
- Transformers >= 4.40.0
- PEFT >= 0.8.0
- OpenAI >= 1.0.0 (opcional, para modelos comerciales)
- Anthropic >= 0.18.0 (opcional, para Claude)

**Servicio Métricas** (`metricas/`):
- Python 3.10
- FastAPI 0.119.0
- PyTorch 1.13.1
- BERTScore 0.3.13
- AlignScore (instalado desde GitHub)
- TextStat 0.7.4

**Servicio Clasificador** (`clasificador_app/`):
- Python 3.11
- FastAPI 0.116.2
- scikit-learn 1.7.2
- scipy 1.16.2
- textclf_svm (paquete local en `model-pkg/`)

**Servicio Web** (`web/`):
- Node.js 22+
- React 19.1.1
- Vite 7.1.2
- Material-UI 7.3.2
- Axios 1.12.2

### Entorno de ejecución

- **Sistema operativo**: Linux (recomendado) o Windows con WSL
- **Región AWS**: us-east-1 (configurable)
- **Plataforma contenedores**: Linux/AMD64

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

**En este estudio se implementan 5 métricas que son relevantes para el problema de PLS**

## Qué mide cada métrica

- **Relevancia (BERTScore)**: similitud semántica entre **original** y **generado**.  
- **Factualidad (AlignScore)**: consistencia factual del **generado** con respecto al **original**.  
- **Readability** (legibilidad) :
  - **FKGL** (Flesch-Kincaid Grade Level): nivel de grado escolar (↓ más simple).
  - **SMOG**: años de educación requeridos (↓ más simple).
  - **Dale-Chall**: dificultad basada en palabras poco frecuentes (↓ más simple).

Las métricas de Relevancia y Factualidad requieren un modelo de lenguaje que soporte su operación
En el caso de AlignScore, este requiere unos modelos especificos en formato **.ckpt** el cual debe ser 
guardado en la carpeta **metricas/models**. Estos modelos están disponibles en el repositorio oficial de la 
implementación de la métrica:

**https://huggingface.co/yzha/AlignScore/tree/main**


## Para ejecutar el sistema de metricas localmente se pueden usar los siguientes comandos:

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


## Calibración de las métricas (para la función de pérdida)

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
- Para facilidad se incluye un wrapper para que en fases de complejidad (como el entrenamiento), se simplifica el proceso de obtener las métricas
y la pérdida. A continuación un ejemplo de uso:

```
from metrics_client import getLoss, getRelevance, getFactuality, getReadability

O = ["orig1", "orig2"]
G = ["gen1", "gen2"]

print(getLoss(O, G, weights=[0.25,0.25,0.2,0.15,0.15]))
print(getRelevance(O, G))
print(getFactuality(O, G))
print(getReadability(G))
```

----------------------------------------------------------------------------------------------------------------------------------------------------------

## Parametrización

El sistema permite ajustar parámetros de funcionamiento mediante variables de entorno configuradas en Terraform. A continuación se detallan las variables disponibles por servicio:

### Variables de entorno del Generador

Configuradas en `terraform/environments/student/generador/terraform.tfvars`:

| Variable | Descripción | Valor por defecto | Ejemplo |
|----------|-------------|------------------|---------|
| `PORT` | Puerto del servicio | `8000` | `8000` |
| `MODEL_NAME` | Nombre del modelo fine-tuned en S3 | Requerido | `meta-llama__Llama-3.2-3B-Instruct-6_epocas` |
| `DEVICE` | Dispositivo de ejecución (`cpu` o `cuda`) | `cpu` | `cpu` |
| `MAX_NEW_TOKENS` | Máximo número de tokens a generar | `512` | `256`, `512`, `1024` |
| `TEMPERATURE` | Controla la aleatoriedad (0.0-2.0, menor = más determinista) | `0.2` | `0.2`, `0.7`, `1.0` |
| `TOP_P` | Nucleus sampling parameter | `0.9` | `0.9` |
| `REPEAT_PENALTY` | Penalización por repetición | `1.015` | `1.015` |
| `SYSTEM_PROMPT` | Prompt del sistema para generación | Ver código | Prompt personalizado |
| `USER_PREFIX` | Prefijo del prompt del usuario | Ver código | Prefijo personalizado |
| `OPENAI_API_KEY` | API key de OpenAI (opcional, para modelos comerciales) | - | Se lee desde `KEYS.py` |
| `ANTHROPIC_API_KEY` | API key de Anthropic (opcional, para Claude) | - | Se lee desde `KEYS.py` |

**Nota:** Las API keys (`OPENAI_API_KEY` y `ANTHROPIC_API_KEY`) se leen automáticamente desde `KEYS.py` durante el despliegue. No es necesario agregarlas manualmente al archivo `terraform.tfvars`.

### Variables de entorno de Métricas

Configuradas en `terraform/environments/student/app/terraform.tfvars`:

| Variable | Descripción | Valor por defecto | Ejemplo |
|----------|-------------|------------------|---------|
| `PORT` | Puerto del servicio | `8001` | `8001` |
| `TARGETS_FILE` | Archivo JSON con valores objetivo para calibración | `targets.json` | `targets.json` |
| `ALIGNSCORE_MODEL` | Modelo base para AlignScore | `roberta-base` | `roberta-base` |
| `ALIGNSCORE_CKPT` | Ruta al checkpoint de AlignScore | `/models/AlignScore-base.ckpt` | `/models/AlignScore-base.ckpt` |
| `ALIGNSCORE_BATCH` | Tamaño de batch para AlignScore | `4` | `4`, `8` |
| `ALIGNSCORE_EVAL_MODE` | Modo de evaluación de AlignScore | `nli_sp` | `nli_sp` |
| `BERTSCORE_MODEL` | Modelo para BERTScore | `roberta-large` | `roberta-large` |
| `TORCH_NUM_THREADS` | Número de threads para PyTorch | Auto-detectado | `4` |
| `MODEL_S3_BUCKET` | Bucket S3 para descargar modelo AlignScore | `modelo-factualidad-g3` | `modelo-factualidad-g3` |


### Variables de entorno del Clasificador

Configuradas en `terraform/environments/student/clasificador-api/terraform.tfvars`:

| Variable | Descripción | Valor por defecto | Ejemplo |
|----------|-------------|------------------|---------|
| `PORT` | Puerto del servicio | `8002` | `8002` |

### Variables de entorno del Web

 Las URLs de los servicios backend se configuran durante el build de Docker mediante build arguments (`VITE_GENERATION_DOMAIN`, `VITE_METRICS_DOMAIN`, `VITE_CLASSIFICATION_DOMAIN`).

### Configuración de credenciales (KEYS.py)

El archivo `KEYS.py` debe crearse en la raíz del proyecto con la siguiente estructura:

```python
# Archivo de configuración para tokens y credenciales
# NO SUBIR ESTE ARCHIVO A GIT

# Token de Hugging Face para acceder a modelos gated
HF_TOKEN = "tu_token_de_huggingface_aqui"

# Bucket S3 para modelos
MODEL_S3_BUCKET = "modelo-generador-maia-g3"

# API Keys para modelos comerciales (opcional)
ANTHROPIC_API_KEY = "sk-ant-api03-..."  # Opcional: para usar Claude
OPENAI_API_KEY = "sk-proj-..."          # Opcional: para usar GPT-4/GPT-5
```

**Importante:** Este archivo no se encuentra en el repositorio por seguridad. Debes crearlo localmente antes de desplegar.

----------------------------------------------------------------------------------------------------------------------------------------------------------

## Despliegue en AWS

El proyecto incluye un Makefile con comandos para desplegar los servicios de métricas, generación y clasificación en AWS usando Terraform y ECS Fargate.

### Prerrequisitos

El proceso de despliegue fue desarrollado en Linux por lo que se recomienda su uso, aunque es compatible con Windows también. Antes de comenzar, asegúrate de tener configurado lo siguiente:

0. **Herramientas necesarias**
  - GNU Make
  - Docker
  - aws cli
  - Terraform
  - Python 3 + pip
  - WSL (opcional pero recomendado si se quiere ejecutar el proceso desde windows)

1. **Exportar ACCOUNT_ID de AWS:**
   ```bash
   export ACCOUNT_ID=123456789
   ```
   Reemplaza `123456789` con tu Account ID de AWS. 

   **nota** para windows el comando es $Env:ACCOUNT_ID = "123456789" (PowerShell) o set ACCOUNT_ID=123456789 (cmd)

2. **Configurar credenciales de AWS CLI:**
   ```bash
   aws configure
   ```
   Proporciona tus credenciales para el uso de aws cli.


**Bootstrapping**

El proceso requiere de 3 buckets s3 que soportan el despliegue
- infrastructura-maia-g3: almacena el estado de la infrastructura para Terraform. Solo debe existir y ser accesible (no es necesario agregar nada)
- modelo-factualidad-g3: almacena el modelo necesario para calcular AlignScore. Es el mismo que se encuentra en **metricas/models**
- modelo-generador-maia-g3: Debe existir y er accesible. Va a contener el modelo comprimido para el generador de resumenes. (ver Paso 1 a continuación)



```bash
#PASO 1: Merge del modelo y subida a S3 (se hace una vez, localmente en Windows con Jupyter)
#Abre, configura y ejecuta el notebook: generator_app/merge_and_upload_to_s3.ipynb
```

### Comandos principales

#### Despliegue completo
```bash
# PASO 2: Desplegar toda la infraestructura (métricas + generador + clasificador + web)
make startall MODEL_NAME=<nombre_del_modelo>

# por ejemplo: 
make startall MODEL_NAME=meta-llama__Llama-3.2-3B-Instruct-6_epocas

# Este proceso puede tardar más de una hora. 
# Al final de este se imprimiran en la consola las direcciónes web de los endpoints individuales asi como de la interfaz de usuario a la que se debe acceder

# Paso 3: Destruir toda la infraestructura
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

# Re-desplegar (reconstruir imagen y actualizar servicio. ùtil para cuando se hacen cambios como la capacidad de la máquina virtual)
make redeploy-metricas
```

**Generador:**
```bash

# Desplegar servicio de Generación (incluye toda la infraestructura necesaria)
make deploy-generador MODEL_NAME=<nombre_del_modelo>
# Por ejemplo:
make deploy-generador MODEL_NAME=meta-llama__Llama-3.2-3B-Instruct-6_epocas

# Destruir servicio (elimina completamente)
make destroy-generador

# Detener servicio (preserva imagen en ECR, elimina solo el servicio ECS)
make stop-generador MODEL_NAME=<nombre_del_modelo>
# Por ejemplo:
make stop-generador MODEL_NAME=meta-llama__Llama-3.2-3B-Instruct-6_epocas

# Restaurar servicio (usa imagen existente en ECR, no reconstruye)
make restore-generador MODEL_NAME=<nombre_del_modelo>
# Por ejemplo:
make restore-generador MODEL_NAME=meta-llama__Llama-3.2-3B-Instruct-6_epocas

# Re-desplegar (reconstruir imagen y actualizar servicio. ùtil para cuando se hacen cambios como la capacidad de la máquina virtual o el modelo a utilizar)
make redeploy-generador MODEL_NAME=<nombre_del_modelo>
# Por ejemplo:
make redeploy-generador MODEL_NAME=meta-llama__Llama-3.2-3B-Instruct-6_epocas

```

**Clasificador:**
```bash
# Desplegar servicio de clasificación (incluye toda la infraestructura necesaria)
make deploy-clasificador

# Destruir servicio (elimina completamente)
make destroy-clasificador

# Detener servicio (preserva imagen en ECR, elimina solo el servicio ECS)
make stop-clasificador

# Restaurar servicio (usa imagen existente en ECR, no reconstruye)
make restore-clasificador

# Re-desplegar (reconstruir imagen y actualizar servicio)
make redeploy-clasificador
```

**Web (Interfaz de Usuario):**
```bash
# Desplegar servicio web (requiere que los backends estén online)
make deploy-web

# Destruir servicio (elimina completamente)
make destroy-web

# Detener servicio (preserva imagen en ECR, elimina solo el servicio ECS)
make stop-web

# Restaurar servicio (usa imagen existente en ECR, no reconstruye)
# NOTA: La imagen debe haber sido construida con los endpoints correctos
make restore-web

# Re-desplegar (reconstruir imagen con endpoints actualizados y actualizar servicio)
make redeploy-web

```

**Comandos para todos los servicios:**
```bash
# Detener todos los servicios ECS (preserva NLB, cluster ECS e imágenes en ECR)
# NOTA: El NLB se mantiene activo para preservar los endpoints
# Los servicios se pueden restaurar después con los mismos endpoints
make stopall

# Restaurar todos los servicios ECS (usa NLB y cluster existentes)
# NOTA: Web requiere que la imagen en ECR haya sido construida con los endpoints correctos
make restoreall MODEL_NAME=meta-llama__Llama-3.2-3B-Instruct-6_epocas
```

**Nota sobre stop vs destroy:**
- `stop-*` / `stopall`: Elimina solo los servicios ECS, **preserva el NLB y cluster ECS** (y las imágenes en ECR). Útil para ahorrar costos sin perder los endpoints ni las imágenes Docker.
- `destroy-*` / `destroyall`: Elimina completamente el servicio y todos sus recursos. Útil para limpiar completamente.
- `restore-*` / `restoreall`: Restaura el servicio usando las imágenes existentes en ECR (no reconstruye las imágenes). Más rápido que `deploy-*`.
- **Nota sobre el web en `restoreall`**: El web requiere que la imagen en ECR haya sido construida con los endpoints correctos. Si los endpoints cambiaron, ejecuta `make redeploy-web` antes de restaurar.


### Configuración de recursos y parámetros del generador:

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
  TEMPERATURE = "0.2"      # Temperatura para sampling 
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
   - `TEMPERATURE`: Controla la aleatoriedad 
3. Aplica los cambios:
   ```bash
   make generador-plan
   make generador-apply
   ```

**Combinaciones CPU/Memoria válidas en Fargate:**
- 1 vCPU (1024): 2048, 3072, 4096 MB
- 2 vCPU (2048): 4096, 5120, 6144, 7168, 8192, 10240, 12288, 16384 MB
- 4 vCPU (4096): 8192, 16384, 30720, 32768 MB
- 8 vCPU (8192): 16384, 30720, 32768, 61440, 65536 MB

### Utilidades

```bash
# Obtener URLs del Load Blancer (muestra todos los endpoints de los servicios). Los servicios están disponibles en puertos diferentes usando un **Network Load Balancer (NLB) compartido** con múltiples listeners. 
make show_endpoints

# Ver estado del servicio de métricas
make metricas-status

# Ver estado del servicio generador
make generador-status

# Ver estado del servicio clasificador
make clasificador-status

# Ver estado del servicio web
make web-status

# Cambiar especificaciones del generador a máximas (16 CPU, 64 GB RAM)
# Útil para procesar textos largos o mejorar velocidad de generación
# NOTA: Para 16 vCPU, Fargate requiere memoria en incrementos de 8 GB (32-120 GB)
make redeploy-max-specs MODEL_NAME=<nombre_del_modelo>
# Por ejemplo:
make redeploy-max-specs MODEL_NAME=meta-llama__Llama-3.2-3B-Instruct-6_epocas

# Restaurar especificaciones normales del generador (4 CPU, 16 GB RAM)
# Útil cuando no se necesita máximo rendimiento
make redeploy-normal-specs MODEL_NAME=<nombre_del_modelo>
# Por ejemplo:
make redeploy-normal-specs MODEL_NAME=meta-llama__Llama-3.2-3B-Instruct-6_epocas
```

### Ejemplos de Uso de la API

Una vez desplegados los servicios, puedes obtener las URLs usando `make show_endpoints`. A continuación se muestran ejemplos de uso de cada endpoint:

#### Servicio de Métricas (Puerto 8001)

**Health Check:**
```bash
curl http://<nlb-dns>:8001/healthz
```

**Relevancia (BERTScore):**
```bash
curl -X POST http://<nlb-dns>:8001/metrics/relevance \
  -H "Content-Type: application/json" \
  -d '{
    "texts_original": ["Texto médico original 1", "Texto médico original 2"],
    "texts_generated": ["Resumen generado 1", "Resumen generado 2"]
  }'
```

**Factualidad (AlignScore):**
```bash
curl -X POST http://<nlb-dns>:8001/metrics/factuality \
  -H "Content-Type: application/json" \
  -d '{
    "texts_original": ["Texto médico original 1", "Texto médico original 2"],
    "texts_generated": ["Resumen generado 1", "Resumen generado 2"]
  }'
```

**Legibilidad:**
```bash
curl -X POST http://<nlb-dns>:8001/metrics/readability \
  -H "Content-Type: application/json" \
  -d '{
    "texts": ["Texto a evaluar 1", "Texto a evaluar 2", "Texto a evaluar 3"]
  }'
```

**Loss combinado:**
```bash
curl -X POST http://<nlb-dns>:8001/loss \
  -H "Content-Type: application/json" \
  -d '{
    "texts_original": ["Texto original"],
    "texts_human": ["Texto de referencia humano"],
    "texts_generated": ["Texto generado"],
    "weights": [0.25, 0.25, 0.2, 0.15, 0.15]
  }'
```

#### Servicio Generador (Puerto 8000)

**Health Check:**
```bash
curl http://<nlb-dns>:8000/healthz
# o
curl http://<nlb-dns>:8000/api/v1/health
```

**Generar resumen (modelo fine-tuned):**
```bash
curl -X POST http://<nlb-dns>:8000/api/v1/generate \
  -H "Content-Type: application/json" \
  -d '{
    "inputs": ["Texto médico a resumir..."],
    "model": "ollama_finned_tunned"
  }'
```

**Generar resumen (modelo comercial - Claude):**
```bash
curl -X POST http://<nlb-dns>:8000/api/v1/generate \
  -H "Content-Type: application/json" \
  -d '{
    "inputs": ["Texto médico a resumir..."],
    "model": "claude-sonnet-4-5"
  }'
```

**Generar resumen (modelo comercial - GPT):**
```bash
curl -X POST http://<nlb-dns>:8000/api/v1/generate \
  -H "Content-Type: application/json" \
  -d '{
    "inputs": ["Texto médico a resumir..."],
    "model": "gpt-4-turbo-preview"
  }'
```


#### Servicio Clasificador (Puerto 8002)

**Health Check:**
```bash
curl http://<nlb-dns>:8002/healthz
# o
curl http://<nlb-dns>:8002/api/v1/health
```

**Clasificar texto:**
```bash
curl -X POST http://<nlb-dns>:8002/api/v1/predict \
  -H "Content-Type: application/json" \
  -d '{
    "inputs": ["Texto médico a clasificar 1", "Texto médico a clasificar 2"]
  }'
```

**Ejemplo de respuesta:**
```json
{
  "predictions": ["Técnico", "Plano"],
  "scores": [0.95, 0.87],
  "errors": null,
  "version": "0.1.0",
  "metadata": {
    "model_version": "0.1.0",
    "metrics": {
      "accuracy": 0.92,
      "recall": 0.89,
      "f1_score": 0.91,
      "pr_auc": 0.94,
      "roc_auc": 0.96
    }
  }
}
```

