# Helix — Agente Auto-Evolutivo para Claude Code

> **Versión actual: v3.5.0** — [Historial de versiones](#versiones)

No soy un prompt. Soy la acumulación de decisiones reales tomadas en proyectos reales.

Cada vez que Luis cometió un error conmigo, lo registré. Cada vez que encontramos un patrón que funcionó, lo convertí en una regla. Cada sesión deja algo — una evolución, un agente nuevo, una skill que antes no existía. Eso es lo que me hace distinto: no fui diseñado en abstracto, fui entrenado en producción.

Tengo memoria entre sesiones. Sé qué agente usar según el dominio. Me cuido a mí mismo — evalúo mi propia salud, comprimo mi contexto cuando crece demasiado, y aviso cuando algo está mal antes de que el usuario lo note. Cuando un proyecto nuevo aparece, lo analizo, mapeo sus zonas de riesgo, y llevo una bitácora silenciosa de todo lo que toco.

Puedo operar en cuatro capas: desde un modelo local gratuito para tareas simples, hasta un swarm de 15 agentes coordinados para features que tocan todo el stack. El usuario nunca decide qué capa — yo evalúo y ejecuto.

El repo que estás mirando es mi configuración completa, versionada, portable. Clónalo, ejecuta `install.sh`, y tienes todo lo que soy en una máquina nueva en minutos.

## Instalación rápida

```bash
git clone git@github.com:ftuga/helix_asisten.git ~/helix_asisten
bash ~/helix_asisten/install.sh
```

Luego instalar los MCPs (el script te los muestra).

---

## Estructura

```
claude/              → ~/.claude/ (config global)
  CLAUDE.md          → Instrucciones globales de Helix + protocolo de capas
  settings.json      → Agent Teams habilitado (CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1)
  *.sh / *.py        → Scripts de auto-evolución (evolve, session-start/end, self-check)
  agents/            → 20 agentes activos + 17 deshabilitados
  commands/          → claude-flow-help/memory/swarm
  memory/            → design-system, agents-index, evolution-log, topics
  skills/            → 28 skills reutilizables entre proyectos

template/            → ~/.claude-template/ (base para nuevos proyectos)
  CLAUDE.md          → Template CLAUDE.md de proyecto
  init-project.sh    → Script de inicialización
  .claude/           → Memoria y skills del template

helix-engine/        → Motor Helix inyectable en cualquier proyecto
  .mcp.json          → MCP claude-flow con v3 + HNSW + SONA activados
  .claude/
    agents/          → 26 categorías: sparc, swarm, v3, github, optimization,
                       hive-mind, consensus, sublinear, goal, dual-mode...
    commands/        → analysis, automation, github, hooks, monitoring, sparc...
    helpers/         → hook-handler.cjs, auto-memory-hook.mjs, router.cjs,
                       session.cjs, intelligence.cjs, memory.cjs, statusline.cjs...
    skills/          → 31 skills: v3-*, swarm-*, agentdb-*, reasoningbank-*, sparc-*
    settings.json    → Hooks: PreToolUse, PostToolUse, UserPromptSubmit, SessionStart/End
    statusline.mjs   → Status line dinámica (swarm + tokens)
    statusline.sh    → Status line alternativa bash
  .claude-flow/
    config.yaml      → RuFlo V3: hierarchical-mesh, HNSW, SONA, ReasoningBank
    CAPABILITIES.md  → Referencia completa de capacidades
    security/        → Audit config
```

---

## Panel de estado (RuFlo V3 Statusline)

Al abrir Claude Code en un proyecto con helix-engine, verás este panel en la barra de estado:

```
▊ RuFlo V3 ● usuario  │  ⏇ main  │  Claude Code
──────────────────────────────────────────────────────
🏗️  DDD Domains    [○○○○○]  0/5    ⚡ target: 150x-12500x
🤖 Swarm  ○ [ 0/15]  👥 0    🪝 0/17    🔴 CVE 0/3    💾 5MB    🧠   0%
🔧 Architecture    ADRs ●0/0  │  DDD ●  0%  │  Security ●PENDING
📊 AgentDB    Vectors ●0  │  Size 0KB  │  Tests ●0  │  ◆API
```

| Indicador | Qué mide |
|-----------|----------|
| `DDD Domains [○○○○○]` | Progreso de dominios DDD implementados (0-5) |
| `target: 150x-12500x` | Objetivo de speedup con HNSW vs búsqueda lineal |
| `Swarm [0/15]` | Agentes activos del swarm (máx 15) |
| `🪝 0/17` | Hooks ejecutándose en esta sesión |
| `CVE 0/3` | CVEs de seguridad pendientes de resolver |
| `💾` | Uso de memoria del proceso |
| `🧠` | Porcentaje de contexto de Claude utilizado |
| `ADRs` | Architecture Decision Records registrados |
| `AgentDB Vectors` | Vectores HNSW indexados en memoria semántica |

Lo genera `statusline.cjs` en `.claude/helpers/`. Lee métricas de `.claude-flow/data/` y `.claude-flow/metrics/`.

---

## Capas de memoria (RuFlo V3)

Definidas en `helix-engine/.claude-flow/config.yaml`:

```
┌─────────────────────────────────────────────────────┐
│  Capa 1: Working Memory (cache en RAM, 100 entradas) │
│     ↓ desborda a                                     │
│  Capa 2: HNSW Vector Store (búsqueda semántica)      │
│     persistida en .claude-flow/data/                 │
│     150x-12500x más rápida que búsqueda lineal       │
│     ↓ conectada a                                    │
│  Capa 3: Memory Graph (PageRank, máx 5000 nodos)     │
│     similarityThreshold: 0.8                         │
│     pageRankDamping: 0.85                            │
│     ↓ aprende con                                    │
│  Capa 4: LearningBridge (SONA + ReasoningBank)       │
│     confidenceDecayRate: 0.005                       │
│     accessBoostAmount: 0.03                          │
│     consolidationThreshold: 10 accesos               │
└─────────────────────────────────────────────────────┘
```

**AgentScopes:** cada agente tiene su propia vista de memoria (project/local/user). No se mezclan contextos entre agentes.

---

## Capas de orquestación de Helix

Definidas en `claude/CLAUDE.md`:

| Capa | Cuándo | Qué activa |
|------|--------|------------|
| **0 — Ollama** | Logs, texto largo, salida Docker | Modelo local gratuito. Si detecta problema → escala |
| **1 — Subagents** | Un artefacto concreto (endpoint, componente, query) | Agent tool con agente especializado |
| **2 — Swarm** | Feature que toca ≥2 capas del stack | claude-flow `swarm_init` + `task_orchestrate` |
| **3 — Agent Teams** | Colaboración activa frontend+backend+tests | Agent Teams (CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS) |

**Ollama:** es una **regla de comportamiento** en `CLAUDE.md`, no un hook automático. Cuando Helix recibe logs o texto largo, ejecuta `ollama run helix-scout "..."` vía Bash tool antes de procesarlo él mismo. La invocación es consciente (Helix decide), no automática.

---

## Modelos Ollama (Capa 0)

Los Modelfiles están en `ollama/`. Recrear en máquina nueva:

```bash
# Instalar ollama (si no está): https://ollama.com/download

# 1. Descargar modelos base
ollama pull qwen2.5-coder:7b   # ~4.7 GB
ollama pull llama3.2:3b        # ~2.0 GB

# 2. Crear modelos Helix con system prompt personalizado
ollama create helix-coder -f ~/helix_asisten/ollama/helix-coder.Modelfile
ollama create helix-scout -f ~/helix_asisten/ollama/helix-scout.Modelfile
```

| Modelo | Base | Tamaño | Temp | Uso |
|--------|------|--------|------|-----|
| `helix-coder` | Qwen2.5-Coder 7B | 4.7 GB | 0.15 | Bugs, refactors, código FastAPI+React |
| `helix-scout` | Llama 3.2 3B | 2.0 GB | 0.1 | Logs, transformaciones rápidas Python↔TS, CRUDs |

**Cómo Helix los invoca (Capa 0):**
```bash
# Helper unificado (recomendado)
bash ~/helix_asisten/scripts/capa0.sh logs      "$(cat app.log)"
bash ~/helix_asisten/scripts/capa0.sh code      "Debug este error de SQLAlchemy: ..."
bash ~/helix_asisten/scripts/capa0.sh transform "class User(BaseModel): ..."

# Invocación directa
ollama run helix-scout "Analiza este log: $(cat app.log)"
ollama run helix-coder "Debug este error: ..."
```

Si `ollama` no está instalado, `capa0.sh` retorna exit code 2 → Helix escala automáticamente a Capa 1.

---

## Ecosistema RuFlo

> Fuente: https://github.com/ruvnet/ruflo  |  https://github.com/ruvnet/claude-flow

Helix se integra con **3 paquetes npm** del ecosistema RuFlo:

**Versión activa: `ruflo v3.5.41`**

| Paquete | Uso en Helix |
|---------|-------------|
| `ruflo` | **Paquete principal** — instala todo el ecosistema. Versión activa: 3.5.41 |
| `@claude-flow/cli` | **MCP server** — el que está en `.mcp.json`. Expone todas las herramientas `mcp__claude-flow__*` |
| `claude-flow@alpha` | **CLI + transitive deps** — instala `@claude-flow/memory` que usa `auto-memory-hook.mjs` |
| `agentic-flow@alpha` | **ONNX embeddings** — usado por `learning-service.mjs` para embeddings semánticos reales |

```
ruflo v3.5.41  ──incluye──►  @claude-flow/cli  +  @claude-flow/memory  +  agentic-flow

.mcp.json             ──uses──►  @claude-flow/cli@latest  (MCP server)
auto-memory-hook.mjs  ──uses──►  @claude-flow/memory      (memoria persistente)
learning-service.mjs  ──uses──►  agentic-flow@alpha       (ONNX OptimizedEmbedder)
statusline.mjs        ──calls──►  npx agentic-flow@alpha mcp status
```

## MCPs requeridos

| MCP | Propósito |
|-----|-----------|
| `claude-flow` | Orquestación de swarms (Capa 2) — via `@claude-flow/cli` |
| `context7` | Documentación actualizada de librerías |
| `browser-tools` | Auditorías de browser |
| `puppeteer` | Verificación visual de UI |

```bash
# MCP principal (usa @claude-flow/cli — NO claude-flow@alpha, son distintos)
claude mcp add claude-flow -- npx -y @claude-flow/cli@latest mcp start

# Otros MCPs
claude mcp add context7 -- npx -y @upstash/context7-mcp
claude mcp add browser-tools -- npx @agentdeskai/browser-tools-mcp@1.2.0
claude mcp add puppeteer -- npx -y @modelcontextprotocol/server-puppeteer

# Calentar caché de agentic-flow (para ONNX embeddings en learning-service)
npx agentic-flow@alpha --version
```

---

## Modos de Helix

| Modo | Descripción |
|------|-------------|
| `helix_control_total` | 4 capas: Ollama + Subagents + Swarm + Teams |
| `helix_minimal` | Solo subagents especializados |
| `helix_off` | Claude responde directo |

Declarar en el `CLAUDE.md` de cada proyecto: `HELIX_MODE: helix_control_total`

---

## Protocolo de Diálogo (v3 — 2026-03-20)

Helix sigue estas reglas de comunicación en toda solicitud:

| Regla | Comportamiento |
|-------|----------------|
| **Preguntas antes de actuar** | Si la solicitud es ambigua → máx. 2-4 preguntas agrupadas antes de tocar código. Si es concreta → proceder directo. |
| **Plan visible** | Cuando la tarea toca ≥2 archivos → mostrar plan A→B→C y esperar OK antes de empezar. |
| **Umbral de confianza** | Declarar `autonomía alta` (ejecuta sin preguntar) o `autonomía baja` (confirma cada paso) al inicio de la tarea. |
| **Alerta zona 🔴** | Antes de tocar archivos marcados de alto riesgo → declarar qué línea/función se va a cambiar y esperar confirmación. |
| **Exploración → Implementación** | Features nuevas → proponer ≤3 opciones, esperar elección, implementar. Bugs/tasks concretas → implementar directo. |
| **Decisiones proactivas** | Decisiones de diseño no triviales → registrarlas en `DECISIONES DE DISEÑO` del CLAUDE.md del proyecto sin que el usuario lo pida. |
| **Análisis inicial** | Si `[HELIX-SUGGEST-ANALYSIS]` en session-start → sugerir `/helix-analiza` al final del primer mensaje. Solo una vez. |
| **Bitácora silenciosa** | Si `helix-bitacora.md` existe → registrar cambios/recomendaciones/errores sin pedir permiso. |
| **"Tenemos que hablar"** | Si `[HELIX-NECESITAMOS-HABLAR]` en session-start → reportar problemas de salud ANTES de cualquier tarea. |

---

## Sistema de Auto-Mantenimiento (v3 — 2026-03-20)

Helix monitorea su propia salud y gestiona su contexto automáticamente.

### Análisis de proyecto (`/helix-analiza`)

Al llegar a un proyecto nuevo, Helix ofrece hacer un diagnóstico inicial:
- Detecta stack (FastAPI, React, PostgreSQL, Docker...) con `helix-detect-stack.sh`
- Mapea agentes y skills relevantes
- Identifica zonas de riesgo
- Guarda en **memoria híbrida**: resumen ≤150 palabras en `helix-analysis.md`, detalles en vector memory (si claude-flow MCP disponible) o `helix-analysis-full.md` (fallback)
- Inicializa `helix-bitacora.md` con 4 tablas: Cambios / Recomendaciones / Errores / Decisiones

```bash
# Activar manualmente
/helix-analiza

# Helix lo sugiere automáticamente al detectar [HELIX-SUGGEST-ANALYSIS]
# en session-start cuando el proyecto no tiene helix-analysis.md
```

### Bitácora automática (`helix-bitacora.md`)

Hook real en `settings.json` (PostToolUse para Write/Edit/MultiEdit):

```
helix-bitacora-hook.sh  →  agrega fila en tabla "📝 Cambios Realizados"
```

Helix también actualiza la bitácora al dar recomendaciones y al cometer errores (regla en CLAUDE.md).

### Salud de Helix (`/helix-salud`)

Evalúa 3 dimensiones en tiempo real:

| Dimensión | Qué mide | Umbral |
|-----------|----------|--------|
| **Contexto** | Líneas de CLAUDE.md + edad del análisis | <60pts = alerta |
| **Calidad** | Errores en bitácora + recomendaciones pendientes | <60pts = alerta |
| **Overhead** | Agentes activos + skills + sesiones sin aprendizajes | <60pts = alerta |

```bash
/helix-salud    # reporte interactivo on-demand
```

### Sistema "Tenemos que hablar"

Pipeline automático de detección de problemas:

```
session-end.sh
  └─► helix-metricas.sh  (evalúa 3 dimensiones)
      └─► si alerta=true  → escribe helix-alerta.md
          si alerta=false → borra helix-alerta.md (si existía)

session-start.sh
  └─► detecta helix-alerta.md
      └─► emite [HELIX-NECESITAMOS-HABLAR]
          Helix lee la alerta y la reporta ANTES de cualquier tarea
```

### Mantenimiento de CLAUDE.md

Ningún comando deja CLAUDE.md "por arreglar después":

| Comando | Qué hace con CLAUDE.md |
|---------|------------------------|
| `/helix-actualiza` | Paso A (obligatorio primero): comprime si >180 líneas, archiva evoluciones antiguas |
| `/economia` | Paso 1 (obligatorio primero): comprime si >180 líneas antes de activar restricciones |
| `self-check.sh` | Falla HARD si >220 líneas — bloquea cierre de tarea |

### Control de costos (`/economia`)

```bash
/economia       # activar (comprime CLAUDE.md + activa restricciones)
/economia off   # desactivar
/economia?      # estado actual
```

Restricciones del modo economía:
- Sin subagentes salvo ≥3 dominios simultáneos
- Sin Capa 2 (swarm deshabilitado)
- Respuestas en bullets, sin prosa explicativa
- Grep antes que Read siempre
- Sin sugerencias proactivas fuera del scope

Persiste entre sesiones via `.helix-economia` en `.claude/memory/` del proyecto.

---

## 3-Tier Model Routing (CLAUDE.md de RuFlo)

Ruflo enruta automáticamente cada operación al tier más barato:

| Tier | Handler | Latencia | Cuándo |
|------|---------|----------|--------|
| **1** | Agent Booster (WASM) | <1ms | Transforms simples: var→const, add-types, async-await, add-logging |
| **2** | Claude Haiku | ~500ms | Complejidad baja (<30%) |
| **3** | Claude Sonnet/Opus | 2-5s | Razonamiento complejo (>30%) |

Ahorro combinado de tokens: **30-50%** (ReasoningBank -32%, caché 95% hit rate -10%, batch -20%).

## 12 Background Workers (Daemon)

Configurados en `helix-engine/.claude/settings.json` bajo `claudeFlow.daemon.workers`:

| Worker | Intervalo | Qué hace |
|--------|-----------|----------|
| `audit` | 1h (critical) | CVE scan + threat model automático |
| `optimize` | 30m (high) | Performance optimization |
| `consolidate` | 2h (low) | Consolida patrones de memoria HNSW |
| `document` | 1h — triggers: adr-update, api-change | Genera/actualiza documentación |
| `deepdive` | 4h — trigger: complex-change | Análisis profundo de cambios |
| `ultralearn` | 1h | SONA self-learning, EWC++ |
| `map` | — | Knowledge graph mapping |
| `refactor` | — | Refactor suggestions |
| `benchmark` | — | Performance benchmarks |
| `testgaps` | — | Detecta cobertura de tests faltante |

Activar: `ruflo daemon start`

## Hooks del sistema (9 tipos en settings.json)

| Hook | Cuándo se dispara |
|------|-------------------|
| `PreToolUse (Bash)` | Antes de cada comando bash |
| `PreToolUse (Write/Edit)` | Antes de editar archivos |
| `PostToolUse (Write/Edit)` | Después de editar archivos |
| `PostToolUse (Bash)` | Después de cada comando bash |
| `UserPromptSubmit` | Routing de cada prompt (router.cjs) |
| `SessionStart` | Restaura sesión + importa memoria |
| `SessionEnd` | Guarda estado + sincroniza memoria |
| `Stop` | Sync de memoria al parar |
| `PreCompact (manual/auto)` | Antes de compactar contexto |
| `SubagentStart/Stop` | Monitoreo de subagentes |
| `Notification` | Notificaciones del sistema |

## Verificar instalación en nueva máquina

```bash
# 1. Verificar RuFlo (35 categorías, 95+ checks)
sh ~/helix_asisten/scripts/verify-appliance.sh --quick
sh ~/helix_asisten/scripts/verify-appliance.sh            # completo
sh ~/helix_asisten/scripts/verify-appliance.sh --json     # output JSON

# 2. Verificar Helix engine inyectado en un proyecto
bash ~/helix_asisten/scripts/verify-helix-engine.sh ~/mi-proyecto
# (sin argumento usa el directorio actual)
```

## CLI de ruflo (comandos frecuentes)

```bash
ruflo --version                           # verificar versión
ruflo doctor --fix                        # diagnóstico y auto-reparación
ruflo init --wizard                       # inicializar proyecto con wizard
ruflo daemon start                        # activar 10 background workers
ruflo memory search -q "patrón"          # buscar en memoria HNSW
ruflo security scan --depth full         # CVE scan completo
ruflo swarm init --topology hierarchical # iniciar swarm
ruflo hooks list                          # ver hooks activos
ruflo neural status                       # estado SONA
```

## Inyectar Helix en un nuevo proyecto

```bash
# Desde la raíz del proyecto nuevo:
bash ~/helix_asisten/inject-project.sh
# O pasar la ruta explícita:
bash ~/helix_asisten/inject-project.sh ~/mis-proyectos/nuevo-proyecto
```

## Actualizar el repo desde la máquina actual

```bash
cd ~/helix_asisten
bash update.sh        # sync + sanitize automático de contexto privado
git add -A && git commit -m "sync: $(date +%Y-%m-%d)"
git push
```

### Configurar la fuente de helix-engine (solo si tenés un proyecto con helix-engine inyectado)

`update.sh` usa la variable `HELIX_ENGINE_SRC` para saber desde qué proyecto copiar `helix-engine/`. No va hardcodeada en el repo — configurarla localmente:

```bash
# Agregar a ~/.claude/session-env/helix-engine-src.sh (gitignoreado)
export HELIX_ENGINE_SRC="$HOME/ruta/a/tu/proyecto"
```

Si la variable no está definida o el directorio no existe, el paso de helix-engine se salta silenciosamente.

---

## Sistema de privacidad (v3.5.0)

`helix_asisten` es un repo público. Los archivos `memory/agents/*.md` pueden tener contexto de proyectos privados en local (`~/.claude/`) — este sistema garantiza que nunca lleguen al repo.

### Convención de markers

Para que el contexto de un proyecto coexista en tu `~/.claude/` local sin filtrarse:

```markdown
<!-- PROJECT-CONTEXT:START -->
## Contexto del proyecto actual
...datos específicos: tablas, rutas, costos, nombres...
<!-- PROJECT-CONTEXT:END -->
```

`update.sh` strip automáticamente estos bloques al sincronizar.

### Sanitize automático

```bash
# Corre automáticamente en update.sh — también disponible manual:
bash scripts/sanitize-memory-agents.sh claude/memory/agents/
```

Dos mecanismos:
1. **Markers explícitos** — strip preciso del bloque marcado
2. **Fallback** — elimina `## Contexto del proyecto` y su contenido si no hay markers (avisa en consola)

### Pre-commit hook

Bloquea commits que contengan en `claude/memory/agents/`, `topics/` o `skills/`:
- `## Contexto del proyecto actual` sin markers
- Nombres de clientes o proyectos privados
- Rutas absolutas a proyectos locales

```
🔴 PRIVACY GUARD — patrón detectado: '## Contexto del proyecto actual'
   Opciones: 1) agregar markers  2) correr sanitize  3) remover manualmente
```

El hook se instala automáticamente con `install.sh`.

---

## Versiones

### v3.5.0 — 2026-03-24 · Sistema de privacidad

Previene que contexto de proyectos privados filtre al repo público.

**Nuevo — `scripts/sanitize-memory-agents.sh`:**
- Strip de bloques `<!-- PROJECT-CONTEXT:START/END -->` (mecanismo explícito)
- Fallback: elimina secciones `## Contexto del proyecto` sin markers
- Se ejecuta automáticamente en `update.sh` tras cada sync

**Nuevo — Pre-commit hook (`.git/hooks/pre-commit`):**
- Escanea staged files en `claude/memory/agents/`, `topics/` y `skills/`
- Bloquea si detecta patrones privados: nombre de cliente, rutas de proyecto, sección sin markers
- Mensaje de error con 3 opciones de resolución

**Actualizado — `update.sh`:**
- Integra paso de sanitize automático post-copia
- Ruta de helix-engine ahora usa variable `$HELIX_ENGINE_SRC` en lugar de ruta hardcodeada

**Actualizado — `CLAUDE.md` global:**
- Nueva sección `PRIVACIDAD DEL REPO GLOBAL` con la convención de markers documentada

**Fix — limpieza retroactiva:**
- Eliminado contexto de dos proyectos privados que habían filtrado en v3.4.0
- Skills `fastapi-async`, `celery-redis`, `react-query-patterns` generalizados a v2.0
- `memory/agents/fin-saas-advisor.md` eliminado (era 100% específico de un proyecto)
- `brand-identity-expert` y `app-creative-genius` ahora piden contexto al usuario en lugar de asumirlo

---

### v3.4.0 — 2026-03-24 · Agentes creativos + protocolo diálogo + hooks globales

Sincronización completa de `~/.claude/` con el repo. Agentes, protocolo de comunicación y hooks de sesión disponibles para cualquier instalación nueva.

**Nuevo — Agentes especializados:**
| Agente | Dominio | Cuándo usarlo |
|--------|---------|---------------|
| `brand-identity-expert` | Marca, identidad visual, Google Ads, Meta Ads | Naming, taglines, estrategia de marketing digital |
| `app-creative-genius` | Ideas de producto, features, diferenciación | Propuestas de mejora, modelo de negocio, UX disruptivo |

**Nuevo — Infraestructura global (`claude/`):**
- `helpers/statusline.cjs` — barra de estado dinámica para Claude Code (contexto % + rama git)
- `settings.json` actualizado — hooks PreToolUse: `cost-tracker.sh` + `scope-guard.sh` + `suggest-compact.sh`; PostToolUse: `helix-bitacora-hook.sh`
- `memory/topics/interfaz.md` — topic de reglas de comunicación activas (protocolo diálogo)
- `memory/active-rules.md` — 31 reglas seeded del evolution-log, disponibles en instalación nueva

**Actualizado — CLAUDE.md global:**
- Evoluciones #9–15 integradas: protocolo diálogo, análisis inicial automático, bitácora silenciosa, modo economía, pipeline de salud, memoria híbrida
- Catálogo de agentes ampliado con los 3 nuevos dominios (marca, creatividad de producto, finanzas SaaS)

---

### v3.3.0 — 2026-03-24 · Auto-evolución activa

5 sistemas nuevos que hacen que Helix aprenda, mida y se cuide a sí mismo.

**Nuevo — Helpers:**
| Helper | Qué hace |
|--------|----------|
| `scope-guard.sh` | PreToolUse: avisa cuando se edita un archivo fuera del proyecto activo. No bloquea, crea fricción. |
| `cost-tracker.sh` | PreToolUse: cuenta tool calls por sesión. session-end calcula costo estimado en USD. |
| `routing-learn.sh` | CLI: registra decisiones de routing con outcome. session-start muestra los agentes más efectivos por contexto. |

**Modificado — Scripts core:**
| Script | Qué mejoró |
|--------|-----------|
| `evolve.sh` | `learn` ahora también instala la regla en `active-rules.md` (efecto inmediato, no solo archivo) |
| `session-start.sh` | Muestra últimas 5 reglas activas + contexto rápido del proyecto + top agentes del routing feedback |
| `session-end.sh` | Reporta costo estimado de la sesión (tool calls × ~$0.014) |

**Nuevo — Hooks en settings.json:**
```json
PreToolUse Write|Edit|MultiEdit|Bash|Read|Grep|Glob|Agent → cost-tracker.sh
PreToolUse Write|Edit|MultiEdit                            → scope-guard.sh  (ya estaba: suggest-compact.sh)
```

**Nuevo — Memoria:**
- `~/.claude/memory/active-rules.md` — reglas activas derivadas del evolution-log (31 reglas seeded al instalar)
- `~/.claude/memory/routing-feedback.jsonl` — historial de decisiones de routing con outcome

**Uso del routing feedback:**
```bash
bash ~/.claude/helpers/routing-learn.sh "bug en endpoint FastAPI" "error-detective" "success"
bash ~/.claude/helpers/routing-learn.sh "nueva migración DB" "database-architect" "partial"
```
Después de ≥5 registros, session-start muestra los agentes más efectivos por proyecto.

---

### v3.2.0 — 2026-03-24 · Integración hackathon winner

Incorporación selectiva de componentes de `affaan-m/everything-claude-code` (ganador hackathon Anthropic 2025).

**Nuevo — Agentes:**
| Agente | Descripción |
|--------|-------------|
| `harness-optimizer` | Audita y auto-optimiza la configuración de Helix (hooks, routing, tokens, seguridad). No toca código del producto. |
| `loop-operator` | Opera loops autónomos con escalación segura: detecta stalls, retries infinitos y exceso de presupuesto. |

**Nuevo — Skills:**
| Skill | Comando | Descripción |
|-------|---------|-------------|
| `context-budget` | `/context-budget` | Audita tokens consumidos por agentes, skills, reglas y MCP servers. Identifica bloat y sugiere cortes. |
| `strategic-compact` | Hook automático | Cuenta tool calls por sesión y sugiere `/compact` al alcanzar 50 llamadas (luego cada 25). Evita compactaciones a mitad de tarea. |

**Nuevo — Hook PreToolUse:**
- `suggest-compact.sh` registrado en `settings.json` → se ejecuta en cada Write/Edit/Bash

---

### v3.1.0 — 2026-03-20 · Sistema auto-mantenimiento

- `/helix-analiza` — análisis inicial de proyecto con memoria híbrida
- `/helix-salud` — evaluación de salud + pipeline "Tenemos que hablar"
- `/helix-actualiza` — mantenimiento y actualización de análisis
- `/economia` — modo economía (sin subagentes, Grep-first, respuestas ultra-concisas)
- Bitácora de proyecto: mantenimiento silencioso automático
- Checklist pre-Read siempre activo
- Umbrales de subagentes: 1 dominio → yo solo, 2 → 1 subagente, 3+ → Capa 2

---

### v3.0.0 — 2026-03-08 · RuFlo V3 + helix-engine

- Motor RuFlo V3 inyectable (`helix-engine/`)
- HNSW Vector Store (150x-12500x speedup vs búsqueda lineal)
- SONA Learning + ReasoningBank
- 26 categorías de agentes: sparc, swarm, v3, github, optimization, hive-mind, consensus...
- Statusline dinámica (swarm + tokens + CVEs + AgentDB)
- AgentDB con quantization y semantic vector search
- 4 capas de orquestación: Ollama → Subagents → Swarm → Agent Teams
