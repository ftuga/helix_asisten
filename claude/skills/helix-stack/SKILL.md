---
name: helix-stack
description: Manifest declarativo de agentes por proyecto. Detecta tier (small/medium/large), recomienda stack curado (técnico/extendido), persiste en .claude/memory/helix-stack.md. Invocar al iniciar trabajo en proyecto nuevo, cuando el proyecto crece de tier, o cuando el routing está sesgado a los mismos 3 agentes.
version: 0.1
status: piloto
---

# Helix Stack Manifest

Cura el conjunto de agentes activos por proyecto para que el routing no se concentre en los mismos 3-4 agentes y para asegurar cobertura de roles transversales (security, qa, ba, devops) en proyectos grandes.

Diseño completo: `~/.claude/memory/topics/stack-manifest.md`
Catálogos: `~/.claude/memory/topics/stack-catalogs.md`

## Cuándo invocar

- Proyecto nuevo sin `.claude/memory/helix-stack.md`.
- El usuario pide "definir stack del proyecto" o "qué agentes usar aquí".
- Routing está sesgado (top-3 agentes acumulan >50% invocaciones — ver `helix-route.sh audit`).
- El proyecto creció (ej: paso de medium a large por crecimiento de codebase) → re-init.

## Cuándo NO invocar

- Proyecto ya tiene manifest y no hay señales de cambio.
- Modificación trivial (agregar/quitar 1 agente) → usar `add`/`remove` directamente sin re-init.

## Flujo

### 1. Detección

```bash
bash ~/.claude/helpers/helix-stack.sh detect
```

Output JSON con:
- `tier`: small | medium | large
- `metrics`: files, loc, has_ci, has_tests, has_iac
- `base_stack`: lenguajes/frameworks detectados
- `recommended.core`: stack técnico
- `recommended.extended`: roles transversales por tier

### 2. Inicialización

Para proyecto LARGE típicamente:

```bash
bash ~/.claude/helpers/helix-stack.sh init extended
```

Para proyecto pequeño o exploratorio:

```bash
bash ~/.claude/helpers/helix-stack.sh init technical
```

Para custom (escribir manifest a mano):

```bash
bash ~/.claude/helpers/helix-stack.sh init custom
# después editar .claude/memory/helix-stack.md
```

### 3. Decisión del usuario

**Helix DEBE preguntar al usuario antes de elegir mode**, mostrando:
- tier detectado
- los dos catálogos posibles (técnico vs extendido)
- recomendación según tier

Ejemplo de prompt:
```
Detecto proyecto LARGE: TypeScript + Next.js + Python + FastAPI + Postgres
Métricas: 152 archivos, 18K LOC, has_ci=true, has_iac=true

(1) Stack técnico (solo lenguaje + framework):
    typescript-pro, frontend-developer, nextjs-architecture-expert,
    python-pro, backend-architect, postgres-pro, sql-pro

(2) Stack extendido (recomendado para LARGE):
    + code-reviewer, security-auditor, database-architect,
      architect-reviewer, qa-expert, business-analyst,
      devops-engineer, monitoring-specialist, performance-engineer

¿Cuál usar? (1) técnico | (2) extendido | (c) custom
```

NUNCA elegir por el usuario en proyectos LARGE — siempre preguntar.

### 4. Modificación

```bash
helix-stack add <agent>           # agregar a core
helix-stack remove <agent>        # mover a excluded (penalty fuerte en routing)
helix-stack promote <agent>       # extended → core
helix-stack show                  # ver manifest actual
helix-stack auto-promote-check    # detecta agentes extended con ≥3 usos (candidatos a core)
```

### Detección universal de agentes faltantes

`helix-stack.sh suggest-agents` recorre el catálogo extensible `~/.claude/memory/topics/specialized-agents-catalog.json` (7 categorías):

| Categoría | Cubre |
|---|---|
| `languages` | Rust, Go, Kotlin, Swift, Elixir, Ruby, Scala, PHP, Dart, C#, Haskell |
| `frameworks` | Vue, Svelte, Astro, Remix, Nuxt, Solid, Qwik, NestJS, Fastify, Rails, Spring, Phoenix, Actix, Gin |
| `domains` | PyTorch, TensorFlow, LangChain, HuggingFace, Spark, dbt, Kafka, Airflow, MLflow, Vector DBs, GraphQL, Prisma, tRPC, Redis, MongoDB, Elasticsearch |
| `infrastructure` | Terraform, Ansible, Pulumi, Helm, Kubernetes, ArgoCD, GitHub Actions, GitLab CI |
| `blockchain` | Solidity, Anchor, Ethers/Web3 |
| `specialized` | Unity, Godot, Unreal, Flutter, React Native, OpenAPI, AsyncAPI, OpenTelemetry |
| `compliance` | HIPAA, GDPR, PCI-DSS, SOC2, ISO27001 (detecta por keywords en README) |

**Señales de detección**: `files`, `dirs`, `manifest`, `deps_python`, `deps_node`, `deps_ruby/elixir/rust/go`, `keywords_in_readme`.

**Extensibilidad**: agregar entries al JSON sin tocar código. El usuario puede crear su propia categoría.

**Importante**: NUNCA auto-crea agente. Solo sugiere comando `agent-create` (con OK del usuario).

### Auto-promoción (Fase 2)

`helix-stack.sh auto-promote-check` lee `routing-feedback.jsonl` últimos 30d, filtra por proyecto actual, y reporta candidatos. Output JSON:
```json
{
  "candidates_for_promotion": [
    {"agent": "qa-expert", "invocations_30d": 5, "command": "helix-stack.sh promote qa-expert"}
  ]
}
```

NO promociona automáticamente — solo sugiere. La decisión queda en el usuario.

## Schema del manifest

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
  languages: [...]
  frameworks: [...]
stack:
  core: [...]
  extended: [...]
  excluded: [...]
---
```

## Integración con routing

`helix-route.sh pick` lee el manifest:
- Agentes en `stack.core` reciben `stack_match = 1.0` (boost fuerte)
- Agentes en `stack.extended` reciben `stack_match = 0.6`
- Agentes en `stack.excluded` se filtran (penalty -1.0)
- Agentes fuera del stack → `stack_match = 0` (no afecta)

## Validación

Antes de marcar manifest como completo:
1. `helix-stack show` retorna YAML válido
2. Todos los agentes en `core/extended` existen en `~/.claude/agents/`
3. `tier` matches con `metrics` (small con 200 archivos = inconsistencia → re-detect)

## Edge cases

- **Multi-proyecto en mismo repo**: cada subdirectorio puede tener su propio `.claude/memory/helix-stack.md` (PROJECT_ROOT lo respeta).
- **Agente inexistente**: el helper hace skip y registra en `missing_in_catalog` del JSON detect.
- **Cambio de tier**: si manifest dice `medium` pero detect retorna `large` → advertir al usuario, no auto-actualizar.

## Estado

- [x] Helper `helix-stack.sh` (detect/init/show/add/remove/promote)
- [x] Schema documentado
- [x] Catálogos por tier
- [ ] Integración con routing (Fase 2 de `helix-route.sh`)
- [ ] Métricas de cobertura del stack en `helix-metricas.sh`
- [ ] Auto-promoción: extended → core si se usa ≥3 veces
