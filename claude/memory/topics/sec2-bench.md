# SEC2 helix-egress-audit — bench y validación

> Implementado 2026-05-04 sesión #21. Componente: `~/.claude/helpers/helix-egress-audit-hook.py` (+ wrapper `.sh`) + reporter `helix-egress-report.sh`. Wired a `settings.json` PostToolUse `WebFetch|WebSearch|mcp__.*`.

---

## Diferencias con hooks pre-existentes

| Hook | Trigger | Propósito | Acción |
|---|---|---|---|
| `network-egress-hook.sh` | PreToolUse Bash | Bloquea curl/ssh fuera de allowlist (Bash) | exit 2 BLOCK |
| `injection-detector-hook.sh` | PostToolUse WebFetch/WebSearch/Read | Alerta patterns de prompt injection | stderr advisory |
| **`helix-egress-audit-hook.py` (SEC2)** | PostToolUse WebFetch/WebSearch/mcp__.* | Audit log estructurado de TODO egress + alert dominios nuevos | log JSONL + stderr advisory en new domain / spike |

SEC2 NO duplica los anteriores. Cubre el gap de:
- Audit log de TODOS los WebFetch/WebSearch (no solo con injection)
- Cobertura MCP (matcher `mcp__.*`)
- Threshold alert por first-seen domain (no por bloqueo)
- Schema log compliance-ready

---

## Smoke test (6 escenarios)

Todos pasan, exit 0 siempre:

| # | Input | Resultado esperado | Real |
|---|---|---|---|
| 1 | WebFetch known (api.anthropic.com) | log entry, no alert | ✓ |
| 2 | WebFetch new (random-new-site.example.org) | log + stderr alert + agregado a known | ✓ |
| 3 | WebFetch con `?token=ghp_secret123` | query_sanitized → `token=[REDACTED]` | ✓ |
| 4 | WebSearch con `password=hello123` | query_sanitized redacta | ✓ |
| 5 | mcp__context7__resolve-library-id | domain=`mcp:context7` path=`resolve-library-id` | ✓ |
| 6 | Read (no-egress tool) | skip (no log entry) | ✓ |

Schema verificado:
```json
{"ts":"2026-05-04T04:14:09Z","tool":"WebFetch","domain":"api.github.com",
 "path_short":"/search","source":"url",
 "query_sanitized":"q=hello&token=[REDACTED]&user=x","new_domain":false}
```

---

## Acceptance criteria (M3 SEC2)

| Criterio | Status | Evidencia |
|---|---|---|
| Threshold alert (only new/spike, NO log verbose) | PASS | stderr solo en `new_domain=true` o spike ≥20/5min. Log JSONL es estructurado, no texto verbose |
| Volumen log <50/día normal | PENDING — requiere 7d uso real | reporter muestra avg per day. Smoke test 5 entries en 1 día (sintético) |
| MCP coverage (WebFetch + WebSearch + MCP) | PASS | matcher `WebFetch\|WebSearch\|mcp__.*`. mcp__ deriva domain `mcp:<server>` |
| Schema log (domain + ts + sanitized payload) | PASS | hard rule en código. Schema documentado arriba |
| Reportes mensuales | PASS | `helix-egress-report.sh --month YYYY-MM` (manual, no cron per D2.1) |

**Nota volumen:** criterio "≤50/día" en uso real. Bench sintético no valida — requiere observación de 7d productivos. Reporter ya calcula `avg_per_active_day`.

---

## Sanitización (regex aplicada)

Pattern: `(api[_-]?key|token|password|secret|auth|bearer|session|sid|jwt)=([^&\s]+)` → `$1=[REDACTED]`

Cubre: `api_key`, `api-key`, `apikey`, `token`, `password`, `secret`, `auth`, `bearer`, `session`, `sid`, `jwt`.

**Limitación:** valores en path (no en query) no son sanitizados (ej: `/users/secret-123/`). El path se trunca a 50 chars pero no redacta. Acceptable porque urls REST suelen tener IDs no-secret en path; secrets van en query/body. Body completo NO se loguea.

---

## Operación

### Hook (automático)
Triggers en cada WebFetch/WebSearch/MCP call. Append a `~/.claude/memory/egress-audit.jsonl`. Mantiene `~/.claude/memory/egress-known-domains.txt` (dominios conocidos).

### Reporter (manual, on-demand)
```bash
# Mes actual
bash ~/.claude/helpers/helix-egress-report.sh

# Mes específico
bash ~/.claude/helpers/helix-egress-report.sh --month 2026-04

# Persistir a topic
bash ~/.claude/helpers/helix-egress-report.sh --month 2026-04 --out ~/.claude/memory/topics/egress-audit-2026-04.md
```

Output: markdown con total / days / avg, top 10 domains, tool breakdown, MCP servers, new domains tabla, daily volume con bar.

### Per D2.1 — on-demand only
NO cron, NO autoschedule. El reporter es invocación interactiva por el creator. (META2/META3 invariant cementado en CLAUDE.md global).

---

## Riesgos / TODO

1. **Volumen real desconocido:** smoke test = 5 entries. Real puede dispararse durante research-heavy. Re-medir post-7d. Si supera 50/día sostenido sin razón clara, investigar.
2. **MCP servers nuevos no listados en defaults:** `context7.com` y `claude_ai_*` están en defaults; otros MCP servers se registran como first-seen (alert una vez, luego silenciosos). Revisar cuáles se agregaron via `tail egress-known-domains.txt`.
3. **No sanitiza path:** decisión documentada arriba. Si surgen casos de secret-in-path, agregar regex específica en `_domain_from`.
4. **Hook PostToolUse cascading:** SEC2 es el 2° hook en matcher WebFetch/WebSearch (después de injection-detector). Latencia agregada no medida — ambos son Python startup. Monitorear si UX se vuelve perceptible.

---

## Histórico

- 2026-05-04 v1.0: implementación inicial. Hook PostToolUse + reporter on-demand. Smoke test 6/6 PASS. Wired en settings.json. PENDING: volumen real (7d) para validar criterio <50/d.
