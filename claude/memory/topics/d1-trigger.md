# D1' multi-domain trigger — TRANCH 1 closure

> Implementado 2026-05-04 sesión #21. Cierra el caveat del plan v4 D1':
> *"discontinuar Ruflo APROBADO con prerequisito: diseñar trigger Capa 2 propio antes de cementar uso"*.

---

## Problema que resuelve

CLAUDE.md describe la regla "2+ dominios → Capa 2 propia" pero hasta hoy NO había hook que la materializara. Sin ese trigger, "2+ dominios" caía en el antipattern explícitamente registrado en evolution #58:

> "NUNCA múltiples Agent tool en paralelo para 2+ dominios — son invisibles en ruflow. Usar Capa 2."

El antipattern es invisible a la observabilidad: cada `Agent` tool se ejecuta en su propio sandbox, sin coordinación visible. La Capa 2 propia (swarm minimalista — diseño TRANCH 3 I5) ofrece visibilidad pero requiere trigger explícito.

**D1' v1.0** introduce el trigger como **advisory**: detecta intent multi-dominio en el prompt del `Agent` tool y emite stderr advisory. NO bloquea (advisory mode primero).

---

## Implementación

`~/.claude/helpers/helix-multidomain-trigger.py` (+ wrapper `.sh`):

- **Trigger:** PreToolUse(Agent)
- **Detección:** keyword groups por dominio (11 dominios: backend, frontend, db, security, infra, testing, debug, ui, performance, data, mlops). Match case-insensitive whole-word.
- **Threshold:** ≥2 dominios → advisory. Configurable via `HELIX_D1_THRESHOLD`.
- **Reversibility:** `HELIX_D1_TRIGGER_ENABLED=0` → skip.
- **Audit:** `~/.claude/memory/d1-multidomain-detections.jsonl` con `{ts, subagent_type, description, domains_detected, domain_count, advised}`.

### Anti-poisoning

`DOMAIN_KEYWORDS` es estático en código (paralelo a M1 CS1 / R1). Updates requieren edición manual + code review. No se modifica desde detecciones del propio hook.

---

## Smoke test (4/4 PASS)

| # | Input | Esperado | Real |
|---|---|---|---|
| 1 | "Implementa endpoint FastAPI con auth JWT, componente React, OWASP top 10" | trigger (3 dominios: backend+frontend+security) | advisory emitida ✓ |
| 2 | "Componente React con Tailwind y useState" | no trigger (1 dominio: frontend) | no advisory ✓ |
| 3 | Caso 1 con `HELIX_D1_TRIGGER_ENABLED=0` | no advisory (kill switch) | no advisory ✓ |
| 4 | Tool != Agent (Bash/Read/Write) | skip | skip ✓ |

---

## Latencia

50 runs por escenario, payload realista:

| Escenario | p50 | p95 | p99 |
|---|---|---|---|
| Trigger (3 dominios match) | 41.4ms | 52.6ms | 58.0ms |
| No trigger (1 dominio) | 38.9ms | 47.5ms | 66.7ms |
| Kill switch (early exit) | 33.7ms | 44.2ms | 47.2ms |

**Acceptable:** PreToolUse Agent ya tiene latency intrínseca de Agent tool (segundos+). +60ms p99 del hook es invisible.

---

## Wire en settings.json

```json
"PreToolUse": [
  {
    "matcher": "Agent",
    "hooks": [
      {"command": "bash \"$HOME/.claude/helpers/routing-check-hook.sh\""},
      {"command": "bash \"$HOME/.claude/helpers/helix-lang-trigger-hook.sh\""},
      {"command": "bash \"$HOME/.claude/helpers/helix-multidomain-trigger.sh\""}
    ]
  }
]
```

3° hook después de routing-check (anti-bias) y helix-lang-trigger (compresión).

---

## Diseño de Capa 2 propia (siguiente paso, NO incluido en D1')

D1' v1.0 detecta y advisa. La construcción de la Capa 2 propia minimalista (swarm sin ruflo) es trabajo aparte:

- **Scope futuro:** orquestador bash que recibe N agentes + tareas paralelas + agrega outputs
- **NO TS/Node** (D3 — bash+Python core)
- **Visible en ruflow** (logs estructurados)
- **Sin lock-in claude-flow**

Eso es candidato a TRANCH 3 si surge demanda real (señal: muchas detecciones D1' con creator confirmando que necesita orquestación).

**Por ahora:** D1' resuelve el caveat del plan v4 (trigger existe). El uso real en TRANCH 2 ya fue advisor — el creator decide.

---

## Reversibility / kill switch

```bash
# Disable globally
export HELIX_D1_TRIGGER_ENABLED=0

# Or per-call
HELIX_D1_TRIGGER_ENABLED=0 ...

# Ajustar threshold (ej: solo flag con ≥3 dominios para reducir ruido)
export HELIX_D1_THRESHOLD=3
```

Sin estado persistente. Removing the script removes D1' entirely.

---

## Acceptance criteria (caveat D1' del plan v4)

| Criterio | Status |
|---|---|
| Trigger Capa 2 propio diseñado | PASS — hook implementado |
| ANTES de cementar uso de Capa 2 | PASS — D1' es advisory; cementing real de Capa 2 propia (orquestador) queda separado, candidate TRANCH 3 |
| Reversibility | PASS — env var |
| Audit | PASS — JSONL log |

**Plan v4 TRANCH 1 caveat D1' CERRADO.**

---

## Histórico

- 2026-05-04 v1.0: implementación inicial. Hook PreToolUse(Agent) con 11 grupos de dominios, threshold ≥2, advisory mode. Smoke test 4/4 PASS. p99 58-67ms. Wired en settings.json. Closes plan v4 D1' caveat.
