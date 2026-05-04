# M2 helix-passive-capture — bench y validación

> Implementado 2026-05-04 sesión #21. Wire en `settings.json` PostToolUse(Write|Edit|MultiEdit).
> Componente `~/.claude/helpers/passive-capture-hook.py` (+ wrapper `.sh`) + review tool `passive-capture-review.sh` + skill `helix-passive-review`.

---

## Latencia hook (criterio M2)

Bench Python `time.perf_counter()`, 80 runs por escenario, payload realista vía stdin.

| Escenario | p50 | p95 | p99 | avg | criterio |
|---|---|---|---|---|---|
| POS (Edit a CLAUDE.md con keywords decisión, score=5) | 23.0ms | 41.9ms | 48.7ms | 25.1ms | <50ms hard ✓ |
| NEG (Edit a `.ts` random sin keywords, salida temprana) | 22.0ms | 28.4ms | 34.4ms | 22.0ms | <50ms hard ✓ |

**Resultado:** p99 POS = 48.7ms ≤ 50ms (criterio acceptance), bien debajo de 100ms (criterio bloqueo).

Decisión técnica: implementación inicial en bash + 2x python3 dio p99=141.8ms (over budget). Reescritura como Python directo (1 startup, regex compiladas en módulo) bajó a 48.7ms p99.

---

## Filtros de relevancia (documentados en código)

Header de `passive-capture-hook.py` declara:

- **Group A — Path matchers** (peso 1, mutuamente exclusivos)
  - A1 `~/.claude/CLAUDE.md`
  - A2 `~/.claude/memory/topics/*.md`
  - A3 `~/.claude/memory/agents/*.md`
  - A4 `~/.claude/memory/agents-index.md`
  - A5 `*/.claude/memory/helix-*.md` (proyecto)
  - A6 `~/.claude/council/*`

- **Group B — Content keyword matchers** (peso 1, no mutuamente exclusivos)
  - B1 `decidim(os|o)|decidido|decisión:|decision:`
  - B2 `cementad[ao]s?|cementing`
  - B3 `razón:|motivo:|porque`
  - B4 `vamos con|elegido|preferido`
  - B5 `DEFER|BLOQUEADO|RECHAZADO|APROBADO|ESCALATED`
  - B6 `TRANCH|FASE [0-9]`
  - B7 `council|creator|gate B[0-9]`
  - B8 `audit log|inmutable|chmod 400`

- **Group C — Tool matcher** (peso 1)
  - C1 `tool ∈ {Edit, Write, MultiEdit}`

**Threshold:** ≥2 hits combinados. Configurable vía `HELIX_M2_THRESHOLD`.

**Skiplist (auto-skip):**
`passive-captures-*.jsonl` (anti-recursión), `helix-bitacora*.md`, `evolution-log.txt`, `session-log.txt`, `/dist/`, `/node_modules/`, `/__pycache__/`, `/.git/`.

---

## Acceptance criteria (de tranch2-acceptance-criteria.md §M2)

| Criterio | Status | Evidencia |
|---|---|---|
| Captura útil (precision ≥40%) | PENDING — requiere ≥30d uso real con review batch | `passive-capture-review.sh stats` |
| Anti-noise (rejected ≤40%) | PENDING — requiere ≥30d uso real | `passive-capture-review.sh stats` |
| Latencia hook <50ms p99 | PASS | bench arriba (POS p99=48.7ms) |
| Confirm 1-line obligatorio (NUNCA captura silenciosa) | PASS | hook escribe a pending; review explícita por creator vía script. Bulk requiere flag explícito (`approve-all`/`reject-all`) que solo se invoca tras OK del usuario |
| Filtro relevancia documentado | PASS | header de `passive-capture-hook.py` con tabla |

**Bloqueos:**
- Latencia >100ms p99 → bench actual 48.7ms p99, sin riesgo
- Captura silenciosa permitida → contractualmente prohibido por diseño (review-tool es la única vía a approved/rejected)

---

## Operación

```bash
# Reviewer interface
bash ~/.claude/helpers/passive-capture-review.sh count
bash ~/.claude/helpers/passive-capture-review.sh list
bash ~/.claude/helpers/passive-capture-review.sh approve <idx|id>
bash ~/.claude/helpers/passive-capture-review.sh reject <idx|id>
bash ~/.claude/helpers/passive-capture-review.sh stats
```

**Storage:**
- `~/.claude/memory/passive-captures-pending.jsonl` (raw)
- `~/.claude/memory/passive-captures-approved.jsonl` (corpus para futura calibración M1)
- `~/.claude/memory/passive-captures-rejected.jsonl` (calibración del threshold)

**Skill invocable:** `helix-passive-review`.

---

## Próximas validaciones

- **30 días post-wire:** correr `stats` y verificar precision ≥40%, noise ≤40%. Ajustar matchers si falla.
- **Pre M1 helix-judge:** approved.jsonl alimenta corpus de calibración (decisiones reales etiquetadas por humano = ground truth).
- **Re-bench post-30d:** validar que p99 sigue <50ms con tráfico real (no sample sintético).

---

## Riesgos identificados

1. **Sample sintético del bench:** payload de prueba es chico (~200 chars). Real puede ser hasta 4KB (bound aplicado). Re-medir con sample real post-30d.
2. **stat() de path matchers:** fast en tmpfs/ssd, puede degradar si HOME en disco lento. No observado en WSL2 actual.
3. **Hooks PostToolUse en cascada:** ya hay 2 hooks en mismo matcher (bitacora, vector-sync). M2 es 3°. Si Claude Code ejecuta secuencial, latencia agregada del cascade es la suma. p99 individual está OK pero agregada puede acercarse a UX-perceptible (>200ms). Monitorear.

---

## Histórico

- 2026-05-04 v1.0: implementación inicial. Bench POS p99=48.7ms, NEG p99=34.4ms. Wired en settings.json.
