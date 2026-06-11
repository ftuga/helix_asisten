---
name: helix-route-recommend
description: Recomienda modelo Claude (Fable 5 / Opus / Sonnet / Haiku) por dominio o agente, basado en mapping estático y data agregada en route-cost-audit.md. ADVISOR read-only — nunca modifica settings.json. Modes recommend/by-agent/list-domains/current/compare. Override via HELIX_FORCE_MODEL. Reversibility via HELIX_R1_ENABLED=0. Invocar cuando el creator pregunte "qué modelo conviene para X", antes de cambiar settings.json model, o al diseñar una nueva sesión con dominios mixtos.
version: 1.1
status: production
---

# Helix Route Recommend — R1 model advisor

Sugiere modelo Claude por dominio (security → Fable 5, frontend → Sonnet, observability → Haiku) basado en `DOMAIN_RECOS` (mapping estático en `helix-route-cost-audit.py`) + cost data agregada vía R2.

**Modelos vigentes (2026-06):**
- `claude-fable-5` — most capable widely released. $10/$50 per MTok. Reservado para high-reasoning (council, architecture, security, debug, finance, defi, product, brand).
- `claude-opus-4-8` — most capable Opus-tier. $5/$25. Alternativa cost-effective si Fable 5 es overkill.
- `claude-sonnet-4-6` — balance speed/intelligence. $3/$15. Default para production code (backend, frontend, db, infra, testing).
- `claude-haiku-4-5` — fastest. $1/$5. Pattern matching (observability).

**Read-only advisor.** Claude Code en runtime actual es single-model — el setting global vive en `~/.claude/settings.json` "model". R1 informa al creator; el creator decide el cambio manualmente.

## Hard rules

1. **NUNCA modifica `settings.json`.** Solo lee + sugiere.
2. **Override sin contención:** `HELIX_FORCE_MODEL=<m>` siempre gana.
3. **Kill switch reversible:** `HELIX_R1_ENABLED=0` → fallback `claude-sonnet-4-6`. No deja estado que limpiar.
4. **Mapping estático.** `AGENT_TO_DOMAIN` y `DOMAIN_RECOS` viven en `helix-route-cost-audit.py`. Updates requieren edición manual + code review.
5. **Audit log 100%.** Cada invocación va a `~/.claude/memory/r1-recommend-log.jsonl`.

## Cuándo invocar

- Antes de cambiar `model` en `settings.json` global o de proyecto
- Al iniciar sesión con dominios diversos (ej: backend + security + frontend)
- Cuando el creator pregunta "¿qué modelo conviene para esta tarea?"
- Para auditar: ¿estamos usando Opus en tareas que se resolverían con Sonnet?

## Cuándo NO invocar

- En medio de tarea activa (interrumpe flujo)
- Para tareas triviales (default Sonnet sirve)
- Esperando que automatice cambio de modelo (Claude Code es single-model — no se puede)

## Flujo

### 1. Recomendación por dominio

```bash
python3 "$CLAUDE_CONFIG_DIR/helpers/helix-route-recommend.py" recommend security
# → claude-fable-5 (reason: Análisis de superficie de ataque)

python3 "$CLAUDE_CONFIG_DIR/helpers/helix-route-recommend.py" recommend observability
# → claude-haiku-4-5 (reason: Pattern match en logs, alta frecuencia)
```

### 2. Recomendación por agente

```bash
python3 "$CLAUDE_CONFIG_DIR/helpers/helix-route-recommend.py" by-agent error-detective
# → debug → claude-fable-5 (root cause análisis profundo)

python3 "$CLAUDE_CONFIG_DIR/helpers/helix-route-recommend.py" by-agent frontend-developer
# → frontend → claude-sonnet-4-6
```

### 3. List + current

```bash
python3 "$CLAUDE_CONFIG_DIR/helpers/helix-route-recommend.py" list-domains
python3 "$CLAUDE_CONFIG_DIR/helpers/helix-route-recommend.py" current
# → current Claude Code model: claude-fable-5
```

### 4. Compare 2 agents (sesión mixta)

```bash
python3 "$CLAUDE_CONFIG_DIR/helpers/helix-route-recommend.py" compare error-detective frontend-developer
# → Diferent models — sugiere Fable 5 para cubrir ambos
```

### 5. Refresh audit (mensual)

```bash
python3 "$CLAUDE_CONFIG_DIR/helpers/helix-route-cost-audit.py" refresh
# Regenera $CLAUDE_CONFIG_DIR/memory/topics/route-cost-audit.md con cost + routing-feedback
```

## Override / kill switch

```bash
# Override force model
HELIX_FORCE_MODEL=claude-haiku-4-5 python3 "$CLAUDE_CONFIG_DIR/helpers/helix-route-recommend.py" recommend security
# → claude-haiku-4-5 (source=force)

# Disable R1 entirely → fallback Sonnet
HELIX_R1_ENABLED=0 python3 "$CLAUDE_CONFIG_DIR/helpers/helix-route-recommend.py" recommend security
# → claude-sonnet-4-6 (source=disabled)
```

## Acceptance criteria status

| Criterio | Status | Evidencia |
|---|---|---|
| Pre-audit costo poblado | PASS | `topics/route-cost-audit.md` con 5 secciones (cost+volume+recos+caveats+gate) |
| Override `HELIX_FORCE_MODEL` | PASS | smoke test |
| Reversibility (`HELIX_R1_ENABLED=0` ignora reco) | PASS | smoke test, fallback Sonnet |
| Audit mensual ($/dominio + accuracy/dominio) | PASS | `helix-cost-rollup.sh` mensual + `helix-route-cost-audit.py refresh` |
| Sin regresión latencia (p99 ≤ baseline + 20%) | N/A | R1 es read-only advisor; no impacta hot path de Claude Code |

## Anti-patterns

- Modificar `settings.json` desde R1 (rompe hard rule "advisor only")
- Updatear `AGENT_TO_DOMAIN` o `DOMAIN_RECOS` en runtime (rompe anti-poisoning analogous a M1 CS1)
- Cambiar el modelo global "porque R1 lo dijo" sin probar (R1 es heurístico — el creator decide tras evidencia)
- Wirear como hook automático que cambia setting sin OK (CS2 circularidad)

## Limitaciones

1. `routing-feedback.jsonl` no captura modelo por agent call → cross-join completo no posible. Heurísticas son educated guesses.
2. Single-model setting de Claude Code en runtime → R1 no puede "rotar" modelo por tarea. Solo informa.
3. Mapping incompleto para agentes nuevos. Cada agente nuevo requiere agregar entry en `AGENT_TO_DOMAIN`.
4. Recomendaciones subjetivas — `DOMAIN_RECOS` es mejor effort, no benchmark validado. v2.0 podría agregar A/B framework.
