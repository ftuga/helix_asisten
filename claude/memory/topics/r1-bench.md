# R1 helix-route-recommend — bench y validación

> Implementado 2026-05-04 sesión #21. Componentes:
> - `~/.claude/helpers/helix-route-cost-audit.py` — regenera `topics/route-cost-audit.md`
> - `~/.claude/helpers/helix-route-recommend.py` — advisor read-only
> - `~/.claude/skills/helix-route-recommend/SKILL.md` — invocable

---

## Acceptance criteria (R1)

| Criterio | Status | Evidencia |
|---|---|---|
| Pre-audit costo por modelo/dominio (tabla poblada antes de roll out) | PASS | `topics/route-cost-audit.md` regenerado, 5 secciones con cost+volumen+recos+caveats+gate |
| Override manual via env var `HELIX_FORCE_MODEL` | PASS | smoke test: `HELIX_FORCE_MODEL=claude-haiku-4-5` retorna haiku con `source=force` |
| Reversibilidad (desactivar = ignorar routing) | PASS | smoke test: `HELIX_R1_ENABLED=0` retorna fallback Sonnet con `source=disabled`. Sin estado persistente |
| Audit mensual ($/dominio + accuracy/dominio) | PASS | `helix-cost-rollup.sh` (existente) + `helix-route-cost-audit.py refresh` mensual on-demand |
| Sin regresión latencia (p99 ≤ baseline + 20%) | N/A — advisor read-only | R1 NO está en el hot path de tool calls. Se invoca on-demand (skill/cli). Latencia advisor: <100ms (sin Ollama call) |

**Bloqueo declarado:** "pre-audit costo no poblado → no roll-out" → **NO aplica**, pre-audit está poblado y documentado.

---

## Smoke test (8 escenarios)

| # | Comando | Resultado esperado | Real |
|---|---|---|---|
| 1 | `recommend security` | opus-4-7, source=recos | opus-4-7 ✓ |
| 2 | `recommend frontend` | sonnet-4-6, source=recos | sonnet-4-6 ✓ |
| 3 | `recommend observability` | haiku-4-5, source=recos | haiku-4-5 ✓ |
| 4 | `by-agent error-detective` | debug → opus-4-7 | opus-4-7 ✓ |
| 5 | `by-agent council-skeptic` | council → opus-4-7 | opus-4-7 ✓ |
| 6 | `current` | lee settings.json model | claude-opus-4-7 ✓ |
| 7 | `HELIX_FORCE_MODEL=haiku-4-5 recommend security` | haiku-4-5 source=force | haiku-4-5 ✓ |
| 8 | `HELIX_R1_ENABLED=0 recommend security` | sonnet-4-6 source=disabled | sonnet-4-6 ✓ |
| 9 | `compare error-detective frontend-developer` | 2 modelos diferentes, warning | warning emitido ✓ |
| 10 | `recommend invented-xyz` | fallback sonnet | sonnet-4-6 source=fallback ✓ |

**10/10 PASS.**

---

## Pre-audit data (snapshot al cierre)

`route-cost-audit.md` regenerado con:

- **Sección 1 — Cost por modelo+proyecto (R2):** $7007.35 USD acumulado, 5 modelos × 14 proyectos. helix-asisten = $1064 (opus) + $58 (sonnet).
- **Sección 2 — Volumen por dominio:** 110 routing entries, 15 dominios distintos. Top: council(41), frontend(26), backend(12), general(10), ui(5).
- **Sección 3 — Recomendaciones:** 25 dominios mapeados, 8 a Opus, 16 a Sonnet, 1 a Haiku.
- **Sección 4 — Caveats explícitos** sobre limitaciones de la data (success rate ~100% sub-calibrado, no model-per-call, mapping incompleto).
- **Sección 5 — Gate B1 #2 closure** ref audit log inmutable.

---

## Compliance con hard rules

| Rule | Verificación |
|---|---|
| Read-only (no modifica settings.json) | `grep -E "settings\.json.*write\|json\.dump\(settings" helix-route-recommend.py` → no matches |
| Audit log 100% | cada cmd_* llama `_log()`; smoke test confirma 3+ entries en `r1-recommend-log.jsonl` |
| Anti-poisoning estático (paralelo M1 CS1) | `AGENT_TO_DOMAIN` y `DOMAIN_RECOS` declarados como constantes module-level en `helix-route-cost-audit.py`. Documentado en docstring |
| Override hard wins | `_resolve()` consulta `_force_model()` ANTES de R1 enabled check |
| Kill switch sin estado | `HELIX_R1_ENABLED=0` → no escribe ni lee config persistente, simplemente fallback en runtime |

---

## Comparación con criterios v1.0 vs v2.0

v1.0 actual:
- Heurístico DOMAIN_RECOS (manual mapping)
- Sin A/B testing
- Sin model-per-call observado
- Single-model runtime de Claude Code = recomendaciones son advisor, no router

v2.0 deseable (deferred):
- Cross-join real cuando Claude Code soporte model-per-tool-call
- A/B framework: comparar opus vs sonnet en mismo dominio, medir output quality
- Routing automático SOLO con feature flag explícito

Decisión actual: v1.0 cubre TRANCH 2 R1 acceptance. v2.0 entra en TRANCH 3 si surge evidencia de necesidad.

---

## Operación

### Regenerar audit (mensual)
```bash
python3 ~/.claude/helpers/helix-route-cost-audit.py refresh
```

### Recomendaciones interactivas
```bash
python3 ~/.claude/helpers/helix-route-recommend.py recommend <domain>
python3 ~/.claude/helpers/helix-route-recommend.py by-agent <agent>
python3 ~/.claude/helpers/helix-route-recommend.py list-domains
python3 ~/.claude/helpers/helix-route-recommend.py current
python3 ~/.claude/helpers/helix-route-recommend.py compare <agent_a> <agent_b>
```

### Override / kill
```bash
HELIX_FORCE_MODEL=claude-haiku-4-5 ...
HELIX_R1_ENABLED=0 ...
```

---

## Histórico

- 2026-05-04 v1.0: implementación inicial. Pre-audit poblado (route-cost-audit.md augmented). Advisor read-only con override + kill switch + audit log 100%. 10/10 smoke tests PASS. **TRANCH 2 cerrado: 6/6 done.**
