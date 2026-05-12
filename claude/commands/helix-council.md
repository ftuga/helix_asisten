---
description: Convoca al Helix Council (7 roles deliberativos) para decisiones arquitectónicas con audit log inmutable.
---

# /helix-council — Helix Council (deliberación de 7 roles)

Orquesta una sesión deliberativa donde 7 agentes especializados (skeptic, innovator, conservative, synthesizer, researcher, devils-advocate, arbiter) analizan una decisión a lo largo de 3 rondas y emiten un veredicto con audit log inmutable.

## Uso

```
/helix-council <trigger> <severity>
```

- `<trigger>`: descripción concisa de la decisión a debatir (entre comillas si tiene espacios).
- `<severity>`: `low` · `medium` · `high` · `critical`.

Ejemplos:

```
/helix-council "Migrar de Postgres a CockroachDB" high
/helix-council "Adoptar React 19 RC en producción" medium
/helix-council "Eliminar Capa 2 swarm del routing por costo" critical
```

## Cómo Claude lo ejecuta

El comando es un orquestador en 4 pasos. Claude principal NO delega esto a un solo agente — coordina personalmente las invocaciones porque cada rol necesita su propio Agent tool call.

### Paso 1 — `prepare`

```bash
bash $(echo ${CLAUDE_CONFIG_DIR:-$HOME/.helix})/council/scripts/helix-council.sh \
  prepare "<trigger>" <severity> [project_dir]
```

Output: `session_id` (formato `YYYYMMDDTHHMMSSZ-<rand>`) y la ruta `context-pack/<session_id>/` con:
- `context_pack.yaml` (datos del proyecto + decisión)
- `prompts/<role>.md` (uno por cada rol, ya con HELIX-LANG inyectado)
- `session_state.txt` → `PREPARED`

### Paso 2 — Round 1 (los 7 roles en paralelo)

Claude invoca los 7 agentes vía `Agent tool` en **un solo mensaje** (paralelo obligatorio, regla #10 de CLAUDE.md). El prompt de cada agente es el contenido literal de `prompts/<role>.md`. Cada agente devuelve YAML estructurado que Claude guarda en `outputs/round_1_<role>.yaml`.

Roles a invocar: `council-skeptic`, `council-innovator`, `council-conservative`, `council-synthesizer`, `council-researcher`, `council-devils-advocate`, `council-arbiter`.

### Paso 3 — `collect` + rondas 2 y 3

```bash
bash .../helix-council.sh collect <session_id> 1
```

Valida outputs Round 1. Si OK → genera prompts Round 2 (síntesis cruzada). Repetir para Round 2 → expert summons (opcional, ≤2 agentes Helix invocados por researcher) → Round 3 (devil's advocate rompe la decisión emergente).

### Paso 4 — `finalize`

```bash
bash .../helix-council.sh finalize <session_id>
```

Aplica voting rules + escribe audit log inmutable (`chmod 400`) en `council/log/<timestamp>_<session_id>.yaml`. Veredicto: `APPROVE`, `APPROVE_WITH_PRECONDITIONS`, `REJECT`, o `ESCALATE`.

## Subcomandos auxiliares

```
status <session_id>       Estado actual de una sesión
abort <session_id> <r>    Kill switch (regla R9)
list                      Sesiones recientes
```

## Hard caps (R5 de la constitución)

- Máx 3 rondas
- Máx 25 LLM calls totales
- Máx 600s wall-clock

## Documentación

- Constitución: `~/.helix/council/constitution.md` (9 reglas R1–R9)
- HELIX-LANG inter-agente: `~/.helix/council/inter-agent-language.md`
- Flujo detallado: `~/.helix/council/README.md`

## Cuándo invocarlo

- Decisiones arquitectónicas que afecten ≥2 dominios o sean difíciles de revertir.
- Cambios a la constitución/doctrina Helix.
- Trade-offs donde el creador no tiene certeza fuerte.

**No invocar** para tareas operativas, fixes de bugs, o decisiones de bajo impacto. El council cuesta tokens y wall-clock — usar con criterio.
