# /helix-actualiza — Actualizar Análisis + Mantenimiento de Helix

Refresca el análisis del proyecto Y realiza mantenimiento estructural de Helix
(CLAUDE.md, memoria, logs). Es el comando de "salud general" — no solo actualiza
el análisis, sino que deja todo compacto y eficiente para las próximas sesiones.

---

## Cuándo usar

- El proyecto lleva >30 días sin actualizar el análisis (session-start lo avisa)
- CLAUDE.md está sobre el límite de líneas (self-check lo detecta)
- Se agregaron nuevas dependencias, servicios o módulos importantes
- Querés asegurarte de que Helix esté liviano antes de una sesión intensa

---

## Protocolo

### Paso A — Mantenimiento de CLAUDE.md (SIEMPRE, antes de todo)

```bash
wc -l ~/.claude/CLAUDE.md
```

- Si supera 180 líneas → ejecutar `bash ~/.claude/compress.sh`
- Si sigue >200 después de compress → mover secciones de detalle a topics:
  - Entradas de EVOLUCIONES con >6 semanas → `~/.claude/memory/topics/evolution-history.md`
  - Entradas de SESIONES antiguas → `~/.claude/memory/sessions.md`
  - Zonas de riesgo resueltas → `~/.claude/memory/topics/resolved-risks.md`
- Objetivo: dejar CLAUDE.md en ≤180 líneas. Reportar: "CLAUDE.md: 268 → 165 líneas"

Si el proyecto tiene CLAUDE.md propio → aplicar la misma lógica.

### Paso B — Mantenimiento de bitácora

Si `helix-bitacora.md` existe y tiene >50 filas en "Cambios Realizados":
- Archivar las filas más antiguas (>30 días) a `helix-bitacora-archivo.md`
- Dejar solo las últimas 30 filas en la tabla activa
- Reportar cuántas entradas se archivaron

### Paso C — Re-detectar stack del proyecto

```bash
bash ~/.claude/helpers/helix-detect-stack.sh {PROJECT_ROOT}
```

Comparar con el stack guardado en `helix-analysis.md`.
Si no existe análisis → redirigir a `/helix-analiza`.

### Paso D — Identificar deltas del proyecto

Solo analizar lo que cambió desde el último análisis:
- ¿Nuevas dependencias en requirements.txt / package.json?
- ¿Nuevos routers, modelos, componentes principales?
- ¿Nuevos servicios en compose.yml?
- ¿Nuevas zonas de riesgo identificadas?

### Paso E — Actualizar selectivamente

Reescribir SOLO las secciones que cambiaron en `helix-analysis.md`.
Actualizar fecha de generación.
Si modo vector disponible → actualizar namespaces afectados en vector memory.

### Paso F — Actualizar helix-team.md si el stack cambió

Si el Paso D detectó nuevos componentes en el stack:

1. Leer `{PROJECT_ROOT}/.claude/memory/helix-team.md`
2. Para cada componente nuevo → verificar si ya hay agente mapeado para ese dominio
3. Si falta agente → agregar fila en "Equipo Activo"
4. Si hay nuevo MCP que aplica → agregarlo en "MCPs Activos"
5. Si hay nuevas dependencias entre agentes → actualizar "Output Contracts"
6. Guardar helix-team.md actualizado

Si no hubo cambios en el stack → skip, reportar "Equipo sin cambios".

### Paso G — Reportar al usuario

Resumen compacto de todo lo que se hizo:
```
✅ CLAUDE.md: 268 → 165 líneas
✅ Bitácora: 12 entradas antiguas archivadas
✅ Stack: sin cambios / +Redis detectado
✅ Equipo: sin cambios / +monitoring-specialist (Redis), +context7 MCP
✅ Análisis: actualizado (agregado Redis, 1 zona de riesgo nueva)
```
