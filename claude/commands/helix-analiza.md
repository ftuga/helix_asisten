# /helix-analiza — Análisis Inicial del Proyecto

Diagnóstico completo del proyecto. Guarda memoria persistente para no repetir el trabajo.
Arquitectura híbrida: resumen en archivo (carga siempre), detalles en vector memory si está disponible.

---

## Paso 0 — Auto-detectar capacidades disponibles

Antes de empezar, evaluar:

```
¿Está disponible mcp__claude-flow__memory_store?
  → Sí: modo VECTOR (detalles en vector, solo resumen en archivo)
  → No: modo FILE   (todo en helix-analysis-full.md + resumen en helix-analysis.md)
```

Para detectarlo: intentar `mcp__claude-flow__memory_store` con un valor de prueba mínimo.
Si falla o no existe → usar modo FILE. No preguntar al usuario cuál usar.

---

## Paso 1 — Detección de stack (bash — determinista)

```bash
bash ~/.claude/helpers/helix-detect-stack.sh {PROJECT_ROOT}
```

Esto devuelve JSON con: backend, frontend, database, auth, infra, servicios Docker, conteos de archivos.
Leer el JSON. Si el script falla → detectar manualmente leyendo los archivos clave en paralelo.

---

## Paso 2 — Leer contexto ya conocido

Si existe `{PROJECT_ROOT}/CLAUDE.md` → leer las secciones:
- MAPA DE ZONAS DE RIESGO
- DECISIONES DE DISEÑO
- ARQUITECTURA
No releer si ya están en contexto.

---

## Paso 3 — Mapear agentes necesarios

Basado en el stack detectado, mapear qué agentes de `~/.claude/memory/agents-index.md` aplican.
Indicar: cuáles están activos, cuáles habría que habilitar.

---

## Paso 4 — Mapear skills aplicables

Listar skills en `~/.claude/skills/` y `{PROJECT_ROOT}/.claude/skills/` que aplican al stack.
Indicar si falta alguna skill crítica para este tipo de proyecto.

---

## Paso 4b — MCPs recomendados por stack

Basado en el stack detectado, recomendar MCPs activos:

| Componente detectado | MCPs recomendados |
|---|---|
| Cualquier proyecto | `context7` (docs de libs), `sequential-thinking` (arquitectura compleja) |
| Frontend React / Next.js / Vue | `context7`, `puppeteer` (verificación visual UI) |
| Backend Python / FastAPI / Django | `context7` |
| Backend Node / Express / NestJS | `context7` |
| PostgreSQL / MySQL / MongoDB | `context7` |
| Docker / docker-compose | `context7` |
| 2+ dominios / features complejas | `claude-flow` (swarm orquestación) |
| Email / Calendar integrado | Gmail MCP, Google Calendar MCP |
| Skills largas (>150 líneas), PDFs externos, docs masivos | `pageindex` (ver razonamiento abajo) |

Indicar cuáles ya están en `.mcp.json` del proyecto y cuáles faltan.
Si falta `context7` en un proyecto con dependencias externas → recomendarlo siempre.

### Cuándo recomendar PageIndex — y cómo razonarlo al usuario

Detectar si aplica alguna de estas condiciones en el proyecto:
- Hay skills con más de 150 líneas
- Existen PDFs, manuales o documentación externa descargada
- `helix-analysis-full.md` supera 500 líneas
- El proyecto tiene documentación técnica interna extensa (wikis, ADRs, specs)

Si aplica **al menos una condición** → explicar al usuario con este razonamiento:

