# Routing Heuristics — Helix ERL
> Generado: 2026-07-24 01:42 | Entradas analizadas: 448
> Umbral mínimo: 2 muestras

## Reglas por Dominio

- dominio 'testing' → `general-purpose` (3/4 usos, 75%, q=3.0 | alternativas: linguista-computacional-tokens(1)) ⚠️ DRIFT — agente fuera de catálogo
- dominio 'bug' → `n8n-workflow-expert` (2/3 usos, 66% | alternativas: frontend-developer(1)) ⚠️ DRIFT — agente fuera de catálogo
- dominio 'frontend' → `frontend-developer` (29/57 usos, 50%, q=3.0 | alternativas: ui-ux-designer(3), ui-designer(1))
- dominio 'security' → `security-auditor` (3/7 usos, 42% | alternativas: api-security-audit(1))
- dominio 'research' → `general-purpose` (10/24 usos, 41%, q=3.0 | alternativas: council-researcher(9), Explore(1))
- dominio 'backend' → `python-pro` (6/20 usos, 30% | alternativas: backend-developer(1))
- dominio 'general' → `general-purpose` (13/76 usos, 17%, q=3.0 | alternativas: frontend-developer(9), n8n-workflow-expert(9))

## Flujos Frecuentes (Pares)

- flujo frecuente: `council-synthesizer` → `council-devils-advocate` (12x) — considerar skill de orquestación
- flujo frecuente: `council-skeptic` → `council-innovator` (11x) — considerar skill de orquestación
- flujo frecuente: `council-innovator` → `council-synthesizer` (9x) — considerar skill de orquestación
- flujo frecuente: `python-pro` → `frontend-developer` (8x) — considerar skill de orquestación
- flujo frecuente: `council-conservative` → `council-synthesizer` (8x) — considerar skill de orquestación

## Patrones por Proyecto

- proyecto `proceso_comite_compras` usa `frontend-developer` como agente dominante (18x)
- proyecto `proyecto` usa `council-synthesizer` como agente dominante (6x)
- proyecto `‹privado›` usa `general-purpose` como agente dominante (8x)
- proyecto `cohortes_riesgo` usa `general-purpose` como agente dominante (12x)
- proyecto `proyecto_01` usa `general-purpose` como agente dominante (30x)

## Routing Drift (agentes fuera de catálogo)

- dominio 'backend' desviado: `general-purpose` usado 3x — catálogo: ['backend-architect', 'backend-developer', 'python-pro']
- dominio 'frontend' desviado: `code-reviewer` usado 6x — catálogo: ['frontend-developer', 'nextjs-architecture-expert', 'typescript-pro', 'ui-designer', 'ui-ux-designer']
- dominio 'testing' desviado: `general-purpose` usado 3x — catálogo: ['qa-expert', 'test-automator', 'test-engineer']
- dominio 'bug' desviado: `n8n-workflow-expert` usado 2x — catálogo: ['error-detective']

## Gaps Detectados

- **Nunca usados** (24): airflow-dag-expert, api-architect, backend-architect, brand-identity-expert, code-reviewer-frontend, design-bridge, ent-tesis, helix-agent-manager, helix-council, investment-expert

## Calidad por Agente (skill-quality.jsonl)

### Agentes con correcciones frecuentes (avg 1.5–2.4)
- error-detective avg=2.0 (1 usos)
### ✅ Agentes confiables (avg ≥ 2.5)
- code-reviewer avg=3.0 (1 usos)
- frontend-developer avg=3.0 (3 usos)
- ui-ux-designer avg=3.0 (1 usos)
- claude-code-guide avg=3.0 (1 usos)
- general-purpose avg=3.0 (2 usos)
- mme-domain-expert avg=3.0 (2 usos)
- harness-optimizer avg=3.0 (2 usos)
- council-arbiter avg=3.0 (8 usos)
- council-skeptic avg=3.0 (10 usos)
- council-innovator avg=3.0 (10 usos)
- council-conservative avg=3.0 (9 usos)
- council-researcher avg=3.0 (7 usos)
- council-synthesizer avg=3.0 (13 usos)
- council-devils-advocate avg=3.0 (6 usos)

---
*Actualizar con: `bash ~/.claude/helpers/helix-erl.sh`*

## Reglas ExpeL (Contrastivas)
> Generado: 2026-07-24 01:42 | Basado en 448 trayectorias

### Dominancia observada
- [devops] `council-synthesizer` (29x, 14%) supera a `council-skeptic` (21x) — usar `council-synthesizer` como primera opción
- [backend] `python-pro` (6x, 31%) supera a `test-engineer` (2x) — usar `python-pro` como primera opción
- [security] `security-auditor` (3x, 37%) supera a `api-security-audit` (1x) — usar `security-auditor` como primera opción
- [frontend] `frontend-developer` (29x, 47%) supera a `code-reviewer` (6x) — usar `frontend-developer` como primera opción
- [general] `general-purpose` (106x, 61%) supera a `frontend-developer` (10x) — usar `general-purpose` como primera opción
- [architecture] `frontend-developer` (3x, 30%) supera a `deployment-engineer` (2x) — usar `frontend-developer` como primera opción
- [research] `general-purpose` (10x, 40%) supera a `council-researcher` (9x) — usar `general-purpose` como primera opción
- [analysis] `frontend-developer` (4x, 66%) supera a `data-analyst` (1x) — usar `frontend-developer` como primera opción
- [testing] `general-purpose` (3x, 75%) supera a `linguista-computacional-tokens` (1x) — usar `general-purpose` como primera opción
- [database] `frontend-developer` (2x, 50%) supera a `python-pro` (1x) — usar `frontend-developer` como primera opción

### Routing incorrecto detectado
- [devops] se usa `council-synthesizer` (29x) pero `devops-engineer` existe en catálogo y nunca se ha invocado — posible routing incorrecto
- [architecture] `frontend-developer` (3x) se usa 3x más que `architect-reviewer` (1x) — considerar routing más preciso
- [research] se usa `general-purpose` (10x) pero `backend-architect` existe en catálogo y nunca se ha invocado — posible routing incorrecto
- [analysis] `frontend-developer` (4x) se usa 4x más que `data-analyst` (1x) — considerar routing más preciso
- [database] se usa `frontend-developer` (2x) pero `database-architect` existe en catálogo y nunca se ha invocado — posible routing incorrecto

### Agentes fuera de catálogo
- `general-purpose` usado 123x pero no está en catálogo activo — considerar añadir a agents-index.md
- `council-synthesizer` usado 33x pero no está en catálogo activo — considerar añadir a agents-index.md
- `n8n-workflow-expert` usado 24x pero no está en catálogo activo — considerar añadir a agents-index.md
- `council-skeptic` usado 23x pero no está en catálogo activo — considerar añadir a agents-index.md
- `council-innovator` usado 23x pero no está en catálogo activo — considerar añadir a agents-index.md

### Evolución temporal
- [architecture] routing evolucionó: `frontend-developer` → `deployment-engineer` — `deployment-engineer` es la estrategia aprendida más reciente
- [research] routing evolucionó: `council-researcher` → `general-purpose` — `general-purpose` es la estrategia aprendida más reciente
- [database] routing evolucionó: `python-pro` → `frontend-developer` — `frontend-developer` es la estrategia aprendida más reciente

