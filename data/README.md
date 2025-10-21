# Dataset de Fine-Tuning: Pares PLS-Abstract

Este dataset contiene **3,796 pares** de textos médicos (Abstract técnico → Plain Language Summary) con métricas completas de legibilidad.

## 📊 Contenido del Dataset

**Archivo**: `pls_abstract_pairs_with_metrics.csv` (30.03 MB)

### Distribución
- **Train**: 3,578 pares (94.3%)
- **Test**: 218 pares (5.7%)
- **Fuente**: Cochrane Library

## 📋 Estructura de Columnas (36 columnas)

### Columnas Esenciales
1. **document_id** - ID único del documento Cochrane
2. **source_text** - Texto técnico (Abstract) - INPUT
3. **target_text** - Texto en lenguaje plano (PLS) - OUTPUT ESPERADO
4. **split** - División del dataset ('train' o 'test')
5. **source** - Fuente de datos ('cochrane')

### Métricas Básicas
#### Texto Fuente (Abstract)
- **source_word_count** - Cantidad de palabras
- **source_sentence_count** - Cantidad de oraciones
- **source_character_count** - Cantidad de caracteres
- **source_characters_per_word** - Caracteres promedio por palabra
- **source_words_per_sentence** - Palabras promedio por oración

#### Texto Objetivo (PLS)
- **target_word_count** - Cantidad de palabras
- **target_sentence_count** - Cantidad de oraciones
- **target_character_count** - Cantidad de caracteres
- **target_characters_per_word** - Caracteres promedio por palabra
- **target_words_per_sentence** - Palabras promedio por oración

### Métricas de Legibilidad

Todas las métricas están calculadas tanto para el texto fuente (`source_*`) como para el objetivo (`target_*`):

#### Flesch Reading Ease
- **source_Flesch_Reading_Ease** - Facilidad de lectura (0-100, mayor = más fácil)
- **target_Flesch_Reading_Ease**
- **readability_improvement** - Diferencia entre target y source

#### Flesch-Kincaid Grade Level
- **source_Flesch_Kincaid_Grade** - Nivel de grado escolar requerido
- **target_Flesch_Kincaid_Grade**
- **grade_level_reduction** - Reducción de nivel (source - target)

#### SMOG Index (Simple Measure of Gobbledygook)
- **source_SMOG_Index** - Años de educación necesarios
- **target_SMOG_Index**

#### Gunning Fog Index
- **source_Gunning_Fog_Index** - Años de educación formal necesarios
- **target_Gunning_Fog_Index**

#### Coleman-Liau Index
- **source_Coleman_Liau_Index** - Nivel de grado basado en caracteres/palabras
- **target_Coleman_Liau_Index**

#### ARI (Automated Readability Index)
- **source_ARI** - Nivel de grado basado en caracteres y palabras
- **target_ARI**

#### Dale-Chall Readability Score
- **source_Dale_Chall_Index** - Dificultad basada en palabras familiares
- **target_Dale_Chall_Index**

#### LIX (Läsbarhetsindex)
- **source_LIX** - Índice de legibilidad sueco
- **target_LIX**

#### RIX (Rix Readability)
- **source_RIX** - Índice de legibilidad basado en palabras largas
- **target_RIX**

### Métricas de Comparación
- **compression_ratio** - Ratio de compresión (target_words / source_words)
  - Promedio: 0.67 (el PLS es ~33% más corto)

## 📈 Estadísticas del Dataset

### Longitud de Textos
| Métrica | Abstract (Source) | PLS (Target) |
|---------|------------------|--------------|
| Promedio palabras | 736.4 | 471.0 |
| Mínimo palabras | 277 | 252 |
| Máximo palabras | 1,900 | 1,380 |

### Legibilidad (Flesch Reading Ease)
- **Abstract promedio**: 23.32 (texto universitario/profesional)
- **PLS promedio**: 10.26 (texto más accesible)
- **Mejora**: -13.06 puntos (nota: valores más bajos pueden indicar mayor simplicidad en algunos contextos)

### Nivel de Grado (Flesch-Kincaid)
- **Abstract promedio**: 20.23 (nivel postgrado)
- **PLS promedio**: 24.99 (nivel postgrado avanzado)

## 🎯 Uso para Fine-Tuning

### Ejemplo de carga en Python

```python
import pandas as pd

# Cargar el dataset
df = pd.read_csv('pls_abstract_pairs_with_metrics.csv')

# Separar train y test
train_df = df[df['split'] == 'train']
test_df = df[df['split'] == 'test']

# Preparar para fine-tuning (formato básico)
train_pairs = [
    {
        'input': row['source_text'],
        'output': row['target_text']
    }
    for _, row in train_df.iterrows()
]
```

### Formato para diferentes frameworks

#### Para OpenAI/GPT Fine-Tuning
```python
# Formato JSONL
import json

with open('train.jsonl', 'w', encoding='utf-8') as f:
    for _, row in train_df.iterrows():
        example = {
            "messages": [
                {"role": "system", "content": "You are a medical text simplification assistant. Convert technical medical abstracts into plain language summaries."},
                {"role": "user", "content": row['source_text']},
                {"role": "assistant", "content": row['target_text']}
            ]
        }
        f.write(json.dumps(example) + '\n')
```

#### Para Hugging Face Transformers
```python
from datasets import Dataset

# Crear dataset de Hugging Face
dataset = Dataset.from_pandas(train_df[['source_text', 'target_text']])

# Opcional: renombrar columnas
dataset = dataset.rename_column('source_text', 'input')
dataset = dataset.rename_column('target_text', 'output')
```

## 📝 Notas Importantes

1. **Textos únicos**: Este dataset contiene solo pares de documentos completos (sin fragmentos o secciones acumuladas)

2. **Métricas pre-calculadas**: Todas las métricas de legibilidad ya están calculadas, evitando la necesidad de recalcularlas durante el entrenamiento

3. **Balance**: El dataset está desbalanceado hacia train (94.3% vs 5.7%), considera usar validación cruzada o crear un split de validación del conjunto de train

4. **Interpretación de métricas**:
   - Flesch Reading Ease: Mayor score = más fácil de leer
   - Todos los demás índices: Mayor score = más difícil de leer

## 🔧 Script de Generación

El dataset fue generado con el script `generate_finetuning_dataset.py` que:
- Empareja documentos únicos PLS-Abstract de la librería Cochrane
- Extrae métricas de legibilidad de los CSVs pre-procesados
- Calcula métricas de comparación entre source y target

## 📧 Contacto

Para preguntas sobre el dataset, consulta el repositorio principal del proyecto.