> **Por qué PageIndex en este proyecto:**
> Los sistemas RAG tradicionales (incluido Qdrant) fragmentan los documentos en chunks y buscan por similitud semántica. Esto funciona bien para snippets cortos, pero falla en documentos largos porque:
> - Los chunks rompen el contexto jerárquico del documento
> - "Similitud ≠ relevancia" — un chunk similar semánticamente puede no ser el relevante
> - Se pierde la estructura natural (secciones, subsecciones, dependencias entre partes)
>
> PageIndex construye un índice en árbol que preserva la jerarquía original del documento. El LLM razona sobre ese árbol para encontrar exactamente la sección correcta — como un experto humano que navega un manual.
>
> **Beneficio concreto para este proyecto:** [adaptar según condición detectada]
> - Si hay skills largas → "Helix podrá recuperar el patrón exacto de una skill de 200 líneas sin traer el documento completo al contexto."
> - Si hay PDFs/manuales → "Helix podrá responder preguntas sobre documentación técnica con referencias exactas a páginas y secciones."
> - Si helix-analysis-full.md es grande → "Las búsquedas de contexto del proyecto serán más precisas y baratas en tokens."
>
> **Costo:** requiere una llamada LLM por búsqueda (más caro que Qdrant). Ideal para documentos que se consultan con profundidad, no para búsquedas frecuentes de snippets.
> Instalación: MCP disponible en https://github.com/VectifyAI/PageIndex

**Regla interna Qdrant vs PageIndex (no mostrar al usuario):**
- Qdrant → snippets cortos, búsqueda fuzzy, historial de reflexiones, planes reutilizables
- PageIndex → documentos largos estructurados donde la jerarquía importa

---

## Paso 4c — Generar helix-team.md

Basado en el stack (Paso 1) y los agentes mapeados (Paso 3), generar el roster del equipo para este proyecto.

Escribir `{PROJECT_ROOT}/.claude/memory/helix-team.md`:

```markdown
# Helix Team — {nombre del proyecto}
> Generado: {fecha} por /helix-analiza | Actualizar con: /helix-actualiza

## Equipo Activo

| Rol | Agente | Dominio | Archivos típicos |
|---|---|---|---|
{filas según stack detectado — ejemplos:}
| Backend Lead | python-pro | API, endpoints, servicios | app/api/*, app/services/* |
| Frontend Lead | frontend-developer | React, componentes, páginas | frontend/src/*, src/components/* |
| DB | postgresql-dba | Schema, queries, migraciones | migrations/*, models/*, alembic/* |
| QA | test-engineer | Tests, cobertura | tests/*, **/*.test.ts |
| Seguridad | security-auditor | Auth, permisos, endpoints | app/auth/*, middleware/* |
| Design | ui-designer | Componentes visuales, tokens | src/components/ui/*, styles/* |
| Infra | devops-engineer | Docker, CI/CD, deploy | docker-compose*, .github/workflows/* |

## MCPs Activos para este proyecto

| MCP | Para qué | Estado |
|---|---|---|
{filas según Paso 4b — indicar disponible/falta}

## Output Contracts

> Define qué produce cada agente y quién lo consume.
> Sin esto, el paralelismo en Capa 2 se rompe en el handoff.
> Completar basado en el stack real detectado — eliminar filas que no apliquen.

| Agente productor | Produce | Lo consume |
|---|---|---|
| backend-architect | OpenAPI spec, endpoint types, schema | frontend-developer, test-engineer |
| database-architect | Schema migrations, model definitions | python-pro, postgresql-dba, frontend-developer |
| python-pro | Endpoint implementado, response models | test-engineer, frontend-developer |
| ui-designer | Tokens, componentes visuales, specs | frontend-developer |
| frontend-developer | Componentes, pages, types | test-engineer |

## Definition of Done

- [ ] Tests escritos y pasando para el cambio
- [ ] code-reviewer aprobó antes de cerrar
- [ ] Sin secrets ni variables hardcodeadas
- [ ] helix-bitacora.md actualizado
- [ ] Si UI → verificado con puppeteer en 375px, 768px, 1280px
- [ ] Si endpoint nuevo → registrado en router principal

## Protocolo de Despacho

Cuando el requerimiento toca ≥2 dominios:
1. Identificar dominios afectados (leer tabla Equipo Activo)
2. Verificar output contracts: ¿hay dependencias entre agentes?
3. Si 1 dominio → Capa 1: Agent tool directo
4. Si 2+ dominios sin dependencias de contrato → Capa 2: swarm paralelo
5. Si 2+ dominios con dependencias → Capa 1 secuencial (output A → input B)
6. Al terminar: almacenar plan en Qdrant + actualizar helix-backlog.md
```

Si ya existe `helix-team.md` → enriquecerlo, NO sobreescribir desde cero.

---

## Paso 4d — Generar skill de design system del proyecto

