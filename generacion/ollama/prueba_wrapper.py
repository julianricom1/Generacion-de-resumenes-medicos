from pathlib import Path
import sys

HERE = Path(__file__).resolve()
# Sube hasta encontrar la carpeta 'metricas'
for p in [HERE] + list(HERE.parents):
    if (p / "metricas").is_dir():
        sys.path.insert(0, str(p))
        break
else:
    raise RuntimeError("No se encontró la carpeta 'metricas' en ningún ancestro.")

from metricas.metrics_client import getLoss, getRelevance, getFactuality, getReadability



O = ["orig1", "orig2"]
H = ["hum1", "hum2"]
G = ["gen1", "gen2"]

print(getLoss(O, H, G, weights=[0.25,0.25,0.2,0.15,0.15]))
print(getRelevance(O, G))
print(getFactuality(O, G))
print(getReadability(G))