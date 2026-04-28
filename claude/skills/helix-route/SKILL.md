---
name: helix-route
description: Selección de agentes con anti-bias (exploración estructurada) y stack-aware (filtra por manifest del proyecto). Combina similitud vectorial + freshness (anti-explotación) + skill_quality + stack_match. Invocar antes de usar Agent tool en tareas no-triviales para validar la elección de agente.
version: 0.1
status: piloto
---

# Helix Route — Anti-bias routing

Reemplaza la búsqueda vectorial pura (`hv search helix_agents`) con un scoring multi-criterio que combate el sesgo hacia los mismos 3-4 agentes y respeta el stack curado del proyecto.

Diseño: `~/.claude/memory/topics/routing-anti-bias.md`

## Cuándo invocar

- Antes de usar el `Agent` tool en tareas no-triviales (≥2 dominios, refactor, decisión de arquitectura).
- Después de `helix-stack init` para validar que el routing usa el manifest.
- Periódicamente para auditar cobertura del catálogo (`helix-route audit`).

## Cuándo NO invocar

- Reglas duras del CLAUDE.md (siempre `error-detective` para bug, siempre `code-reviewer` pre-cierre) — no requieren routing.
- Tareas triviales con dominio obvio (1 archivo, 1 dominio).

## Comandos

### `pick` — selecciona agente

```bash
bash ~/.claude/helpers/helix-route.sh pick <domain> "<query>" [epsilon]
```

`<domain>`: testing | devops | security | database | frontend | backend | ml | api | error | generic
`<query>`: descripción de la tarea (lo que iría como prompt al agente)
`[epsilon]`: probabilidad de exploración (default 0.1)

**Output JSON:**
```json
{
  "primary": {
    "agent": "test-engineer",
    "score": 0.72,
    "similarity": 0.81,
    "freshness": 1.0,
    "skill_quality": 0.5,
    "stack_match": 0.6,
    "invocations_30d": 0,
    "epsilon_pick": false
  },
  "alternatives": [...],
  "warnings": [],
  "config": {
    "domain": "testing",
    "epsilon": 0.1,
    "weights": {...},
    "stack_loaded": true
  }
}
```

### `--shadow` (Fase 2) — modo dry-run

```bash
bash ~/.claude/helpers/helix-route.sh pick testing "tarea X" 0.1 --shadow
```

Calcula la recomendación pero NO la imprime al detalle — la registra en `~/.claude/memory/routing-shadow.jsonl`. Útil para validación 1 semana antes de activar el hook PreToolUse en producción.

### `shadow-report` — análisis de modo shadow

```bash
bash ~/.claude/helpers/helix-route.sh shadow-report
```

Reporta últimos 7 días de picks en sombra: distribución por dominio, primarios elegidos, tasa de epsilon-pick. Para validación: comparar contra `routing-feedback.jsonl` real — si convergen ≥90%, activar hook PreToolUse.

### `audit` — métricas de bias

```bash
bash ~/.claude/helpers/helix-route.sh audit
```

Reporta:
- `coverage_ratio`: agentes únicos invocados / total catálogo (objetivo ≥0.5)
- `top3_saturation`: % invocaciones en top 3 (objetivo <0.5)
- `never_used_sample`: primeros 10 agentes nunca usados
- `verdict`: BIASED si top3 ≥ 50%, OK si menor

### `weights` — pesos del scoring

```bash
bash ~/.claude/helpers/helix-route.sh weights
```

Lee/crea `~/.claude/config/routing-weights.yaml`:
```yaml
w_sim: 0.50      # similitud vectorial
w_fresh: 0.20    # bonus por uso poco reciente
w_quality: 0.15  # skill-quality avg
w_stack: 0.15    # bonus por estar en stack del proyecto
epsilon: 0.10
```

## Fórmula

```
score_final = w_sim · similarity
            + w_fresh · 1/(1+log(invocations_30d + 1))
            + w_quality · normalize(skill_quality_avg, [1,3] → [0,1])
            + w_stack · {1.0 si core, 0.6 si extended, 0 si fuera, -1 si excluded}
```

Con probabilidad `ε`, en lugar del best, elige aleatoriamente entre candidatos con `score ≥ 0.7 · best_score` (epsilon-greedy).

## Filtros hard

ANTES del scoring:
1. Si `domain != generic`: filtra por catálogo del dominio (ej: `testing` → solo `qa-expert/test-engineer/test-automator`).
2. Filtra agentes en `stack.excluded`.

Esto elimina DRIFT (frontend-developer haciendo devops).

## Workflow recomendado

```
1. Tarea entra: "agregar tests para el módulo X"
2. Helix identifica dominio: testing
3. helix-route.sh pick testing "agregar tests pytest módulo X"
4. Output: primary=test-engineer, score=0.72, alternatives=[qa-expert, test-automator]
5. Helix usa Agent tool con subagent_type=test-engineer
6. Al terminar, registrar feedback en routing-feedback.jsonl con quality 1-3
```

## Edge cases

- **Sin manifest del proyecto**: `w_stack` se ignora, scoring usa otros 3 componentes (re-normalizar).
- **Sin routing-feedback.jsonl**: `freshness = 1.0` para todos (todos nuevos).
- **Sin skill-quality.jsonl**: `skill_quality = 0.5` para todos (neutral).
- **Vector store down**: fallback a catálogo del dominio + skill_quality.
- **Catálogo del dominio vacío**: usa todos los candidatos del vector search (modo permisivo).

## Validación antes de activar como hook automático

Plan: correr `pick` en sombra (manual) durante 1 semana → comparar con la elección que Helix tomó por sí mismo:
- Si divergencia >40%: revisar pesos
- Si convergencia >90%: bias aún presente, bajar `w_sim` a 0.4 y subir `w_fresh` a 0.3

Solo después de ≥80% acuerdo y `top3_saturation < 0.5`, considerar hook automático.

## Estado

- [x] Helper `helix-route.sh` (pick/audit/weights)
- [x] Pesos configurables
- [x] Epsilon-greedy implementado
- [x] Filtro por catálogo del dominio
- [ ] Integración con `routing-check-hook.sh` existente
- [ ] Métricas en `helix-metricas.sh`
- [ ] Hook PreToolUse(Agent) automático (Fase 2)
