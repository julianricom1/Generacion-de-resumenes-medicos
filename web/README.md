# Aplicación de Generación y Clasificación de Resúmenes Médicos

Aplicación web React + Vite que permite la generación de resúmenes en lenguaje plano de documentos médicos técnicos, utilizando modelos de lenguaje comerciales y fine-tuned. Incluye funcionalidades de clasificación de textos entre "Técnico" y "Plano".

## 📋 Descripción

Esta aplicación ofrece dos funcionalidades principales:

### 1. **Generación de Resúmenes (Plain Language Summaries)**

Permite al usuario crear resúmenes en lenguaje llano de documentos médicos mediante:

- Selección de múltiples modelos (comerciales y fine-tuned)
- Clasificación previa del texto original (Técnico/Plano) para condicionar la generación
- Visualización de métricas de legibilidad del texto generado
- Comparación entre diferentes modelos

### 2. **Clasificación de Textos**

Permite clasificar textos médicos como "Técnico" o "Plano" de dos formas:

- **Por texto directo**: Ingreso manual de texto para clasificación inmediata
- **Por archivo CSV**: Carga masiva de textos para clasificación en lote

## 🏗️ Arquitectura

La aplicación se conecta a tres servicios backend:

- **API de Clasificación** (`VITE_CLASSIFICATION_DOMAIN`)
- **API de Generación** (`VITE_GENERATION_DOMAIN`)
- **API de Métricas** (`VITE_METRICS_DOMAIN`)

## 📦 Tecnologías

- **React 19** - Biblioteca de UI
- **Vite 7** - Build tool y dev server
- **Material-UI (MUI) 7** - Componentes de interfaz
- **React Router 6** - Enrutamiento
- **Axios** - Cliente HTTP
- **Papa Parse** - Procesamiento de archivos CSV

## 🚀 Desarrollo Local

### Prerrequisitos

- Node.js 22 o superior
- Yarn o npm
- APIs backend ejecutándose (clasificación, generación, métricas)

### Configuración del Entorno

1. **Clonar el repositorio y navegar al directorio web:**

```bash
cd web
```

2. **Crear archivo `.env` con las URLs de las APIs:**
   Los dominios deben correponder a las disponibles para cada servicio

```env
VITE_CLASSIFICATION_DOMAIN=http://localhost:8001
VITE_GENERATION_DOMAIN=http://localhost:8002
VITE_METRICS_DOMAIN=http://localhost:8001
```

3. **Instalar dependencias:**

```bash
yarn
# o
npm install
```

### Comandos de Desarrollo

#### Iniciar servidor de desarrollo

```bash
yarn start
# o
npm run start
```

La aplicación estará disponible en `http://localhost:5173`

#### Ejecutar linter

```bash
yarn lint
# o
npm run lint
```

## 🏭 Build para Producción

### Build Local

```bash
yarn build
# o
npm run build
```

Los archivos optimizados se generarán en el directorio `dist/`

### Build con Docker

#### Opción 1: Docker CLI

```bash
docker build \
  --build-arg VITE_CLASSIFICATION_DOMAIN=http://api.example.com:8001 \
  --build-arg VITE_GENERATION_DOMAIN=http://api.example.com:8002 \
  --build-arg VITE_METRICS_DOMAIN=http://api.example.com:8001 \
  -t medical-summaries-app \
  -f Dockerfile .
```

#### Opción 2: Docker Compose

Crear archivo `.env` en el directorio raíz:

```env
VITE_CLASSIFICATION_DOMAIN=http://api.example.com:8001
VITE_GENERATION_DOMAIN=http://api.example.com:8002
VITE_METRICS_DOMAIN=http://api.example.com:8001
```

Crear `docker-compose.yml`:

```yaml
services:
  web:
    build:
      context: .
      dockerfile: web/Dockerfile
      args:
        VITE_CLASSIFICATION_DOMAIN: ${VITE_CLASSIFICATION_DOMAIN}
        VITE_GENERATION_DOMAIN: ${VITE_GENERATION_DOMAIN}
        VITE_METRICS_DOMAIN: ${VITE_METRICS_DOMAIN}
    ports:
      - '80:80'
```

Ejecutar:

```bash
docker-compose build
docker-compose up
```

## 📂 Estructura del Proyecto

```
web/
├── public/              # Archivos estáticos
├── src/
│   ├── assets/         # Recursos (imágenes, etc.)
│   ├── components/     # Componentes reutilizables
│   │   ├── FileClassifier/    # Clasificador por archivo
│   │   ├── Layout/            # Layout principal
│   │   ├── ModelInfo/         # Información de modelos
│   │   ├── SideMenu/          # Menú lateral
│   │   └── TextClassifier/    # Clasificador por texto
│   ├── containers/     # Páginas/vistas
│   │   ├── FilePage/          # Vista de clasificación por archivo
│   │   ├── GeneratePage/      # Vista de generación
│   │   └── TextPage/          # Vista de clasificación por texto
│   ├── hooks/          # Custom hooks
│   │   ├── useClassification.js  # Hook para clasificación
│   │   ├── useGeneration.js      # Hook para generación
│   │   ├── useMetrics.js         # Hook para métricas
│   │   └── useReadability.js     # Hook para legibilidad
│   ├── types/          # Definiciones de tipos
│   ├── App.jsx         # Componente principal
│   └── main.jsx        # Punto de entrada
├── .env                # Variables de entorno (desarrollo)
├── Dockerfile          # Configuración Docker
├── nginx.conf          # Configuración Nginx
├── package.json        # Dependencias y scripts
└── vite.config.js      # Configuración Vite
```

## 🌐 Rutas de la Aplicación

- `/` - Redirige a la página de generación
- `/generar` - Página de generación de resúmenes
- `/texto` - Página de clasificación por texto directo
- `/archivo` - Página de clasificación por archivo CSV
