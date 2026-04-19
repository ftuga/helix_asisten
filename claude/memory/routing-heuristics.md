# Routing Heuristics — Helix ERL
> Generado: 2026-04-18 20:40 | Entradas analizadas: 63
> Umbral mínimo: 2 muestras

## Reglas por Dominio

- dominio 'testing' → `general-purpose` (3/3 usos, 100%)
- dominio 'frontend' → `frontend-developer` (16/27 usos, 59% | alternativas: general-purpose(3), ui-ux-designer(3))
- dominio 'research' → `general-purpose` (4/7 usos, 57% | alternativas: Explore(1), ui-ux-designer(1))
- dominio 'analysis' → `frontend-developer` (3/6 usos, 50% | alternativas: app-creative-genius(1), data-analyst(1))
- dominio 'backend' → `python-pro` (6/13 usos, 46% | alternativas: test-engineer(2), security-auditor(1))
- dominio 'general' → `frontend-developer` (6/15 usos, 40% | alternativas: python-pro(6), general-purpose(2))
- dominio 'devops' → `frontend-developer` (3/8 usos, 37% | alternativas: general-purpose(2), python-pro(1))
- dominio 'architecture' → `frontend-developer` (2/7 usos, 28% | alternativas: architect-reviewer(1), general-purpose(1))

## Flujos Frecuentes (Pares)

- flujo frecuente: `python-pro` → `frontend-developer` (8x) — considerar skill de orquestación
- flujo frecuente: `frontend-developer` → `python-pro` (7x) — considerar skill de orquestación
- flujo frecuente: `frontend-developer` → `ui-ux-designer` (3x) — considerar skill de orquestación
- flujo frecuente: `frontend-developer` → `general-purpose` (2x) — considerar skill de orquestación

## Patrones por Proyecto

- proyecto `proceso_comite_compras` usa `frontend-developer` como agente dominante (18x)

## Gaps Detectados

- **Nunca usados** (20): api-architect, backend-architect, codebase-explorer, context-manager, database-architect, deployment-engineer, devops-engineer, fin-saas-advisor, investment-expert, monitoring-specialist
- **Usados 1 vez**: Explore, api-security-audit, app-creative-genius, claude-code-guide, code-reviewer, data-analyst, error-detective, security-auditor

## Calidad por Agente (skill-quality.jsonl)

### Agentes con correcciones frecuentes (avg 1.5–2.4)
- error-detective avg=2.0 (1 usos)
### ✅ Agentes confiables (avg ≥ 2.5)
- code-reviewer avg=3.0 (1 usos)
- frontend-developer avg=3.0 (3 usos)
- ui-ux-designer avg=3.0 (1 usos)
- claude-code-guide avg=3.0 (1 usos)

---
*Actualizar con: `bash ~/.claude/helpers/helix-erl.sh`*

## Reglas ExpeL (Contrastivas)
> Generado: 2026-04-18 20:40 | Basado en 63 trayectorias

### Dominancia observada
- [devops] `frontend-developer` (3x, 37%) supera a `general-purpose` (2x) — usar `frontend-developer` como primera opción
- [backend] `python-pro` (6x, 46%) supera a `test-engineer` (2x) — usar `python-pro` como primera opción
- [frontend] `frontend-developer` (16x, 59%) supera a `general-purpose` (3x) — usar `frontend-developer` como primera opción
- [general] `frontend-developer` (7x, 43%) supera a `python-pro` (6x) — usar `frontend-developer` como primera opción
- [research] `general-purpose` (4x, 66%) supera a `Explore` (1x) — usar `general-purpose` como primera opción
- [analysis] `frontend-developer` (4x, 80%) supera a `data-analyst` (1x) — usar `frontend-developer` como primera opción

### Routing incorrecto detectado
- [devops] se usa `frontend-developer` (3x) pero `devops-engineer` existe en catálogo y nunca se ha invocado — posible routing incorrecto
- [research] se usa `general-purpose` (4x) pero `backend-architect` existe en catálogo y nunca se ha invocado — posible routing incorrecto
- [analysis] `frontend-developer` (4x) se usa 4x más que `data-analyst` (1x) — considerar routing más preciso
- [testing] se usa `general-purpose` (3x) pero `test-engineer` existe en catálogo y nunca se ha invocado — posible routing incorrecto
- [database] se usa `python-pro` (1x) pero `database-architect` existe en catálogo y nunca se ha invocado — posible routing incorrecto

### Agentes fuera de catálogo
- `general-purpose` usado 8x pero no está en catálogo activo — considerar añadir a agents-index.md

### Evolución temporal
- [devops] routing evolucionó: `general-purpose` → `frontend-developer` — `frontend-developer` es la estrategia aprendida más reciente
- [backend] routing evolucionó: `security-auditor` → `python-pro` — `python-pro` es la estrategia aprendida más reciente
- [analysis] routing evolucionó: `data-analyst` → `frontend-developer` — `frontend-developer` es la estrategia aprendida más reciente

