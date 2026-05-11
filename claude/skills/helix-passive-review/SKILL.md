---
name: helix-passive-review
description: Revisar capturas pasivas pendientes (M2 helix-passive-capture). El hook PostToolUse detecta decisiones no-triviales y las guarda en passive-captures-pending.jsonl. Esta skill las muestra en batch y permite que el creator marque cada una como aprobada (válida para futura consolidación) o rechazada (calibra threshold). NUNCA mueve sin acción explícita. Invocar al final de sesión, cuando el usuario diga "revisa capturas" o "passive-review", o si session-start reporta pendings.
version: 1.0
status: production
---

# Helix Passive Review — Revisión de capturas M2

`M2 helix-passive-capture` es un hook `PostToolUse(Write|Edit|MultiEdit)` que detecta decisiones no-triviales por filtros documentados (path Helix + keywords decisión + tool match, threshold ≥2). Cada match va a `~/.claude/memory/passive-captures-pending.jsonl`.

Esta skill es la **única vía** de mover entries a `approved` (corpus para futura calibración M1 helix-judge) o `rejected` (calibra threshold + falsos positivos del hook).

**Regla dura:** NUNCA captura silenciosa. NUNCA classify silencioso. Cada entry pendiente requiere acción explícita del creator.

## Cuándo invocar

- Al final de sesión si hay capturas pendientes (`pending count > 0`)
- Cuando el usuario pide "revisa capturas", "passive review", "review M2"
- Si session-start reporta `[HELIX-SUGGEST-PASSIVE-REVIEW]` (futuro hook)
- Antes de evaluar criterios M2 (precision ≥40%, noise ≤40%)

## Cuándo NO invocar

- Pending vacío (verificar con `count` antes)
- En medio de tarea activa — interrumpe flujo. Esperar al cierre.
- Sesión exploratoria sin escrituras significativas

## Flujo

### 1. Inspeccionar pending

```bash
bash ~/.claude/helpers/passive-capture-review.sh count   # cuántos hay
bash ~/.claude/helpers/passive-capture-review.sh list    # detalle con índices
```

`list` imprime cada entry con:
- `[idx]` índice 1-based
- timestamp + tool
- archivo (acortado a `~/.claude/...`)
- score + matchers hit (ej `A1,C1,B1,B6`)
- snippet (primera línea con keyword)
- id único

### 2. Clasificar entry por entry

```bash
bash ~/.claude/helpers/passive-capture-review.sh approve 3
bash ~/.claude/helpers/passive-capture-review.sh reject 7
```

Acepta `<idx>` (1-based) o `<id>` completo. Mueve a `approved.jsonl` o `rejected.jsonl` y elimina de pending.

### 3. Bulk si el creator confirma

```bash
bash ~/.claude/helpers/passive-capture-review.sh approve-all   # confirma TODAS
bash ~/.claude/helpers/passive-capture-review.sh reject-all    # rechaza TODAS
```

Solo después de que el creator dijo explícitamente "todas válidas" o "todas ruido". Helix nunca debe asumir.

### 4. Medir contra criterios M2

```bash
bash ~/.claude/helpers/passive-capture-review.sh stats
```

Reporta:
- `precision` = approved / (approved + rejected). Target ≥40%
- `noise` = rejected / (approved + rejected). Target ≤40%
- pending sin clasificar

Si `precision < 40%` durante 30 días → ajustar `HELIX_M2_THRESHOLD` (subir de 2 a 3) o agregar matchers.
Si `noise > 40%` → quitar matchers ruidosos del hook.

## Schema de entry (JSONL)

```json
{
  "id": "20260504T040000Z-abc12345",
  "ts": "2026-05-04T04:00:00Z",
  "tool": "Edit|Write|MultiEdit",
  "file": "/abs/path/to/file",
  "matchers_hit": ["A1","C1","B1","B6"],
  "score": 4,
  "threshold": 2,
  "snippet": "...primera línea con keyword...",
  "session": "20260504-040000"
}
```

## Housekeeping

```bash
bash ~/.claude/helpers/passive-capture-review.sh purge-approved-older 90
```

Limpia approved más viejos que N días. Rejected NO se purga (calibración del hook a futuro).

## Anti-patterns

- Auto-aprobar sin pedir OK al creator (rompe "confirm 1-line obligatorio")
- Procesar en bulk basándose en heurística (rompe contrato — solo creator decide bulk)
- Modificar `approved.jsonl` manualmente sin pasar por el script (rompe stats)
- Subir `HELIX_M2_THRESHOLD` sin medir stats primero (no es ajuste justificado sin data)

## Acceptance criteria M2 (de tranch2-acceptance-criteria.md)

| Criterio | Métrica | Umbral | Validador |
|---|---|---|---|
| Captura útil | precision en stats | ≥40% | creator manual |
| Anti-noise | noise rate en stats | ≤40% | creator manual |
| Latencia hook | p99 PostToolUse | <50ms | bench (DONE: 48.7ms POS) |
| Confirm 1-line | NUNCA captura silenciosa | hard rule | code review |
| Filtro relevancia documentado | matchers en header del hook | sí | code review |

Bench inicial documentado en `~/.claude/memory/topics/m2-bench.md` (a crear post-30d con sample real).
