# /helix-actualiza — Actualizar Análisis del Proyecto

Refresca `helix-analysis.md` comparando el estado actual del proyecto contra el análisis guardado.
Útil cuando el proyecto ha evolucionado significativamente desde el último análisis.

---

## Cuándo usar

- El proyecto lleva >30 días sin actualizar el análisis (session-start lo avisa)
- Se agregaron nuevas dependencias, servicios o módulos importantes
- Cambió el stack (nuevo framework, nueva DB, nuevo servicio)
- El mapa de riesgo está desactualizado

---

## Protocolo

### Paso 1 — Leer análisis existente

Leer `{PROJECT_ROOT}/.claude/memory/helix-analysis.md`.
Si no existe → redirigir a `/helix-analiza` (análisis inicial).

### Paso 2 — Re-detectar stack

```bash
bash ~/.claude/helpers/helix-detect-stack.sh {PROJECT_ROOT}
```

Comparar resultado con el stack guardado en el análisis.

### Paso 3 — Identificar deltas

Solo analizar lo que cambió:
- ¿Nuevas dependencias en requirements.txt o package.json?
- ¿Nuevos routers, modelos, componentes principales?
- ¿Nuevos servicios en compose.yml?
- ¿Nuevas zonas de riesgo identificadas desde el último análisis?

### Paso 4 — Actualizar selectivamente

Reescribir SOLO las secciones que cambiaron en `helix-analysis.md`.
Actualizar la fecha de generación.
Si modo vector disponible → actualizar los namespaces afectados en vector memory.

### Paso 5 — Reportar deltas al usuario

Mostrar qué cambió: "Actualicé stack (agregado Redis), 2 agentes nuevos recomendados, 1 zona de riesgo nueva."