Si el stack detectado incluye cualquier framework UI (React, Next.js, Vue, Svelte, Flutter, React Native, SwiftUI):

1. Verificar si existe `{PROJECT_ROOT}/.claude/memory/design-system.md` → si existe, leerlo para extraer tokens reales
2. Crear `{PROJECT_ROOT}/.claude/skills/{project-slug}-design-system/SKILL.md` con el contenido adaptado al stack

El skill generado debe seguir este formato — auto-poblar lo que se puede detectar, dejar placeholders claros para lo que el usuario debe completar:

```markdown
---
name: {project-slug}-design-system
description: "Design system de {nombre del proyecto}. Stack: {stack UI detectado}. Usar cuando: construyas componentes, pages o estilos en este proyecto. Complementa ui-ux-pro-max con las reglas y tokens específicos de esta app."
---

# {Nombre del Proyecto} — Design System

> Skill específico de este proyecto. Generado por /helix-analiza.
> Complementos activos: ui-ux-pro-max (estilos generales) · emilkowalski/skill (animaciones)
> ⚠️ Completar las secciones marcadas con [COMPLETAR] antes de usar.

## Stack UI
{stack detectado: ej. React 18 + TypeScript + Tailwind CSS v4 + shadcn/ui}

## Cuándo aplicar este skill
- Al construir cualquier componente nuevo en este proyecto
- Al revisar consistencia visual
- Al elegir entre variantes de un componente
- Al definir espaciado, color o tipografía

---

## Tokens de Color

{Si design-system.md existe → extraer paleta real. Si no → placeholder}

```css
:root {
  /* [COMPLETAR con los valores reales del proyecto] */
  --bg:        #0a0a0f;    /* Fondo principal */
  --surface:   #111118;    /* Cards, paneles */
  --accent:    #6c63ff;    /* Color de acción — usar con disciplina */
  --text-1:    #f0f0f5;    /* Texto principal */
  --text-2:    #8888aa;    /* Texto secundario */
  --border:    #ffffff10;  /* Bordes sutiles */
}
```

## Tipografía

{Si detectado en design-system.md → extraer. Si no → placeholder}

| Uso | Fuente | Tamaño | Peso |
|---|---|---|---|
| Headings | [COMPLETAR] | — | — |
| Body | [COMPLETAR] | 16px mínimo móvil | 400 |
| Código/mono | [COMPLETAR] | — | — |

## Componentes del Proyecto

{Detectar componentes existentes en src/components/ o similar → listar los principales}

| Componente | Ubicación | Cuándo usar | Variantes |
|---|---|---|---|
| [COMPLETAR] | [COMPLETAR] | [COMPLETAR] | [COMPLETAR] |

## Reglas de Este Proyecto

{Extraer de design-system.md si existe, si no generar reglas base según stack}

- Mobile-first siempre — base → sm: → md: → lg:
- Touch targets mínimo 44×44px
- font-size ≥ 16px en inputs móvil (evita zoom iOS)
- Nunca información accesible solo por hover
- {[COMPLETAR] reglas específicas del proyecto}

## ❌ Anti-patrones Detectados / Prohibidos

{Detectar de errores en bitácora si existe. Si no → listar los más comunes del stack}

- No usar colores hardcodeados — siempre var(--token)
- No crear componentes custom si ya existe uno en el proyecto
- {[COMPLETAR] anti-patrones propios del proyecto}

## Recursos

- ui-ux-pro-max: estilos, paletas, patrones generales → activar para decisiones de diseño
- emilkowalski/skill: animaciones y motion design → activar al implementar transiciones
- {[COMPLETAR] links a Figma, Storybook u otros recursos del equipo}
```

Si ya existe `.claude/skills/{project-slug}-design-system/SKILL.md` → NO sobreescribir. Reportar "skill de design system ya existe".
Si existe `design-system.md` en el proyecto → reportar cuántos tokens/secciones se extrajeron automáticamente.
Si no hay stack UI detectado (proyecto backend puro) → skip este paso.

---

## Paso 5 — Pre-identificar zonas de riesgo

Basado en el stack y los patrones conocidos, identificar archivos/módulos que típicamente
son frágiles. Si CLAUDE.md ya tiene un mapa de riesgo, enriquecerlo.

---

## Paso 6 — Guardar resultados

