# M1 helix-judge — bench y validación

> Implementado 2026-05-04 sesión #21. Componente: `~/.claude/helpers/helix-judge.py` + skill `helix-judge`. Backend: Ollama local (llama3.2:3b default).

---

## Acceptance criteria (M1)

| Criterio | Status | Evidencia |
|---|---|---|
| Detección útil ≥70% precision | PENDING — requiere ≥30d audit-mark del creator | `helix-judge.py stats` |
| Falsos positivos ≤30% | PENDING | mismo |
| Decisiones auditables 100% | PASS | `_log_decision()` siempre se invoca |
| Threshold confidence ≥0.85 hard rule | PASS | constante `CONFIDENCE_THRESHOLD` + gate en `_judge_pair()` |
| Audit humano semanal primer mes | PROCESS | flujo listo (audit-list + audit-mark) |
| Anti-poisoning (CS1) | PASS | `FEW_SHOT_PROMPT` estático, comentado como hard rule |
| Sin feedback loop M1↔S1 | PASS | code review: `grep -E "skill-evolve\|s1_update" helix-judge.py` → no matches |

**Bloqueo:** "precision <70% OR CS1 anti-poisoning no se cumple" → no aplican en v1.0.

---

## Smoke test (4 escenarios)

llama3.2:3b con few-shot prompt + `--format json`:

| # | Input A | Input B | Expected | Actual | conf | emitted | elapsed |
|---|---|---|---|---|---|---|---|
| 1 | `HELIX_M3_FUZZY_THRESHOLD default 0.75` | `Default fuzzy threshold for M3 is 0.5` | CONTRADICTORY | CONTRADICTORY | 0.93 | true | 3.96s |
| 2 | `API /users supports POST` | `Users endpoint accepts POST` | CONSISTENT | CONSISTENT | 0.95 | true | 2.45s |
| 3 | `Build uses Vite` | `Coffee brewed at 195F` | UNRELATED | UNRELATED | 0.95 | false | 1.89s |
| 4 | `Logs kept 7 days` | `Old logs eventually rotated` | borderline | CONSISTENT | 0.93 | true | 2.17s |

**Acuerdo con expectativa: 4/4** (test 4 es razonablemente "consistent" — los logs eventualmente se rotan SÍ es compatible con kept-7-days).

---

## Audit workflow validado

```bash
# 1. List decisiones emitted
python3 helix-judge.py audit-list --sample-pct 100

# 2. Marcar
python3 helix-judge.py audit-mark <id> ok
python3 helix-judge.py audit-mark <id> wrong --note "..."

# 3. Métricas
python3 helix-judge.py stats
```

Reportes correctos: `precision = ok/labeled`, `noise = wrong/labeled`. Threshold checks PASS/FAIL en stdout.

---

## Comparación de modelos (warm cache, par del test 1)

| Modelo | Tiempo | Resultado | conf |
|---|---|---|---|
| llama3.2:3b | ~4s | CONTRADICTORY | 0.93 |
| qwen2.5-coder:7b | ~22s | CONTRADICTORY | 0.95 |
| llama3.2:3b (sin few-shot) | ~9s | CONSISTENT (incorrecto) | 0.7 |

**Decisión:** llama3.2:3b por default (3-5x más rápido, accuracy adecuada con few-shot prompt). Override a qwen disponible via `HELIX_JUDGE_MODEL=qwen2.5-coder:7b`.

**Lección crítica:** sin few-shot, llama3.2:3b respondió INCORRECTAMENTE a la contradicción de test 1. Few-shot prompt es ESENCIAL — eso explica por qué `FEW_SHOT_PROMPT` es estático en código y por qué CS1 anti-poisoning protege específicamente esa estructura.

---

## Schema audit log

`~/.claude/memory/judge-decisions.jsonl`:
```json
{
  "id": "20260504T042918Z-dbabd259",
  "ts": "2026-05-04T04:29:18Z",
  "model": "llama3.2:3b",
  "source": "manual" | "scan:<file>:<i>,<j>",
  "claim_a": "...",
  "claim_b": "...",
  "verdict": "CONTRADICTORY|CONSISTENT|UNRELATED|PARSE_ERROR",
  "confidence": 0.93,
  "reasoning": "...",
  "elapsed_s": 3.96,
  "emitted": true
}
```

`~/.claude/memory/judge-audit-feedback.jsonl`:
```json
{"ts": "2026-05-04T04:30:00Z", "decision_id": "20260504T...", "label": "ok|wrong", "note": "..."}
```

Last label per decision_id wins en `stats`.

---

## Anti-poisoning (CS1) — code review

| Check | Resultado |
|---|---|
| `FEW_SHOT_PROMPT` declarado como constante module-level | ✓ |
| Comentario "STATIC ... NEVER updated from judge output" presente | ✓ |
| Ningún call que escriba a `helix-judge.py` desde el propio script | ✓ |
| Ningún call que actualice `FEW_SHOT_PROMPT` en runtime | ✓ |
| Ninguna lectura de `judge-decisions.jsonl` para construir el prompt | ✓ |

`audit-feedback.jsonl` puede usarse en versiones futuras para *validar* la calibración (no para retraining automático). Updates al prompt requieren intervención manual del creator + code review.

---

## Sin feedback loop M1↔S1 — code review

```bash
grep -nE "skill[\-_]evolve|s1_update|auto[\-_]update" ~/.claude/helpers/helix-judge.py
# (no matches)
```

S1 (skill auto-update) está RECHAZADO en TRANCH 3 (decisión council). Defensivamente, el código de M1 no tiene paths a S1 incluso si S1 existiera.

---

## Limitaciones v1.0 (documentadas)

1. **Latencia 2-30s/par** — NO viable para hooks automáticos. M1 es on-demand only.
2. **Scan O(N²)** — corpus de 100 entries = 4950 pares = mucho tiempo. Usar `--last N` para bound.
3. **Modelos disponibles asumen Ollama instalado** — sin Ollama, M1 no funciona (D2 hard requirement).
4. **No detecta contradicción contextual sin claims explícitas** — judge funciona sobre afirmaciones; no extrae claims de prosa larga.
5. **Few-shot prompt en inglés** — judge sobre afirmaciones en español funciona pero accuracy puede degradarse. v1.1 podría agregar ejemplos bilingües si hay evidencia.

---

## Operación

```bash
# Judge directo
python3 ~/.claude/helpers/helix-judge.py judge "A" "B"

# Scan corpus
python3 ~/.claude/helpers/helix-judge.py scan ~/.claude/memory/passive-captures-approved.jsonl -n 20

# Audit
python3 ~/.claude/helpers/helix-judge.py audit-list --sample-pct 20
python3 ~/.claude/helpers/helix-judge.py audit-mark <id> ok
python3 ~/.claude/helpers/helix-judge.py stats

# Override modelo
HELIX_JUDGE_MODEL=qwen2.5-coder:7b python3 ~/.claude/helpers/helix-judge.py judge "A" "B"
HELIX_JUDGE_CONF=0.90 python3 ~/.claude/helpers/helix-judge.py judge "A" "B"   # threshold más estricto
```

---

## Histórico

- 2026-05-04 v1.0: implementación inicial. Backend Ollama llama3.2:3b. Few-shot prompt anti-poisoning. Smoke test 4/4 acuerdan con expectativa. Audit workflow validado. Latencia 2-4s post-warmup. PENDING precision/noise stats con 30d uso real.
