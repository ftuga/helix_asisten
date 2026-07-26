# Routing Heuristics — Helix ERL
> Generado: 2026-07-26 16:01 | Entradas analizadas: 457
> Umbral mínimo: 2 muestras

## Reglas por Dominio

- dominio 'testing' → `general-purpose` (3/4 usos, 75%, q=1.3 | alternativas: linguista-computacional-tokens(1)) ⚠️ DRIFT — agente fuera de catálogo
- dominio 'bug' → `n8n-workflow-expert` (2/3 usos, 66%, q=3.0 | alternativas: frontend-developer(1)) ⚠️ DRIFT — agente fuera de catálogo
- dominio 'frontend' → `frontend-developer` (29/58 usos, 50%, q=3.0 | alternativas: ui-ux-designer(3), ui-designer(1))
- dominio 'security' → `security-auditor` (3/7 usos, 42%, q=3.0 | alternativas: api-security-audit(1))
- dominio 'research' → `council-researcher` (9/24 usos, 37%, q=3.0 | alternativas: general-purpose(10), Explore(1))
- dominio 'backend' → `python-pro` (6/20 usos, 30% | alternativas: backend-developer(1))
- dominio 'general' → `frontend-developer` (10/77 usos, 12%, q=3.0 | alternativas: general-purpose(13), n8n-workflow-expert(9))

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

### ⚠️ Agentes problemáticos (avg < 1.5) — revisar o reemplazar
- **general-purpose** avg=1.3 (86 usos) — considerar skill alternativa o mejorar prompt
### ✅ Agentes confiables (avg ≥ 2.5)
- code-reviewer avg=3.0 (12 usos)
- frontend-developer avg=3.0 (22 usos)
- ui-ux-designer avg=3.0 (2 usos)
- claude-code-guide avg=3.0 (2 usos)
- mme-domain-expert avg=3.0 (2 usos)
- harness-optimizer avg=3.0 (2 usos)
- council-arbiter avg=3.0 (16 usos)
- council-skeptic avg=3.0 (23 usos)
- council-innovator avg=3.0 (23 usos)
- council-conservative avg=3.0 (22 usos)
- council-researcher avg=3.0 (14 usos)
- council-synthesizer avg=3.0 (33 usos)
- council-devils-advocate avg=3.0 (13 usos)
- typescript-pro avg=3.0 (1 usos)
- linguista-computacional-tokens avg=3.0 (3 usos)
- backend-developer avg=3.0 (2 usos)
- Explore avg=3.0 (4 usos)
- architect-reviewer avg=3.0 (1 usos)
- security-auditor avg=3.0 (5 usos)
- tokens-manager avg=3.0 (1 usos)
- conversational-comms-expert avg=3.0 (5 usos)
- n8n-workflow-expert avg=3.0 (22 usos)
- bot-architecture-expert avg=3.0 (4 usos)
- deployment-engineer avg=3.0 (7 usos)
- api-security-audit avg=3.0 (1 usos)
- powerbi-expert avg=3.0 (3 usos)
- transformacion-digital-expert avg=3.0 (3 usos)
- planeacion-estrategica-expert avg=3.0 (3 usos)
- devops-engineer avg=3.0 (1 usos)
- auditor-cuentas-cobro avg=3.0 (2 usos)
- domain-researcher avg=3.0 (2 usos)
- cohortes-riesgo-expert avg=3.0 (1 usos)
- mipres-interop-expert avg=3.0 (1 usos)
- rag-clinical-architect avg=3.0 (1 usos)
- bid-strategist avg=3.0 (1 usos)
- salud-publica-datos-expert avg=3.0 (1 usos)
- claude avg=3.0 (1 usos)
- sql-pro avg=3.0 (1 usos)
- database-architect avg=3.0 (1 usos)
- error-detective avg=2.5 (2 usos)

---
*Actualizar con: `bash ~/.claude/helpers/helix-erl.sh`*

## Reglas ExpeL (Contrastivas)
> Generado: 2026-07-26 16:01 | Basado en 457 trayectorias

### Dominancia observada
- [devops] `council-synthesizer` (29x, 14%) supera a `council-skeptic` (21x) — usar `council-synthesizer` como primera opción
- [backend] `python-pro` (6x, 31%) supera a `test-engineer` (2x) — usar `python-pro` como primera opción
- [security] `security-auditor` (4x, 40%) supera a `api-security-audit` (1x) — usar `security-auditor` como primera opción
- [frontend] `frontend-developer` (30x, 47%) supera a `code-reviewer` (6x) — usar `frontend-developer` como primera opción
- [general] `general-purpose` (111x, 62%) supera a `frontend-developer` (11x) — usar `general-purpose` como primera opción
- [architecture] `frontend-developer` (3x, 30%) supera a `deployment-engineer` (2x) — usar `frontend-developer` como primera opción
- [research] `general-purpose` (11x, 42%) supera a `council-researcher` (9x) — usar `general-purpose` como primera opción
- [analysis] `frontend-developer` (4x, 66%) supera a `data-analyst` (1x) — usar `frontend-developer` como primera opción
- [testing] `general-purpose` (3x, 75%) supera a `linguista-computacional-tokens` (1x) — usar `general-purpose` como primera opción
- [database] `frontend-developer` (2x, 50%) supera a `python-pro` (1x) — usar `frontend-developer` como primera opción

### Routing incorrecto detectado
- [devops] se usa `council-synthesizer` (29x) pero `devops-engineer` existe en catálogo y nunca se ha invocado — posible routing incorrecto
- [architecture] `frontend-developer` (3x) se usa 3x más que `architect-reviewer` (1x) — considerar routing más preciso
- [research] se usa `general-purpose` (11x) pero `backend-architect` existe en catálogo y nunca se ha invocado — posible routing incorrecto
- [analysis] `frontend-developer` (4x) se usa 4x más que `data-analyst` (1x) — considerar routing más preciso
- [database] se usa `frontend-developer` (2x) pero `database-architect` existe en catálogo y nunca se ha invocado — posible routing incorrecto

### Agentes fuera de catálogo
- `general-purpose` usado 129x pero no está en catálogo activo — considerar añadir a agents-index.md
- `council-synthesizer` usado 33x pero no está en catálogo activo — considerar añadir a agents-index.md
- `n8n-workflow-expert` usado 24x pero no está en catálogo activo — considerar añadir a agents-index.md
- `council-skeptic` usado 23x pero no está en catálogo activo — considerar añadir a agents-index.md
- `council-innovator` usado 23x pero no está en catálogo activo — considerar añadir a agents-index.md

### Evolución temporal
- [architecture] routing evolucionó: `frontend-developer` → `deployment-engineer` — `deployment-engineer` es la estrategia aprendida más reciente
- [research] routing evolucionó: `council-researcher` → `general-purpose` — `general-purpose` es la estrategia aprendida más reciente
- [database] routing evolucionó: `python-pro` → `frontend-developer` — `frontend-developer` es la estrategia aprendida más reciente