### Siempre (ambos modos):

Escribir `{PROJECT_ROOT}/.claude/memory/helix-analysis.md` con SOLO el resumen ejecutivo:

```markdown
# Helix Analysis — {nombre}
> Generado: {fecha} | Modo: vector|file | Actualizar con: /helix-actualiza
> ⚠️ Si este archivo tiene >30 días, ejecutar /helix-actualiza

## Resumen ejecutivo
{≤150 palabras: stack, agentes clave, skills críticas, riesgos principales}

## Stack (resumen)
Backend: {x} | Frontend: {x} | DB: {x} | Auth: {x} | Infra: {x}

## Agentes prioritarios para este proyecto
{lista corta: agente → cuándo usarlo aquí}

## Skills críticas
{lista: skill → disponible/falta}

## MCPs recomendados
{lista: mcp → disponible/falta}

## Zonas de riesgo iniciales
{lista: archivo → nivel → razón}
```

### Modo VECTOR (si MCP disponible):

Almacenar en vector memory con namespace `helix/{project_name}/`:
- `helix/{name}/stack` → JSON completo del stack detectado
- `helix/{name}/agents` → mapeo detallado de agentes
- `helix/{name}/skills` → skills completas con razones
- `helix/{name}/mcps` → MCPs recomendados con estado
- `helix/{name}/team` → roster del equipo con output contracts
- `helix/{name}/risks` → zonas de riesgo con contexto
- `helix/{name}/plans/` → namespace reservado para planes de ejecución (se llena automáticamente al completar reqs)

### Modo FILE (fallback):

Escribir `{PROJECT_ROOT}/.claude/memory/helix-analysis-full.md` con todos los detalles.

---

## Paso 7 — Inicializar bitácora y backlog

### Bitácora

Si `helix-bitacora.md` NO existe → crearlo:

```markdown
# Helix Bitácora — {nombre del proyecto}
> Iniciada: {fecha}
> Propósito: Registro continuo. Helix actualiza automáticamente vía hook PostToolUse.

## 📝 Cambios Realizados
| Fecha | Archivo(s) | Cambio | Sesión |
|-------|-----------|--------|--------|

## 💡 Recomendaciones
| Fecha | Recomendación | Estado |
|-------|--------------|--------|

## 🐛 Errores Cometidos
| Fecha | Error | Solución | Aprendizaje |
|-------|-------|----------|-------------|

## 🧠 Decisiones de Diseño Validadas
| Fecha | Decisión | Por qué |
|-------|---------|---------|
```

Si ya existe → NO sobreescribir. Informar que existe.

### Backlog

Si `helix-backlog.md` NO existe → crearlo:

```markdown
# Helix Backlog — {nombre del proyecto}
> Iniciado: {fecha} | Helix actualiza automáticamente al completar requerimientos.

## 🔵 En Progreso
| ID | Requerimiento | Agentes | Inicio |
|----|--------------|---------|--------|

## 🟡 Pendiente
| ID | Requerimiento | Prioridad | Notas |
|----|--------------|-----------|-------|

## 🟢 Completado
| ID | Requerimiento | Fecha | Resultado |
|----|--------------|-------|-----------|

## 🔴 Bloqueado
| ID | Requerimiento | Bloqueado por | Desde |
|----|--------------|---------------|-------|
```

Si ya existe → NO sobreescribir.

---

## Paso 8 — Reportar al usuario

Mostrar resumen breve:
- Stack detectado (1 línea)
- Equipo definido (tabla compacta de helix-team.md)
- MCPs recomendados: disponibles vs faltantes
- Skills faltantes (si hay)
- Design system skill: creado / ya existía / skipped (backend puro)
  - Si creado → indicar qué se auto-pobló y qué secciones requieren completar manualmente
- Zonas de riesgo iniciales
- Modo usado (vector/file) y qué se guardó
- Confirmar que no volverá a preguntar automáticamente

---

## Si el usuario dijo "no" al análisis automático

```bash
mkdir -p {PROJECT_ROOT}/.claude/memory
touch {PROJECT_ROOT}/.claude/memory/.analysis-declined
```

Decir: "Entendido. Cuando quieras: `/helix-analiza`. No vuelvo a preguntar."
