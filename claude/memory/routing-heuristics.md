# Routing Heuristics — Helix ERL
> Generado: 2026-04-18 21:11 | Entradas analizadas: 63
> Umbral mínimo: 2 muestras

## Reglas por Dominio

- dominio 'testing' → `general-purpose` (3/3 usos, 100%) ⚠️ DRIFT — agente fuera de catálogo
- dominio 'frontend' → `frontend-developer` (16/27 usos, 59%, q=3.0 | alternativas: ui-ux-designer(3), ui-designer(1))
- dominio 'research' → `general-purpose` (4/7 usos, 57% | alternativas: Explore(1), ui-ux-designer(1))
- dominio 'backend' → `python-pro` (6/13 usos, 46%)
- dominio 'general' → `frontend-developer` (6/15 usos, 40%, q=3.0 | alternativas: python-pro(6), general-purpose(2))
- dominio 'devops' → `frontend-developer` (3/8 usos, 37%, q=3.0 | alternativas: general-purpose(2), python-pro(1)) ⚠️ DRIFT — agente fuera de catálogo

## Flujos Frecuentes (Pares)

- flujo frecuente: `python-pro` → `frontend-developer` (8x) — considerar skill de orquestación
- flujo frecuente: `frontend-developer` → `python-pro` (7x) — considerar skill de orquestación
- flujo frecuente: `frontend-developer` → `ui-ux-designer` (3x) — considerar skill de orquestación
- flujo frecuente: `frontend-developer` → `general-purpose` (2x) — considerar skill de orquestación

## Patrones por Proyecto

- proyecto `proceso_comite_compras` usa `frontend-developer` como agente dominante (18x)

## Routing Drift (agentes fuera de catálogo)

- dominio 'devops' desviado: `frontend-developer` usado 3x — catálogo: ['deployment-engineer', 'devops-engineer']
- dominio 'backend' desviado: `test-engineer` usado 2x — catálogo: ['backend-architect', 'backend-developer', 'python-pro']
- dominio 'frontend' desviado: `general-purpose` usado 3x — catálogo: ['frontend-developer', 'nextjs-architecture-expert', 'typescript-pro', 'ui-designer', 'ui-ux-designer']
- dominio 'testing' desviado: `general-purpose` usado 3x — catálogo: ['qa-expert', 'test-automator', 'test-engineer']

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
