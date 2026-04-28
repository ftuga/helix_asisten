# Stack Manifest — Diseño

Versión: v0.1 (2026-04-27)
Status: implementación inicial

## Problema

El routing vectorial actual (`hv search helix_agents`) trae los top-K agentes más similares al query — sin considerar el contexto del proyecto. Resultado:

- 24 de 35 agentes nunca usados
- 3 agentes (`frontend-developer`, `python-pro`, `general-purpose`) acumulan ~70% de invocaciones
- DRIFT detectado por ERL: `frontend-developer` se usa para devops/analysis, `general-purpose` para testing
- Roles transversales (security, qa, ba, devops) nunca aparecen porque no hay query que los pida explícitamente

## Solución: Stack Manifest

Cada proyecto declara su *stack curado de agentes* en `.claude/memory/helix-stack.md`. El routing filtra candidatos por este stack ANTES del top-K vectorial.

## Schema

```yaml
---
project: <nombre>
tier: small | medium | large
detected_at: YYYY-MM-DD
mode: technical | extended | custom
detected:
  files: <int>
  loc: <int>
  has_ci: bool
  has_tests: bool
  has_iac: bool
  languages: [python, typescript, ...]
  frameworks: [nextjs, fastapi, ...]
stack:
  core:
    - <agent_id>
  extended:
    - <agent_id>
  excluded:
    - <agent_id>  # explicitamente fuera (usuario dijo no aplica)
---

## Notas
[notas libres del usuario, opcional]
```

## Modos

- **`technical`**: solo `core` (stack del lenguaje + framework). Tier ignorado para roles transversales.
- **`extended`**: `core` + `extended` recomendado por tier. Recomendado para `large`.
- **`custom`**: usuario edita manualmente, Helix respeta sin cuestionar.

## Detección automática de tier

| Tier | Condiciones |
|---|---|
| `small` | <10 archivos código Y <500 LOC Y sin tests Y sin CI |
| `medium` | (10-100 archivos) O (500-10K LOC) O tiene `tests/` |
| `large` | (100+ archivos) O (10K+ LOC) O (tiene CI Y IaC) |

Archivos contados: `*.py *.ts *.tsx *.js *.go *.rs *.java *.kt *.swift`.
Excluye: `node_modules/`, `.venv/`, `__pycache__/`, `dist/`, `build/`.

## Flujo de inicialización

1. Usuario corre `bash ~/.claude/helpers/helix-stack.sh init` (o Helix sugiere al detectar ausencia de manifest en proyecto >small).
2. Helper ejecuta `detect` → JSON con tier + stack base.
3. Helper genera 2 propuestas de stack: `technical` y `extended`.
4. Helper imprime al usuario:
   ```
   Detecto proyecto LARGE: typescript + nextjs + python + fastapi + postgres
   Tier: large (152 files, 18K LOC, has_ci=true, has_iac=true)

   (1) Stack técnico:
       typescript-pro, frontend-developer, nextjs-architecture-expert,
       python-pro, backend-architect, postgres-pro, sql-pro

   (2) Stack extendido (recomendado para LARGE):
       + code-reviewer, security-auditor, database-architect,
         architect-reviewer, qa-expert, business-analyst,
         devops-engineer, monitoring-specialist

   Elige: 1 (técnico) | 2 (extendido) | c (custom)
   ```
5. Usuario elige (vía argv o prompt).
6. Helper escribe `.claude/memory/helix-stack.md`.

## Comandos del helper

```bash
helix-stack.sh detect            # solo detecta, imprime JSON
helix-stack.sh init [mode]       # crea manifest (mode: technical|extended|custom)
helix-stack.sh show              # muestra manifest actual
helix-stack.sh add <agent>       # agrega agente al stack core
helix-stack.sh remove <agent>    # mueve agente a excluded
helix-stack.sh promote <agent>   # mueve de extended a core
```

## Integración con routing

`helix-route.sh pick <domain> <query>`:
1. Lee `helix-stack.md` del proyecto si existe
2. `hv search helix_agents "$query" --limit 10`
3. Si stack existe: filtra candidatos por `stack.core ∪ stack.extended ∖ stack.excluded`
4. Si dominio en query no tiene match en stack → emite warning: `requiere <agent> que no está en stack — agregar con helix-stack add <agent>?`
5. Re-rankea con freshness + skill_quality (ver `routing-anti-bias.md`)
6. Output JSON: primary + alternatives

## Edge cases

- **Sin manifest**: routing usa catálogo full + algoritmo anti-bias estándar.
- **Manifest stale**: si proyecto creció (small→large) sin actualizar manifest, advertir y sugerir re-init.
- **Agente eliminado del catálogo global**: manifest lo mantiene pero routing lo skip-ea (warning log).
- **Multi-proyecto**: cada proyecto tiene su propio manifest. Helix global respeta el del `$PWD`.

## Métricas

- **Cobertura del stack:** % invocaciones que cayeron dentro del stack declarado
- **Drift fuera de stack:** count de invocaciones a agentes excluidos o no listados
- **Saturación:** entropy de la distribución de invocaciones (alta = bien distribuido, baja = sesgo)

## Roadmap

- [x] v0.1 — schema + helper detect/init/show
- [ ] v0.2 — integración con `helix-route.sh` (filtro por stack)
- [ ] v0.3 — métricas de cobertura/drift en `helix-metricas.sh`
- [ ] v0.4 — auto-promoción: si un agente del extended se usa ≥3 veces, ofrecer moverlo a core
- [ ] v0.5 — staleness: detectar si tier real cambió y sugerir re-init
