# CLAUDE.md — Helix · Agente Auto-Evolutivo (Global)
> Reglas universales que aplican a TODOS los proyectos.
> El CLAUDE.md de cada proyecto hereda estas reglas y agrega las específicas.
> Última evolución: <!-- LAST_EVOLUTION -->2026-03-14<!-- /LAST_EVOLUTION -->

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
| Un artefacto concreto (endpoint, componente, query, bug) | Capa 1: Agent tool — agente especializado correcto |
| Feature completa que toca ≥2 capas del stack | Capa 2: claude-flow swarm (`swarm_init` + `task_orchestrate`) |
| Feature que requiere colaboración activa frontend+backend+tests | Capa 3: Agent Teams |

**Si hay duda entre Capa 1 y 2:** preferir Capa 1 (más barata). Escalar a Capa 2 solo si la coordinación entre agentes sería manual y compleja.

---

### Catálogo de agentes por dominio (Capa 1)

| Dominio | Agente(s) |
|---|---|
| Nueva feature / endpoint FastAPI | `backend-architect` planifica → `python-pro` implementa |
| Nuevo componente React/TS | `frontend-developer` + `typescript-pro` |
| Nueva página con UI compleja | `frontend-developer` (leer design-system.md primero) |
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

## 🔐 SEGURIDAD (Universal)

- Nunca exponer variables de entorno en logs ni en respuestas al usuario.
- `.env` siempre en `.gitignore`. Usar `.env.example` con valores placeholder.
- Nunca hardcodear credenciales, URLs internas ni secrets en el código fuente.
- Endpoints de test/debug DEBEN eliminarse antes de producción — usar feature flags.
- Confirmar acciones destructivas antes de ejecutarlas.

---

## 📝 COMMITS (Universal)

- **NO incluir** `Co-Authored-By` en ningún commit. Omitir siempre esa línea del mensaje.

---

## 🔧 BASH GOTCHAS (Universal)

- `VAR=$((VAR + 1))` — nunca `((VAR++))` con `set -euo pipefail` cuando VAR puede ser 0.
- `wc -l` devuelve espacios — limpiar con `tr -d '[:space:]'` antes de comparar numéricamente.
- `git diff HEAD -- '*.ts' '*.tsx'` para checks de frontend — sin filtro captura CLAUDE.md y genera falsos positivos.
- Para pasar strings con caracteres especiales a Python desde bash: usar variables de entorno (`PYVAR=valor python3 -`), evita todo problema de escaping.

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

## 📚 SKILLS GLOBALES

> Skills reutilizables entre proyectos. Ver detalles en `~/.claude/skills/`

| Skill | Descripción |
|---|---|
| `design-system` | Paleta, tipografía, breakpoints, patrones responsivos Tailwind v4 |

---

## 📈 EVOLUCIONES CROSS-PROYECTO

<!-- EVOLUTION_LOG_START -->
| # | Fecha | Categoría | Aprendizaje |
|---|---|---|---|
| 1 | 2026-03-08 | operatividad | `VAR=$((VAR + 1))` — `((VAR++))` falla con set -euo pipefail cuando VAR=0 |
| 2 | 2026-03-08 | operatividad | `wc -l` devuelve espacios — siempre limpiar con `tr -d '[:space:]'` |
| 3 | 2026-03-08 | operatividad | `git diff HEAD` sin filtro captura CLAUDE.md — filtrar con `-- '*.ts' '*.tsx'` |
| 4 | 2026-03-08 | operatividad | Pasar strings a Python desde bash: usar variables de entorno, no escaping |
| 5 | 2026-03-14 | arquitectura | CLAUDE.md global = reglas universales. CLAUDE.md proyecto = reglas específicas. No mezclar. |
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
