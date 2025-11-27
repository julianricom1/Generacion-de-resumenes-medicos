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

# Este proceso puede tardar mas de 45 minutos. 
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

**Nota importante sobre el generador:**

Antes siquiera de subir el modelo a s3, es necesario configurar ciertas credenciales

**Configura `KEYS.py`** (en la raíz del proyecto):
   ```python
   # Token de Hugging Face para acceder a modelos gated
   HF_TOKEN = "tu_token_aqui"
   
   # Bucket S3 para modelos
   MODEL_S3_BUCKET = "modelo-generador-maia-g3"
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
# Detener todos los servicios, load balancer y cluster ECS (preserva imágenes en ECR)
make stopall

# Restaurar toda la infraestructura (cluster ECS + servicios + load balancer + web)
# NOTA: El web requiere que la imagen en ECR haya sido construida con los endpoints correctos
make restoreall MODEL_NAME=meta-llama__Llama-3.2-3B-Instruct-6_epocas
```

**Nota sobre stop vs destroy:**
- `stop-*` / `stopall`: Elimina solo el servicio ECS (y load balancer/cluster en `stopall`), preserva las imágenes en ECR. Útil para ahorrar costos sin perder las imágenes Docker.
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
# Obtener URLs del Load Blancer (muestra todos los endpoints de los servicios). Los servicios están disponibles en puertos diferentes usando un **Network Load Balancer (NLB) compartido** con múltiples listeners
make show_endpoints

# Ver estado del servicio de métricas
make metricas-status

# Ver estado del servicio generador
make generador-status

# Ver estado del servicio clasificador
make clasificador-status

# Ver estado del servicio web
make web-status
```