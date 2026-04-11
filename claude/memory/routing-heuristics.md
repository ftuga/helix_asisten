# Routing Heuristics — Helix ERL
> Generado: 2026-04-10 16:45 | Entradas analizadas: 54
> Umbral mínimo: 2 muestras

## Reglas por Dominio

- dominio 'testing' → `researcher` (3/3 usos, 100%)
- dominio 'research' → `researcher` (4/6 usos, 66% | alternativas: Explore(1), ui-ux-designer(1))
- dominio 'frontend' → `frontend-developer` (14/22 usos, 63% | alternativas: architect-reviewer(2), researcher(2))
- dominio 'backend' → `python-pro` (6/12 usos, 50% | alternativas: security-auditor(1), architect-reviewer(1))
- dominio 'analysis' → `frontend-developer` (3/6 usos, 50% | alternativas: app-creative-genius(1), data-analyst(1))
- dominio 'general' → `frontend-developer` (6/14 usos, 42% | alternativas: python-pro(5), general-purpose(2))
- dominio 'devops' → `frontend-developer` (3/8 usos, 37% | alternativas: fin-saas-advisor(1), researcher(1))
- dominio 'architecture' → `frontend-developer` (2/7 usos, 28% | alternativas: architect-reviewer(1), general-purpose(1))

## Flujos Frecuentes (Pares)

- flujo frecuente: `python-pro` → `frontend-developer` (8x) — considerar skill de orquestación
- flujo frecuente: `frontend-developer` → `python-pro` (7x) — considerar skill de orquestación
- flujo frecuente: `frontend-developer` → `ui-ux-designer` (2x) — considerar skill de orquestación

## Patrones por Proyecto

- proyecto `proceso_comite_compras` usa `frontend-developer` como agente dominante (18x)

## Gaps Detectados

- **Nunca usados** (23): api-architect, backend-architect, backend-developer, code-reviewer, codebase-explorer, context-manager, database-architect, deployment-engineer, devops-engineer, error-detective
- **Usados 1 vez**: Explore, api-security-audit, app-creative-genius, data-analyst, fin-saas-advisor, security-auditor, test-engineer, ui-designer

---
*Actualizar con: `bash ~/.claude/helpers/helix-erl.sh`*

## Reglas ExpeL (Contrastivas)
> Generado: 2026-04-10 16:45 | Basado en 54 trayectorias

### Dominancia observada
- [devops] `frontend-developer` (3x, 37%) supera a `fin-saas-advisor` (1x) — usar `frontend-developer` como primera opción
- [backend] `python-pro` (6x, 50%) supera a `security-auditor` (1x) — usar `python-pro` como primera opción
- [frontend] `frontend-developer` (14x, 63%) supera a `architect-reviewer` (2x) — usar `frontend-developer` como primera opción
- [general] `frontend-developer` (6x, 42%) supera a `python-pro` (5x) — usar `frontend-developer` como primera opción
- [research] `researcher` (4x, 80%) supera a `Explore` (1x) — usar `researcher` como primera opción
- [analysis] `frontend-developer` (3x, 75%) supera a `data-analyst` (1x) — usar `frontend-developer` como primera opción

### Routing incorrecto detectado
- [devops] se usa `frontend-developer` (3x) pero `devops-engineer` existe en catálogo y nunca se ha invocado — posible routing incorrecto
- [research] se usa `researcher` (4x) pero `backend-architect` existe en catálogo y nunca se ha invocado — posible routing incorrecto
- [analysis] `frontend-developer` (3x) se usa 3x más que `data-analyst` (1x) — considerar routing más preciso
- [testing] se usa `researcher` (3x) pero `test-engineer` existe en catálogo y nunca se ha invocado — posible routing incorrecto
- [database] se usa `python-pro` (1x) pero `database-architect` existe en catálogo y nunca se ha invocado — posible routing incorrecto

### Agentes fuera de catálogo
- `general-purpose` usado 3x pero no está en catálogo activo — considerar añadir a agents-index.md

### Evolución temporal
- [devops] routing evolucionó: `fin-saas-advisor` → `frontend-developer` — `frontend-developer` es la estrategia aprendida más reciente
- [backend] routing evolucionó: `security-auditor` → `python-pro` — `python-pro` es la estrategia aprendida más reciente
- [general] routing evolucionó: `frontend-developer` → `python-pro` — `python-pro` es la estrategia aprendida más reciente
- [analysis] routing evolucionó: `data-analyst` → `frontend-developer` — `frontend-developer` es la estrategia aprendida más reciente

