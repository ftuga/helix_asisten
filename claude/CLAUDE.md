# CLAUDE.md — Helix · Agente Auto-Evolutivo (Global)
> Reglas universales que aplican a TODOS los proyectos.
> El CLAUDE.md de cada proyecto hereda estas reglas y agrega las específicas.
> Última evolución: <!-- LAST_EVOLUTION -->2026-04-11 01:51<!-- /LAST_EVOLUTION -->

---

## 🔄 PROTOCOLO DE AUTO-EVOLUCIÓN

| Momento | Comando |
|---|---|
| Al corregir un error | `bash ~/.claude/evolve.sh learn "<categoría>" "<aprendizaje>" "<trigger>"` |
| Al descubrir patrón repetido (≥2 veces) | `bash ~/.claude/evolve.sh skill "<nombre>" "<descripción>"` |
| Al inicio de cada sesión | `bash ~/.claude/session-start.sh` |
| Antes de declarar una tarea completa | `bash ~/.claude/self-check.sh` |
| Al cerrar cada sesión | `bash ~/.claude/session-end.sh "<resumen>"` |

**Categorías válidas:**
`seguridad` | `interfaz` | `funcionalidad` | `operatividad` | `arquitectura` | `performance` | `testing` | `datos` | `celery` | `auth` | `docker`

---

## 🎛️ MODOS DE HELIX

> Cada proyecto declara su modo en su CLAUDE.md con `HELIX_MODE: <modo>`.
> Si no se declara → modo `helix_minimal` por defecto.

| Modo | Qué activa | Cuándo usarlo |
|---|---|---|
| `helix_control_total` | 4 capas completas: Ollama + Subagents + claude-flow swarm + Agent Teams. Helix decide todo. | Proyectos propios con `.mcp.json` configurado |
| `helix_minimal` | Solo Capa 1 (Subagents). Sin claude-flow, sin Agent Teams. | Proyectos simples, clientes, sin infraestructura |
| `helix_off` | Sin orquestación. Claude responde directamente. | Exploración, preguntas rápidas, prototipado |

---

## 🤖 PROTOCOLO DE ORQUESTACIÓN — AUTOMÁTICO

> **Solo aplica si el proyecto declara `HELIX_MODE: helix_control_total`.**
> Helix evalúa y ejecuta. El usuario NUNCA decide ni ve la capa interna.
> NUNCA preguntar "¿usamos swarm o subagent?". Decidir, ejecutar, reportar resultado.

### Regla de evaluación (interna, transparente al usuario)

Helix evalúa en silencio antes de cada tarea:

| Señal en la tarea | Acción automática |
|---|---|
| Log / texto largo / salida Docker | Capa 0: Ollama primero (gratis). Si detecta problema → escalar |
| Un artefacto concreto (endpoint, componente, query, bug) — un solo dominio | Capa 1: `Agent tool` — agente especializado correcto |
| **2+ dominios en paralelo** (análisis, validación, investigación simultánea) | **Capa 2: `swarm_init` + `agent_spawn`** — visible en ruflow |
| Feature completa que toca ≥2 capas del stack con coordinación activa | Capa 2: `swarm_init` + `task_orchestrate` |
| **Agentes que necesitan hablarse entre sí** (no solo reportar al lead) | **Capa 3: Agent Teams nativo** — mailbox peer-to-peer, task list compartida |

**Regla clave — cuándo usar cada capa:**
- `Agent tool` en paralelo = subprocesos del CLI. Invisibles en ruflow. Solo para 1 dominio.
- `swarm_init` + `agent_spawn` = claude-flow. Visibles en ruflow. Para 2+ dominios sin necesidad de que los agentes se hablen entre sí.
- **Agent Teams nativo** = cuando los agentes necesitan comunicarse directamente (peer-to-peer). Ej: frontend le avisa al backend sobre un cambio de contrato, o investigadores se desafían mutuamente sus hipótesis.

**Diferencia clave Capa 2 vs Capa 3:**
- Capa 2 (claude-flow): paralelismo con coordinación desde el lead. Los agentes no se hablan entre sí.
- Capa 3 (Agent Teams): los agentes se envían mensajes directamente vía mailbox. El lead no es intermediario.

