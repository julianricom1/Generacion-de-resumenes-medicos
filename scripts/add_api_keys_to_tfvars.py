#!/usr/bin/env python3
"""
Script para agregar API keys desde KEYS.py al archivo terraform.tfvars del generador.
Este script lee las keys desde KEYS.py y las agrega/actualiza en terraform.tfvars.
"""
import sys
import re
from pathlib import Path

# Agregar el directorio raíz al path para importar KEYS
sys.path.insert(0, str(Path(__file__).parent.parent))

try:
    from KEYS import OPENAI_API_KEY, ANTHROPIC_API_KEY
except ImportError:
    print("ERROR: No se pudo importar KEYS.py. Asegúrate de que el archivo existe en la raíz del proyecto.")
    sys.exit(1)

tfvars_file = Path(__file__).parent.parent / "terraform/environments/student/generador/terraform.tfvars"

if not tfvars_file.exists():
    print(f"ERROR: No se encontró el archivo {tfvars_file}")
    sys.exit(1)

# Leer el contenido actual
with open(tfvars_file, 'r', encoding='utf-8') as f:
    content = f.read()

# Agregar o actualizar OPENAI_API_KEY
if 'OPENAI_API_KEY' not in content:
    # Buscar USER_PREFIX y agregar OPENAI_API_KEY después
    content = re.sub(
        r'(USER_PREFIX = ".*")\n',
        r'\1\n  OPENAI_API_KEY = "' + OPENAI_API_KEY + '"\n',
        content
    )
else:
    # Actualizar el valor existente
    content = re.sub(
        r'OPENAI_API_KEY = ".*"',
        'OPENAI_API_KEY = "' + OPENAI_API_KEY + '"',
        content
    )

# Agregar o actualizar ANTHROPIC_API_KEY
if 'ANTHROPIC_API_KEY' not in content:
    # Buscar OPENAI_API_KEY y agregar ANTHROPIC_API_KEY después
    if 'OPENAI_API_KEY' in content:
        content = re.sub(
            r'(OPENAI_API_KEY = ".*")\n',
            r'\1\n  ANTHROPIC_API_KEY = "' + ANTHROPIC_API_KEY + '"\n',
            content
        )
    else:
        # Si no hay OPENAI_API_KEY, agregar después de USER_PREFIX
        content = re.sub(
            r'(USER_PREFIX = ".*")\n',
            r'\1\n  ANTHROPIC_API_KEY = "' + ANTHROPIC_API_KEY + '"\n',
            content
        )
else:
    # Actualizar el valor existente
    content = re.sub(
        r'ANTHROPIC_API_KEY = ".*"',
        'ANTHROPIC_API_KEY = "' + ANTHROPIC_API_KEY + '"',
        content
    )

# Escribir el contenido actualizado
with open(tfvars_file, 'w', encoding='utf-8') as f:
    f.write(content)

print(">> API keys agregadas/actualizadas en terraform.tfvars")

