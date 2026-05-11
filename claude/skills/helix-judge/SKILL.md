---
name: helix-judge
description: LLM-as-judge sobre conflictos semánticos en memoria/decisiones de Helix. Backend Ollama local (llama3.2:3b por default, override via HELIX_JUDGE_MODEL). Modes judge/scan/audit. Hard rules confidence ≥0.85, audit log 100%, anti-poisoning few-shot estático en código (CS1), NO trigger S1. Invocar cuando el creator pida "buscar conflictos", "judge X vs Y", o "audit decisiones del judge". On-demand only (D2.1) — NO scheduled.
version: 1.0
status: production
---

# Helix Judge — M1 LLM-as-judge para conflictos semánticos

LLM-as-judge contra el corpus de decisiones/memoria de Helix. Detecta pares contradictorios entre afirmaciones (ej: dos topics que dicen valores distintos para el mismo default).

Backend: **Ollama local** (D2 100% local, NO cloud LLM en core). Default: `llama3.2:3b` (rápido, accuracy adecuada con few-shot prompt).

## Hard rules (acceptance criteria M1)

1. **Confidence ≥ 0.85** para emitir verdict no trivial. Por debajo del threshold, decisión se loguea pero NO se emite como alerta. Override via `HELIX_JUDGE_CONF`.
2. **Audit log 100%** de las llamadas a `~/.claude/memory/judge-decisions.jsonl`. Schema: `{id, ts, model, source, claim_a, claim_b, verdict, confidence, reasoning, elapsed_s, emitted}`.
3. **Anti-poisoning (CS1):** los few-shot examples del prompt son ESTÁTICOS en código (`FEW_SHOT_PROMPT`). NUNCA se actualizan desde decisiones del propio judge. Updates requieren edición manual + code review.
4. **Sin feedback loop M1↔S1:** S1 está RECHAZADO en TRANCH 3. Defensivamente, el código de M1 NO tiene ningún hook a S1 ni a auto-update de skills.
5. **Audit feedback explícito:** la única fuente de calibración futura del corpus es `~/.claude/memory/judge-audit-feedback.jsonl`, poblado por el creator vía `audit-mark`.

## Cuándo invocar

- Creator pide "buscar contradicciones en memoria"
- Sospecha de drift de reglas / decisiones inconsistentes en CLAUDE.md
- Antes de un cementing importante: judge propuesto vs decisiones previas
- Audit semanal del primer mes (criterio M1: ≥4 reviews/mes con feedback)

## Cuándo NO invocar

- Decisiones triviales (ej: typos, formato) — no aplica judge semántico
- Cuando el creator no está disponible — judge produce candidates pero sólo el creator marca ok/wrong
- En medio de tarea activa — el judge tarda 2-30s; no bloquear flujo. Usar al cierre de sesión o batch.
- Como hook automático — M1 es invocación on-demand. NO se wirea a hooks (anti-CS2 circularidad: el judge no se valida a sí mismo).

## Flujo

### 1. Judge un par directo

```bash
python3 ~/.claude/helpers/helix-judge.py judge \
  "Default port is 8080" \
  "The default port is 3000"
```

Output JSON:
```json
{
  "id": "20260504T...",
  "verdict": "CONTRADICTORY",
  "confidence": 0.95,
  "emitted": true,
  "reasoning": "...",
  "elapsed_s": 3.2
}
```

`emitted=true` ⟺ verdict ∈ {CONTRADICTORY, CONSISTENT} AND confidence ≥ 0.85.

### 2. Scan corpus pairwise

```bash
# Scan últimas 20 entries de passive-captures-approved
python3 ~/.claude/helpers/helix-judge.py scan \
  ~/.claude/memory/passive-captures-approved.jsonl -n 20

# Cap a primeros 5 conflictos detectados
python3 ~/.claude/helpers/helix-judge.py scan \
  ~/.claude/memory/passive-captures-approved.jsonl --max-flags 5
```

Compara N×(N-1)/2 pares. Para corpus grande, considera `--last` chico o filtrar el corpus antes.

### 3. Audit (creator review)

```bash
# Sample random 20% de decisiones emitted para revisar
python3 ~/.claude/helpers/helix-judge.py audit-list --sample-pct 20

# Etiquetar cada decisión
python3 ~/.claude/helpers/helix-judge.py audit-mark <decision_id> ok
python3 ~/.claude/helpers/helix-judge.py audit-mark <decision_id> wrong --note "razón"

# Métricas precision/noise
python3 ~/.claude/helpers/helix-judge.py stats
```

`stats` reporta:
- precision (ok / labeled): target ≥70%
- noise (wrong / labeled): target ≤30%

### 4. Override modelo

```bash
HELIX_JUDGE_MODEL=qwen2.5-coder:7b python3 ~/.claude/helpers/helix-judge.py judge "A" "B"
```

Modelos disponibles (verificar con `ollama list`):
- `llama3.2:3b` (default, ~3-5s post-warmup)
- `qwen2.5-coder:7b` (más capaz, ~15-25s)
- `helix-scout` (custom, llama3.2 base)

## Anti-patterns

- Usar judge para "validar" decisiones que el judge mismo emitió (loop CS1) — el feedback debe venir del creator, no del judge
- Modificar `FEW_SHOT_PROMPT` con outputs del judge ("ah, esto fue un buen ejemplo, lo agrego") — viola CS1 anti-poisoning hard rule
- Actuar sobre verdicts con confidence <0.85 sin marcar audit-mark — el threshold existe por una razón
- Wirear a hook automático — M1 es on-demand only; auto-trigger introduce CS2 circularidad
- Trigger S1 (auto-update de skills) desde un verdict del judge — S1 está RECHAZADO en TRANCH 3

## Acceptance criteria status

| Criterio | Status | Evidencia |
|---|---|---|
| Detección útil ≥70% precision | PENDING | requiere ≥30d uso real con audit-mark del creator |
| Falsos positivos ≤30% | PENDING | requiere ≥30d uso real |
| Decisiones auditables 100% | PASS | `_log_decision()` siempre escribe (incluye PARSE_ERROR y below-threshold) |
| Threshold confidence ≥0.85 hard rule | PASS | `CONFIDENCE_THRESHOLD` constante; gate en `_judge_pair()` |
| Audit humano semanal primer mes | PROCESS | `audit-list` + `audit-mark` listos. Crear cron-personal del creator |
| Anti-poisoning (CS1) | PASS | `FEW_SHOT_PROMPT` estático, comentado como anti-poisoning. Solo creator edita |
| Sin feedback loop M1↔S1 | PASS | code review: ningún import/call a skill-* desde helix-judge.py |

## Notas de operación

- **Latencia:** 2-30s por par dependiendo de modelo. NO usar en hot path. Para batch grande, usar `scan` con `--max-flags` o subdividir corpus.
- **Cold start:** primer call post-suspend de Ollama puede tardar +20s. Subsequent calls warm.
- **Cost:** $0 (D2). Solo electricidad y CPU/GPU local.
- **Schema decision_id:** `<UTC timestamp>-<8 hex>` ej `20260504T042918Z-dbabd259`. Idempotente para audit-mark.
