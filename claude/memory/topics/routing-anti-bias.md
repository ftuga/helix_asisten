# Routing Anti-Bias — Diseño

Versión: v0.1 (2026-04-27)
Status: implementación inicial (Fase 1)

## Problema

Datos reales del sistema (ERL report 2026-04-26):
- 24 de 35 agentes **nunca invocados**
- 8 agentes invocados solo 1 vez
- `frontend-developer` + `python-pro` + `general-purpose` acumulan ~70% de las 68 invocaciones registradas
- DRIFT detectado: `frontend-developer` se usa para devops/analysis, `general-purpose` para testing

Causa raíz: la búsqueda vectorial pura (`hv search helix_agents`) optimiza por **similitud al query**, no por **idoneidad para el contexto**. Los agentes con descripciones bien-escritas y de alta visibilidad ganan siempre, incluso cuando hay un especialista mejor pero menos visible.

Es el clásico **explotación vs exploración**.

## Solución: scoring multi-criterio + epsilon-greedy

### Formula de score

```
score_final = w_sim · similarity
            + w_fresh · freshness
            + w_quality · skill_quality
            + w_stack · stack_match
```

Pesos por defecto (configurables en `~/.claude/config/routing-weights.yaml`):
- `w_sim = 0.50` — similitud vectorial (qué tan cerca está la descripción al query)
- `w_fresh = 0.20` — bonus por uso poco reciente (anti-explotación)
- `w_quality = 0.15` — promedio de skill-quality (avg ≥ 2.5 ideal)
- `w_stack = 0.15` — bonus si el agente está en `stack.core` del proyecto

### Cálculo de `freshness`

```
invocations_30d = count(routing-feedback.jsonl where agent=A and date ≥ today-30d)
freshness = 1 / (1 + log(invocations_30d + 1))
```

Resultado:
- 0 invocaciones → freshness = 1.0 (boost máximo)
- 1 invocación → freshness ≈ 0.59
- 5 invocaciones → freshness ≈ 0.36
- 50 invocaciones → freshness ≈ 0.20

### Cálculo de `skill_quality`

Lee `skill-quality.jsonl` (ya existe). `avg ∈ [1.0, 3.0]`. Normalizar:
```
skill_quality = (avg - 1.0) / 2.0  # → [0, 1]
```

Si agente sin historial → `skill_quality = 0.5` (neutral, no penaliza ni premia).

### Cálculo de `stack_match`

```
if agent in stack.core: 1.0
elif agent in stack.extended: 0.6
elif agent in stack.excluded: -1.0  # penalty fuerte
else: 0.0  # no afecta
```

### Filtro por catálogo del dominio (hard)

ANTES del scoring, si el query menciona dominio explícito:
- `domain=testing` → solo candidatos en `[qa-expert, test-engineer, test-automator]`
- `domain=devops` → solo `[devops-engineer, deployment-engineer]`
- `domain=security` → solo `[security-auditor, api-security-audit, mcp-security-auditor]`

Catálogo de dominios → agentes en `~/.claude/memory/topics/stack-catalogs.md` §"Por lenguaje/framework".

Esto elimina DRIFTs estructurales (frontend-developer haciendo devops).

## Epsilon-greedy

Con probabilidad `ε = 0.10` (configurable):
- Saltar el scoring y elegir aleatoriamente entre los candidatos con `score ≥ 0.7 · best_score`
- Solo aplica si hay ≥3 candidatos elegibles
- Tracker en `routing-feedback.jsonl` con flag `epsilon=true` para análisis posterior

Resultado: 1 de cada 10 invocaciones explora. Si el explorado funciona → su `skill_quality` sube → futuro routing lo prefiere → diversificación se cementa orgánicamente.

## Output del router

```json
{
  "primary": {
    "agent": "test-engineer",
    "score": 0.72,
    "components": {
      "similarity": 0.81,
      "freshness": 1.0,
      "skill_quality": 0.5,
      "stack_match": 0.6
    },
    "epsilon_pick": false
  },
  "alternatives": [
    {"agent": "qa-expert", "score": 0.68, ...},
    {"agent": "test-automator", "score": 0.61, ...}
  ],
  "warnings": [
    "agente fuera de stack: needed test-automator but only test-engineer in stack.core"
  ]
}
```

## Integración

### Comando manual

```bash
bash ~/.claude/helpers/helix-route.sh pick <domain> "<query>"
```

Helix lo invoca antes de usar el `Agent` tool. Si el primary recomendado coincide con el que iba a usar → proceder. Si difiere → reconsiderar.

### Hook (Fase 2, no implementado aún)

`PreToolUse(Agent)` → llama `helix-route.sh pick` con el subagent_type → si el agente seleccionado no está en top-3 del router → exit 2 con sugerencia.

Por ahora se queda como **Fase 1 manual** para validar antes de automatizar.

## Métricas

`helix-route.sh audit` reporta:
- **Cobertura de catálogo**: cuántos agentes únicos se invocaron en últimos 30d / total catálogo
- **Top-3 saturación**: % de invocaciones que cayeron en los 3 más usados (objetivo <50%)
- **Tasa de epsilon-pick exitoso**: % de exploraciones que terminaron con feedback positivo

## Validación

Para evitar regresiones, antes de activar este routing:
1. Correr `helix-route.sh pick` en sombra (dry-run) durante 1 semana
2. Comparar primary recomendado vs agente que Claude eligió
3. Si divergencia >40% → revisar pesos
4. Si convergencia >90% → el sistema está OK pero el bias persiste — bajar `w_sim` y subir `w_fresh`

## Edge cases

- **Sin `helix-stack.md`**: `w_stack = 0`, todo el scoring se distribuye entre los otros 3 componentes (re-normalizar pesos).
- **Sin `routing-feedback.jsonl`**: `freshness = 1.0` para todos (todos nuevos), reduce a similarity + skill_quality.
- **Sin `skill-quality.jsonl`**: `skill_quality = 0.5` para todos (neutral).
- **Vector store down (Qdrant)**: fallback a catálogo del dominio + skill_quality.

## Roadmap

- [x] v0.1 — diseño + helper `helix-route.sh pick` (manual)
- [ ] v0.2 — integración con `helix-stack.md` (filtro por stack)
- [ ] v0.3 — métricas en `helix-route.sh audit`
- [ ] v0.4 — hook PreToolUse (validación 1 semana antes)
- [ ] v0.5 — auto-tuning de pesos via gradient sobre feedback
