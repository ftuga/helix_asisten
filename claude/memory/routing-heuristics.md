# Routing Heuristics — Helix ERL
> Generado: 2026-06-11 09:10 | Entradas analizadas: 235
> Umbral mínimo: 2 muestras

## Reglas por Dominio

- dominio 'testing' → `general-purpose` (3/4 usos, 75%, q=3.0 | alternativas: linguista-computacional-tokens(1)) ⚠️ DRIFT — agente fuera de catálogo
- dominio 'frontend' → `frontend-developer` (24/40 usos, 60%, q=3.0 | alternativas: ui-ux-designer(3), ui-designer(1))
- dominio 'research' → `council-researcher` (9/16 usos, 56%, q=3.0 | alternativas: general-purpose(4), Explore(1))
- dominio 'backend' → `python-pro` (6/14 usos, 42% | alternativas: backend-developer(1))
- dominio 'devops' → `council-synthesizer` (29/148 usos, 19%, q=3.0 | alternativas: council-skeptic(21), council-innovator(21)) ⚠️ DRIFT — agente fuera de catálogo
- dominio 'general' → `frontend-developer` (6/32 usos, 18%, q=3.0 | alternativas: python-pro(6), general-purpose(4))

## Flujos Frecuentes (Pares)

- flujo frecuente: `council-synthesizer` → `council-devils-advocate` (12x) — considerar skill de orquestación
- flujo frecuente: `council-skeptic` → `council-innovator` (11x) — considerar skill de orquestación
- flujo frecuente: `council-innovator` → `council-synthesizer` (9x) — considerar skill de orquestación
- flujo frecuente: `python-pro` → `frontend-developer` (8x) — considerar skill de orquestación
- flujo frecuente: `council-conservative` → `council-synthesizer` (8x) — considerar skill de orquestación

## Patrones por Proyecto

- proyecto `proceso_comite_compras` usa `frontend-developer` como agente dominante (18x)
- proyecto `proyecto` usa `council-synthesizer` como agente dominante (6x)

## Routing Drift (agentes fuera de catálogo)

- dominio 'devops' desviado: `council-synthesizer` usado 29x — catálogo: ['deployment-engineer', 'devops-engineer']
- dominio 'backend' desviado: `test-engineer` usado 2x — catálogo: ['backend-architect', 'backend-developer', 'python-pro']
- dominio 'frontend' desviado: `code-reviewer` usado 4x — catálogo: ['frontend-developer', 'nextjs-architecture-expert', 'typescript-pro', 'ui-designer', 'ui-ux-designer']
- dominio 'testing' desviado: `general-purpose` usado 3x — catálogo: ['qa-expert', 'test-automator', 'test-engineer']

## Gaps Detectados

- **Nunca usados** (19): airflow-dag-expert, api-architect, backend-architect, brand-identity-expert, database-architect, deployment-engineer, devops-engineer, ent-tesis, helix-agent-manager, investment-expert
- **Usados 1 vez**: api-security-audit, app-creative-genius, claude-code-guide, data-analyst, error-detective, security-auditor, typescript-pro, ui-designer

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
> Generado: 2026-06-11 09:10 | Basado en 235 trayectorias

### Dominancia observada
- [devops] `council-synthesizer` (29x, 19%) supera a `council-skeptic` (21x) — usar `council-synthesizer` como primera opción
- [backend] `python-pro` (6x, 40%) supera a `test-engineer` (2x) — usar `python-pro` como primera opción
- [frontend] `frontend-developer` (24x, 58%) supera a `ui-ux-designer` (4x) — usar `frontend-developer` como primera opción
- [general] `frontend-developer` (7x, 21%) supera a `python-pro` (6x) — usar `frontend-developer` como primera opción
- [architecture] `frontend-developer` (3x, 60%) supera a `architect-reviewer` (1x) — usar `frontend-developer` como primera opción
- [research] `council-researcher` (9x, 60%) supera a `general-purpose` (4x) — usar `council-researcher` como primera opción
- [analysis] `frontend-developer` (4x, 80%) supera a `data-analyst` (1x) — usar `frontend-developer` como primera opción
- [testing] `general-purpose` (3x, 75%) supera a `linguista-computacional-tokens` (1x) — usar `general-purpose` como primera opción
- [database] `frontend-developer` (2x, 66%) supera a `python-pro` (1x) — usar `frontend-developer` como primera opción

### Routing incorrecto detectado
- [devops] se usa `council-synthesizer` (29x) pero `devops-engineer` existe en catálogo y nunca se ha invocado — posible routing incorrecto
- [architecture] `frontend-developer` (3x) se usa 3x más que `architect-reviewer` (1x) — considerar routing más preciso
- [research] se usa `council-researcher` (9x) pero `backend-architect` existe en catálogo y nunca se ha invocado — posible routing incorrecto
- [analysis] `frontend-developer` (4x) se usa 4x más que `data-analyst` (1x) — considerar routing más preciso
- [testing] se usa `general-purpose` (3x) pero `test-engineer` existe en catálogo y nunca se ha invocado — posible routing incorrecto
- [database] se usa `frontend-developer` (2x) pero `database-architect` existe en catálogo y nunca se ha invocado — posible routing incorrecto

### Agentes fuera de catálogo
- `council-synthesizer` usado 33x pero no está en catálogo activo — considerar añadir a agents-index.md
- `council-skeptic` usado 23x pero no está en catálogo activo — considerar añadir a agents-index.md
- `council-innovator` usado 23x pero no está en catálogo activo — considerar añadir a agents-index.md
- `council-conservative` usado 22x pero no está en catálogo activo — considerar añadir a agents-index.md
- `council-arbiter` usado 16x pero no está en catálogo activo — considerar añadir a agents-index.md

### Evolución temporal
- [backend] routing evolucionó: `security-auditor` → `python-pro` — `python-pro` es la estrategia aprendida más reciente
- [security] routing evolucionó: `security-auditor` → `council-researcher` — `council-researcher` es la estrategia aprendida más reciente
- [general] routing evolucionó: `frontend-developer` → `council-synthesizer` — `council-synthesizer` es la estrategia aprendida más reciente
- [architecture] routing evolucionó: `architect-reviewer` → `frontend-developer` — `frontend-developer` es la estrategia aprendida más reciente
- [research] routing evolucionó: `general-purpose` → `council-researcher` — `council-researcher` es la estrategia aprendida más reciente
- [analysis] routing evolucionó: `data-analyst` → `frontend-developer` — `frontend-developer` es la estrategia aprendida más reciente