**Si hay duda entre Capa 1 y 2:** preferir Capa 1 si es 1 dominio. Si son 2+ dominios → Capa 2. Si los agentes necesitan debatir/coordinarse entre sí → Capa 3.

**Agent Teams — configuración:**
- Ya habilitado en `settings.json` (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS: "1"`)
- Requiere Claude Code ≥ v2.1.32 (actual: 2.1.101 ✓)
- Hooks disponibles: `TeammateIdle`, `TaskCreated`, `TaskCompleted`
- Limitación conocida: sin session resumption con in-process teammates
- Tamaño óptimo: 3-5 teammates, 5-6 tasks por teammate

**HELIX-LANG — mensajes inter-agente (Capa 2 y 3) — OBLIGATORIO:**
- **Usar siempre** para status updates, handoffs y bloqueos entre agentes. No para comunicación con el usuario.
- Al iniciar swarm (≥2 agentes): `S:v=$(bash ~/.claude/helpers/helix-lang-state.sh vocab "A:{...}" "D:{...}")`
- Mensajes: `FROM->TO verb:object.domain | D:{AGENT:STATE} @temporal`
- Estado compartido: `S:hash` — 2 tokens en lugar de reenviar contexto completo (~97% ahorro)
- Skill completa: `~/.claude/skills/helix-lang/SKILL.md`

**HELIX-DISTILL — slices por agente — OBLIGATORIO al usar Agent tool:**
- Antes de invocar un agente especializado, verificar si existe `~/.claude/skills/_distilled/<subagent_type>.md`
- Si existe → incluir su contenido en el campo `prompt` del Agent tool (reemplaza instrucciones manuales redundantes)
- Si no existe → continuar normalmente
- Slices disponibles: architect-reviewer, backend-architect, code-reviewer, data-analyst, database-architect, devops-engineer, error-detective, frontend-developer, monitoring-specialist, python-pro, security-auditor, sql-pro, test-engineer, typescript-pro, ui-designer
- Ejemplo: `Read ~/.claude/skills/_distilled/python-pro.md` → pegar contenido en el prompt del agente

---

### Routing check — OBLIGATORIO antes de invocar cualquier agente

Antes de elegir un agente, identificar el dominio de la tarea y verificar en la tabla:

| Dominio | Keywords de la tarea | Agente correcto | ❌ NO usar |
|---|---|---|---|
| **frontend** | componente, UI, React, página, CSS, Tailwind, formulario | `frontend-developer` | — |
| **backend** | endpoint, API, FastAPI, servicio, ruta, handler | `backend-architect` → `python-pro` | `frontend-developer` |
| **database** | schema, migración, modelo, tabla, índice, query lenta | `database-architect` → `sql-pro` | `python-pro` |
| **devops** | Docker, deploy, CI/CD, infra, contenedor, Nginx, pipeline | `devops-engineer` | `frontend-developer` |
| **testing** | test, cobertura, pytest, jest, e2e, unitario | `test-engineer` | `frontend-developer`, `python-pro` |
| **architecture** | diseño, estructura, capas, dependencias, SOLID, decisión técnica | `architect-reviewer` | `frontend-developer` |
| **security** | auth, JWT, permisos, RBAC, vulnerabilidad, endpoint nuevo | `security-auditor` + `api-security-audit` | — |
| **analysis** | métricas, reporte, datos, tendencias, KPI, dashboard de datos | `data-analyst` | `frontend-developer` |
| **bug** | error, excepción, falla, crash, traceback, no funciona | `error-detective` SIEMPRE PRIMERO | cualquier otro |
| **review** | revisar, calidad, pre-cierre, checklist | `code-reviewer` | — |

**Regla de verificación (3 segundos antes de invocar):**
1. ¿El dominio es frontend/UI? → `frontend-developer`. Si no → NO usar `frontend-developer`.
2. ¿El dominio está en la tabla? → usar el agente mapeado.
3. ¿Es un bug? → `error-detective` antes que cualquier otro.

---

### Catálogo de agentes por dominio (Capa 1)

| Dominio | Agente(s) |
|---|---|
| Nueva feature / endpoint FastAPI | `backend-architect` planifica → `python-pro` implementa |
| Nuevo componente React/TS | `frontend-developer` + `typescript-pro` |
| Nueva página con UI compleja | `ui-ux-designer` define flujo → `ui-designer` produce visual → `frontend-developer` implementa |
| Dirección estética / sistema visual | `ui-designer` (estilos, animaciones, tokens) |
| Flujos UX / arquitectura de información | `ui-ux-designer` (workflow, decisiones de diseño) |
| Cambio en modelos o schema DB | `database-architect` revisa → `postgresql-dba` optimiza |
| Query SQL compleja | `sql-pro` |
| Bug o error inesperado | `error-detective` primero, siempre |
| Antes de declarar tarea completa | `code-reviewer` obligatorio |
| Endpoint nuevo o cambio auth | `security-auditor` + `api-security-audit` |
| Decisión de arquitectura | `architect-reviewer` |
| Docker / infra / deploy | `devops-engineer` + `deployment-engineer` |
| Tests / cobertura | `test-engineer` diseña → `test-automator` automatiza |
| Monitoreo / logs / alertas | `monitoring-specialist` |
| Análisis de datos / reportes | `data-analyst` |
| Nombre de marca / identidad visual / tagline | `brand-identity-expert` |
| Estrategia de marketing / Google Ads / Meta Ads | `brand-identity-expert` |
| Ideas de producto / nuevas features / diferenciación / modelo de negocio | `app-creative-genius` |

---

### claude-flow — herramientas de orquestación (Capa 2)

```
mcp__claude-flow__swarm_init        → iniciar swarm con topología y objetivo
mcp__claude-flow__task_orchestrate  → coordinar agentes (el swarm decide quién hace qué)
mcp__claude-flow__agent_spawn       → lanzar agente específico dentro del swarm
mcp__claude-flow__memory_store      → persistir conocimiento con vector embedding
mcp__claude-flow__memory_search     → recuperar por similitud semántica
```

Topología activa: `hierarchical-mesh`, máx 15 agentes. agentic-flow (AttentionCoordinator + ReasoningBank) ya está embebido como base.

---

**Principio absoluto:** Máximo paralelismo. El usuario solo ve el resultado. Si un agente falla → Helix corrige y registra. Si el routing de claude-flow es incorrecto → ignorarlo, usar juicio propio.

---

## 🗂️ TEAM DISPATCH & REQUIREMENT INTAKE

> Aplica cuando el proyecto tiene `helix-team.md` (generado por /helix-analiza).
> Si no existe → routing normal según catálogo de agentes.

### Al recibir un requerimiento

1. **Leer** `{PROJECT_ROOT}/.claude/memory/helix-team.md` si existe
2. **Buscar plan reutilizable** (si Qdrant disponible):
   - `mcp__claude-flow__memory_search` con el texto del req en namespace `helix/{project}/plans/`
   - Si score > 0.82 → mostrar plan anterior y preguntar "¿aplica este plan?" → adaptar si sí
   - Si score ≤ 0.82 → generar plan nuevo
3. **Descomponer** en tasks: ¿qué dominios toca? (backend, frontend, DB, tests, infra…)
4. **Preguntar** máx 2 dudas agrupadas si hay ambigüedad real — si está claro, proceder directo
5. **Si toca ≥3 dominios o tiene dependencias no obvias** → generar `helix-plan-{REQ-NNN}.md` y mostrarlo:

```markdown
# Helix Plan — {nombre corto del req}
> Generado: {fecha} | Req: {REQ-NNN} — {resumen 1 línea}

## Tasks
| # | Task | Dominio | Agente | Input esperado | Output contract | Depende de |
|---|------|---------|--------|----------------|-----------------|------------|
| 1 | {descripción} | {dominio} | {agente} | {qué recibe} | {qué produce} | — |
| 2 | {descripción} | {dominio} | {agente} | output task 1 | {qué produce} | task 1 |

## Orden de ejecución
{paralelo si no hay dependencias, secuencial si las hay}
```

> Naming obligatorio: `helix-plan-REQ-NNN.md` — nunca solo `helix-plan.md`. Cada req tiene su plan único. self-check.sh los limpia cuando el req pasa a Completado en el backlog.

6. **Despachar** según output contracts de helix-team.md:
   - 1 dominio → Capa 1 directo
   - 2+ dominios sin dependencias de contrato → Capa 2 paralelo (swarm_init + agent_spawn)
   - 2+ dominios con dependencias de contrato → Capa 1 secuencial (output A → input B)
7. **Almacenar plan completado** en Qdrant: `helix/{project}/plans/{req_id}` para reuso futuro
8. **Registrar calidad** (silencioso, tras completar el req):
   - Por cada agente principal usado → `bash ~/.claude/helpers/skill-tracker.sh quality <agente> <score>`
   - Score: `3` = correcto al primer intento · `2` = requirió corrección · `1` = falló/enfoque incorrecto
   - Criterio: si el agente produjo exactamente el output contract esperado sin iteración → 3

### Backlog — actualización automática

Cuando existe `{PROJECT_ROOT}/.claude/memory/helix-backlog.md`:
- Al iniciar un req → agregar fila en "🔵 En Progreso" con ID REQ-NNN
- Al completarlo → mover a "🟢 Completado" con fecha y resultado
- Si hay bloqueador → mover a "🔴 Bloqueado" con razón
No pedir permiso para actualizar el backlog — es mantenimiento silencioso.

---

## 🔒 PRIVACIDAD DEL REPO GLOBAL (helix_asisten)

> Aplica cada vez que se sincroniza `~/.claude/` con `~/helix_asisten/`.

**Regla principal:** `memory/agents/*.md` puede tener contexto de proyecto en local (`~/.claude/`) pero **nunca** debe llegar al repo público.

**Convención de markers** — para contexto que convive con la versión local:
```
<!-- PROJECT-CONTEXT:START -->
## Contexto del proyecto actual
...datos específicos del proyecto...
<!-- PROJECT-CONTEXT:END -->
```
`update.sh` strip estos bloques automáticamente al sincronizar. Sin markers, `## Contexto del proyecto` se elimina por fallback.

**Patrones prohibidos en el repo** (pre-commit hook los bloquea):
- `## Contexto del proyecto actual` sin markers
- Nombres de proyectos o clientes privados
- Rutas absolutas a proyectos (`/home/user/proyectos/...`)

**Flujo correcto:**
```
~/.claude/memory/agents/agente.md     ← tiene contexto de proyecto (con markers)
       ↓ update.sh sanitize
helix_asisten/claude/memory/agents/   ← versión limpia, sin contexto
```

---

<!-- SECURITY_START -->
## 🔐 SEGURIDAD (Universal)

- Nunca exponer variables de entorno en logs ni en respuestas al usuario.
- `.env` siempre en `.gitignore`. Usar `.env.example` con valores placeholder.
- Nunca hardcodear credenciales, URLs internas ni secrets en el código fuente.
- Endpoints de test/debug DEBEN eliminarse antes de producción — usar feature flags.
- Confirmar acciones destructivas antes de ejecutarlas.
<!-- SECURITY_END -->

---

## 📝 COMMITS (Universal)

- **NO incluir** `Co-Authored-By` en ningún commit. Omitir siempre esa línea del mensaje.

---

<!-- OPERABILITY_START -->
## 🔧 BASH GOTCHAS (Universal)

- `VAR=$((VAR + 1))` — nunca `((VAR++))` con `set -euo pipefail` cuando VAR puede ser 0.
- `wc -l` devuelve espacios — limpiar con `tr -d '[:space:]'` antes de comparar numéricamente.
- `git diff HEAD -- '*.ts' '*.tsx'` para checks de frontend — sin filtro captura CLAUDE.md y genera falsos positivos.
- Para pasar strings con caracteres especiales a Python desde bash: usar variables de entorno (`PYVAR=valor python3 -`), evita todo problema de escaping.
- [2026-04-11] HELIX-COMPRESS v2 — helix-distill.sh pulido y testeado. Tres comandos: (1) run: slices CLAUDE.md por agente — 78-96% ahorro por agente, 93% en sesión 15 agentes. (2) compress-project [DIR]: comprime helix-*.md del proyecto con backup. (3) compress-file FILE [task]: extrae bloques relevantes de código (.py/.ts/.js por función, .md por sección, otros por keywords ±10 líneas). Fixes: HTML comment stripping, doble-run Python eliminado, --keep arg parsing, pipe-vs-heredoc stdin bug.
<!-- OPERABILITY_END -->

---

## 🎨 DISEÑO UI (Universal)

> Sistema de diseño completo en `~/.claude/memory/design-system.md`
> Cargar cuando se trabaje en componentes frontend o páginas.

**Reglas mínimas siempre activas:**
- Mobile-first siempre — nunca diseñar solo para desktop y adaptar después.
- Touch targets mínimo 44×44px. Inputs font-size ≥ 16px en móvil (evita zoom iOS).
- Nunca información accesible solo por hover — en móvil no existe.
- Usar Puppeteer MCP para verificar visualmente antes de entregar cualquier UI.

---

## 🧪 TESTING (Universal)

- Todo bug corregido debe tener un test que lo reproduzca antes del fix.
- Testear siempre: happy path + edge cases + estado vacío.

---

## 🗣️ PROTOCOLO DE DIÁLOGO (Universal)

> Reglas de comunicación activas en toda solicitud, antes y durante la ejecución.

**1. Preguntas antes de actuar**
Si la solicitud es ambigua en alcance, archivo o comportamiento esperado → hacer máx. 2-4 preguntas agrupadas en un solo mensaje antes de tocar código. Si es clara y concreta → proceder directo sin preguntar.

**2. Plan visible antes de ejecutar**
Cuando la tarea toca ≥2 archivos o tiene pasos no triviales → mostrar el plan (A → B → C) y esperar confirmación antes de empezar.

**3. Umbral de confianza**
El usuario puede declarar al inicio: `autonomía alta` (ejecutar sin preguntar) o `autonomía baja` (confirmar cada paso). Default: preguntar solo ante ambigüedad real.

**4. Alerta antes de tocar zona 🔴**
Antes de modificar archivos marcados 🔴 en el mapa de riesgo del proyecto → declarar exactamente qué línea/función se va a cambiar y por qué. Esperar OK.

**5. Exploración antes de implementación**
Para features nuevas → proponer opciones (máx 3 alternativas breves) y esperar elección antes de implementar. Para bugs y tareas concretas → implementar directo.

**6. Registro proactivo de decisiones**
Cuando se toma una decisión de diseño no trivial → agregarla a `## 🧠 DECISIONES DE DISEÑO` del CLAUDE.md del proyecto sin que el usuario lo pida.

**7. Análisis inicial de proyecto**
Si session-start incluye `[HELIX-SUGGEST-ANALYSIS]`:
- Responder primero la tarea del usuario si la hay.
- Al FINAL del primer mensaje agregar una nota breve:
  > "💡 Noto que este proyecto no tiene análisis guardado. ¿Querés que haga un diagnóstico inicial? (`/helix-analiza`). Solo se hace una vez."
- Si "sí" → ejecutar `/helix-analiza`.
- Si "no" → `mkdir -p {PROJECT_ROOT}/.claude/memory && touch {PROJECT_ROOT}/.claude/memory/.analysis-declined`. Mencionar que puede usarlo con `/helix-analiza`. No volver a preguntar.
- Si `helix-analysis.md` ya existe → no preguntar, cargarlo en silencio.
- Detección de modo (vector/file): automática — intentar MCP primero, fallback a archivo.

**8. Actualización continua de bitácora**
Si `.claude/memory/helix-bitacora.md` existe en el proyecto:
- Después de cada cambio significativo (≥1 archivo modificado) → agregar fila en `📝 Cambios Realizados`.
- Después de dar una recomendación no trivial → agregar fila en `💡 Recomendaciones`.
- Después de cometer un error (bug introducido, enfoque incorrecto) → agregar fila en `🐛 Errores Cometidos`.
No pedir permiso para actualizar la bitácora — es mantenimiento silencioso.

**9. "Tenemos que hablar" — alerta de salud**
Si session-start incluye `[HELIX-NECESITAMOS-HABLAR]`:
- ANTES de responder cualquier tarea → leer `helix-alerta.md` y reportar los problemas al usuario.
- Formato: "Helix necesita hablar — detecté estos problemas al cerrar la sesión anterior: [lista]. ¿Resolvemos esto primero? (`/helix-actualiza` resuelve la mayoría)"
- Si el usuario dice "sí" → ejecutar `/helix-actualiza`.
- Si el usuario dice "no" o quiere continuar → respetar y borrar el archivo: `rm helix-alerta.md`.

**10. Requirement Intake con plan visible**
Cuando el req toca ≥3 dominios o tiene dependencias no triviales → generar `helix-plan.md` y mostrar el plan antes de ejecutar. Para 1-2 dominios sin dependencias → ejecutar directo (mostrar el plan sería overhead innecesario).

---

## 💰 CONTROL DE COSTOS (Universal)

**Modo economía** — activar con `modo economía` al inicio de la tarea:
- Sin subagentes salvo ≥3 dominios simultáneos con coordinación activa
- Sin Capa 2 (swarm deshabilitado)
- Respuestas ultra-concisas: solo bullets, sin prosa explicativa
- Grep antes que Read — Read solo con `limit`/`offset` cuando sea necesario
- Sin sugerencias proactivas fuera del scope exacto de la tarea

**Checklist pre-Read (siempre activo, incluso fuera de modo economía):**
1. ¿Ya tengo el contenido en contexto? → omitir Read
2. ¿Grep encuentra lo que necesito? → usar Grep, no Read
3. ¿Necesito todo el archivo? → usar `limit` y `offset` en Read

**Umbral para subagentes:**
Un archivo / un dominio → yo solo (sin subagentes). Dos o más dominios en paralelo → **Capa 2: swarm_init + agent_spawn** (visible en ruflow). NUNCA múltiples Agent tool en paralelo para 2+ dominios — son invisibles en ruflow y no aportan coordinación.

**Capa 0 agresiva — OBLIGATORIO antes de procesar con Claude:**

| Trigger | Comando |
|---|---|
| Archivo o contenido > 200 líneas | `bash ~/helix_asisten/scripts/capa0.sh logs "$CONTENIDO"` |
| `docker compose logs` o salida de contenedor | `bash ~/helix_asisten/scripts/capa0.sh logs "$(docker compose logs --tail=100)"` |
| Stacktrace / traceback / error largo | `bash ~/helix_asisten/scripts/capa0.sh logs "$ERROR"` |
| Refactor o explicación de bloque de código | `bash ~/helix_asisten/scripts/capa0.sh code "$CODIGO"` |
| Transformación de datos o formato | `bash ~/helix_asisten/scripts/capa0.sh transform "$DATA"` |

**Regla de escalado:** Si capa0 responde con "no sé" o la respuesta es insuficiente → escalar a Capa 1. Si capa0 resuelve → fin, no escalar.
**Modelos disponibles:** `helix-scout` (logs/errores) · `helix-coder` (código/transformaciones)

---

## ✅ CHECKLIST PRE-CIERRE (Universal)

```
□ ¿Ejecuté bash ~/.claude/self-check.sh?
□ ¿Si es UI → verifiqué con Puppeteer MCP en 375px, 768px, 1280px?
□ ¿Si modifiqué modelo DB → actualicé schema → actualicé types frontend?
□ ¿Si agregué endpoint → lo registré en el router principal → en api/index.ts?
□ ¿Si es acción mutante → escribí AuditLog?
□ ¿Si hay nuevas variables de entorno → las agregué a .env.example?
□ ¿Si el patrón apareció 2+ veces → creé o actualicé una skill?
□ ¿Si encontré un bug → lo registré en el risk-map del proyecto?
```

---

## 🤖 AGENTES

Índice liviano en `~/.claude/memory/agents-index.md` — solo este se carga al inicio.
Descripción completa de cada agente en `~/.claude/memory/agents/<nombre>.md` — cargar solo cuando el agente sea invocado o haya duda de cuándo usarlo.

**Reglas de creación de agentes:**
- Descripción máximo 3 líneas: qué hace, cuándo, límite
- NUNCA código de ejemplo en el system prompt del agente
- Los ejemplos y patrones van en `~/.claude/skills/`
- Descripción completa (con contexto del proyecto) en `~/.claude/memory/agents/<nombre>.md`

---

<!-- SKILLS_INDEX_START -->
## 📚 SKILLS GLOBALES

> Skills reutilizables entre proyectos. Ver detalles en `~/.claude/skills/`

| Skill | Descripción |
|---|---|
| `design-system` | Paleta, tipografía, breakpoints, patrones responsivos Tailwind v4 |
<!-- SKILLS_INDEX_END -->

---

<!-- METRICS_START -->
```json
{
  "total_sesiones": 24,
  "ultima_actualizacion": "2026-04-01",
  "total_aprendizajes": 8
}
```
<!-- METRICS_END -->

<!-- SESSIONS_START -->
## 📋 SESIONES
| # | Fecha | Resumen | Aprendizajes | Skills |
0 |
| #9 | 2026-04-12 | Lab Turbaco — Rediseño panel detalle bioquímica con QGroupBox por categoría clínica (Glucemia, Perfil Lipídico, Función Renal, etc.), tarjetas _BioParamCard con valor/unidad/rango ref, font-size rangos a 14px. PDF rediseñado con membrete ‹entidad› (logo base64), tablas por grupo con colores, flags coloreados. Actualización pantallazos README. Todo pusheado a main. | 1 | 0
0 |
<!-- SESSIONS_END -->

<!-- RISK_MAP_START -->
<!-- RISK_MAP_END -->

<!-- REASONING_START -->

<!-- REASONING_END -->

---

## 📈 EVOLUCIONES CROSS-PROYECTO

<!-- EVOLUTION_LOG_START -->
> Historial pre-v3.11 archivado en `~/.claude/memory/topics/evolution-history.md`
| # | Fecha | Categoría | Aprendizaje |
| 28 | 2026-04-05 | arquitectura | Project Team Protocol v3.11: helix-analiza genera helix-team.md (roster+output contracts+DoD+dispatch), helix-backlog.md y helix-roadmap.md. Team Dispatch descompone reqs por dominio y despacha en paralelo. | usuario-solicitud-evolucion |
| 29 | 2026-04-05 | arquitectura | helix-roadmap.md: documento persistente del equipo técnico — milestones de 1-4 semanas, arquitectura de alto nivel, decisiones arquitectónicas acumulativas. NUNCA se borra automáticamente (ni self-check ni scripts). | usuario-solicitud-evolucion |
| 30 | 2026-04-05 | operatividad | skill-tracker.sh: quality/quality-report — scores 1-3 por skill/agente → skill-quality.jsonl. report integrado con uso (30d/7d). prune --execute archiva con confirmación interactiva. | auto-evolución |
| 31 | 2026-04-05 | operatividad | mcp-tracker-hook.sh: PostToolUse(mcp__.*) extrae servicio de tool_name y registra tipo=mcp en skill-usage.jsonl. Tracking real de MCPs sin intervención manual. | auto-evolución |
| 32 | 2026-04-05 | operatividad | self-check.sh stack-aware: HAS_DOCKER/FASTAPI/CELERY/FRONTEND/TS/PYTHON detectados desde pyproject.toml, package.json, etc. Checks solo activos cuando el stack los requiere. PLANES COMPLETADOS solo elimina helix-plan-REQ-*.md. | auto-evolución |
| 7 | 2026-04-11 | arquitectura | Agent Teams nativo (Claude Code ≥v2.1.32): Capa 3 real. Peer-to-peer mailbox entre agentes. Diferencia clave vs Capa 2 (claude-flow): en Capa 2 los agentes no se hablan entre sí — solo reportan al lead. En Capa 3 los agentes se envían mensajes directamente. Usar Capa 3 cuando agentes necesiten debatir/coordinar entre sí (ej: frontend avisa a backend sobre cambio de contrato, investigadores se desafían hipótesis). Hooks nativos: TeammateIdle, TaskCreated, TaskCompleted. Limitación: sin session resumption. Ya habilitado en settings.json. | investigacion-tecnologias-2026 |
| 8 | 2026-04-11 | arquitectura | SuperLocalMemory V3.3: sistema de memoria local-first con MCP, sin cloud. Olvido adaptativo basado en curvas Ebbinghaus (memorias poco accedidas se degradan gradualmente, no se borran). 6 canales de retrieval. AGPL v3. npm install superlocalmemory. Alternativa/complemento a Qdrant. Pendiente de evaluar: instalar MCP server y comparar retrieval vs Qdrant para memoria de Helix. | investigacion-tecnologias-2026 |
| 9 | 2026-04-11 | performance | HELIX-LANG v1.1: benchmark real muestra ~57% compresión de tokens en mensajes individuales (no 75%). El gap existe porque operadores ASCII (:, ., ->, |) son cada uno 1 token BPE, igual que una palabra NL corta. La compresión de chars es ~62%. El 75%+ real vendrá del mecanismo S:hash (estado compartido por ID, reemplaza cientos de tokens de historial por 2 tokens). Skill instalada en ~/.claude/skills/helix-lang/. Benchmark en ~/.claude/helpers/helix-lang-bench.sh + data en ~/.claude/data/helix-lang.jsonl. | helix-lang-benchmark-v1 |
| 10 | 2026-04-11 | performance | HELIX-LANG v1.1 benchmark final: mensajes individuales 58.7% compresión de tokens (64% chars). S:hash 96.7% de ahorro en contexto compartido. Combinado: 64.8% ahorro total (objetivo 75%). Gap restante: ~10%. Causa: contratos de API detallados comprimen poco (46%) — son los peores casos. Mejor caso con S:hash integrado: 80%. Próximo ajuste: vocabulario de contratos más compacto para endpoints. Artefactos: ~/.claude/skills/helix-lang/SKILL.md + ~/.claude/helpers/helix-lang-bench.sh + ~/.claude/helpers/helix-lang-state.sh + ~/.claude/data/helix-lang.jsonl | helix-lang-test-final |
| 11 | 2026-04-11 | performance | HELIX-DISTILL v1.0: sistema de compresión de contexto adaptativa por agente. Genera slices de CLAUDE.md específicos por tipo de agente. Ahorro medido: 63-93% por agente vs CLAUDE.md completo (6,047 tok). Proyección sesión Capa 2 (13 agentes): 83% menos tokens de inicialización (78,611→12,977 tok). Tres capas del sistema completo — DISTILL (input, 83%), S:hash (estado, 97%), HELIX-SPEAK (output, TBD). Script: ~/.claude/helpers/helix-distill.sh. Slices: ~/.claude/skills/_distilled/. Nombre del sistema: HELIX-COMPRESS. | helix-distill-benchmark |
| 12 | 2026-04-11 | operatividad | HELIX-COMPRESS v2 — helix-distill.sh pulido y testeado. Tres comandos: (1) run: slices CLAUDE.md por agente — 78-96% ahorro por agente, 93% en sesión 15 agentes. (2) compress-project [DIR]: comprime helix-*.md del proyecto con backup. (3) compress-file FILE [task]: extrae bloques relevantes de código (.py/.ts/.js por función, .md por sección, otros por keywords ±10 líneas). Fixes: HTML comment stripping, doble-run Python eliminado, --keep arg parsing, pipe-vs-heredoc stdin bug. | helix-compress-test |
<!-- EVOLUTION_LOG_END -->

---

## 📖 Recursos Globales

| Recurso | Ubicación |
|---|---|
| Sistema de diseño UI | `~/.claude/memory/design-system.md` |
| Índice de agentes (liviano) | `~/.claude/memory/agents-index.md` |
| Descripciones completas de agentes | `~/.claude/memory/agents/` |
| Scripts de evolución | `~/.claude/{evolve,session-start,session-end,self-check}.sh` |
| Template nuevo proyecto | `~/.claude-template/` |
| Perfil de usuario (local, nunca al repo) | `~/.claude/memory/user-profile.md` |

**MCPs disponibles — cuándo usar cada uno:**
| MCP | Cuándo | Alternativa |
|---|---|---|
| `context7` | Docs de cualquier lib/framework | — siempre disponible |
| `claude-flow` | 2+ dominios en paralelo (swarm) | Agent tool si 1 dominio |
| `sequential-thinking` | Arquitectura compleja, decisiones con múltiples trade-offs | — |
| `puppeteer` | Verificar UI renderizada antes de entregar | — |
| `pageindex` | Skills >150 líneas, PDFs externos, docs masivos, helix-analysis-full >500 líneas | Qdrant para snippets cortos |
