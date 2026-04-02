# Routing Heuristics — Helix ERL
> Generado: 2026-04-02 00:05 | Entradas analizadas: 22
> Umbral mínimo: 2 muestras

## Reglas por Dominio

- dominio 'testing' → `researcher` (3/3 usos, 100%)
- dominio 'research' → `researcher` (4/5 usos, 80% | alternativas: Explore(1))
- dominio 'analysis' → `frontend-developer` (2/4 usos, 50% | alternativas: app-creative-genius(1), data-analyst(1))
- dominio 'frontend' → `frontend-developer` (4/9 usos, 44% | alternativas: architect-reviewer(2), researcher(2))
- dominio 'devops' → `frontend-developer` (2/5 usos, 40% | alternativas: fin-saas-advisor(1), researcher(1))
- dominio 'architecture' → `frontend-developer` (2/5 usos, 40% | alternativas: architect-reviewer(1), general-purpose(1))

## Flujos Frecuentes (Pares)

- Sin pares frecuentes detectados aún

## Patrones por Proyecto

- proyecto `proyecto_privado` usa `frontend-developer` como agente dominante (6x)

## Gaps Detectados

- **Nunca usados** (24): api-architect, backend-architect, backend-developer, code-reviewer, codebase-explorer, context-manager, database-architect, deployment-engineer, devops-engineer, error-detective
- **Usados 1 vez**: Explore, api-security-audit, app-creative-genius, data-analyst, fin-saas-advisor, python-pro, security-auditor, test-engineer

---
*Actualizar con: `bash ~/.claude/helpers/helix-erl.sh`*

## Reglas ExpeL (Contrastivas)
> Generado: 2026-04-02 00:19 | Basado en 22 trayectorias

### Dominancia observada
- [devops] `frontend-developer` (2x, 40%) supera a `fin-saas-advisor` (1x) — usar `frontend-developer` como primera opción
- [frontend] `frontend-developer` (4x, 44%) supera a `architect-reviewer` (2x) — usar `frontend-developer` como primera opción
- [research] `researcher` (4x, 80%) supera a `Explore` (1x) — usar `researcher` como primera opción
- [analysis] `frontend-developer` (2x, 66%) supera a `data-analyst` (1x) — usar `frontend-developer` como primera opción

### Routing incorrecto detectado
- [devops] se usa `frontend-developer` (2x) pero `devops-engineer` existe en catálogo y nunca se ha invocado — posible routing incorrecto
- [research] se usa `researcher` (4x) pero `backend-architect` existe en catálogo y nunca se ha invocado — posible routing incorrecto
- [testing] se usa `researcher` (3x) pero `test-engineer` existe en catálogo y nunca se ha invocado — posible routing incorrecto

### Agentes fuera de catálogo
- `researcher` usado 4x pero no está en catálogo activo — considerar añadir a agents-index.md
- `general-purpose` usado 2x pero no está en catálogo activo — considerar añadir a agents-index.md

### Evolución temporal
- [devops] routing evolucionó: `fin-saas-advisor` → `researcher` — `researcher` es la estrategia aprendida más reciente
- [backend] routing evolucionó: `security-auditor` → `api-security-audit` — `api-security-audit` es la estrategia aprendida más reciente
- [frontend] routing evolucionó: `architect-reviewer` → `frontend-developer` — `frontend-developer` es la estrategia aprendida más reciente

