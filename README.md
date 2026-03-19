# Helix — Configuración del Agente Auto-Evolutivo

Backup completo de Helix para Claude Code. Clona y ejecuta `install.sh` en cualquier máquina nueva.

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
  agents/            → 18 agentes activos + 17 deshabilitados
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

**Ollama:** no es config técnica. Es una regla de comportamiento en `CLAUDE.md`. En máquina nueva: `ollama pull <modelo>`.

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
# Verificación rápida (categorías críticas)
sh ~/helix_asisten/scripts/verify-appliance.sh --quick

# Verificación completa (35 categorías, 95+ checks)
sh ~/helix_asisten/scripts/verify-appliance.sh

# Verificar categoría específica
sh ~/helix_asisten/scripts/verify-appliance.sh --category memory
sh ~/helix_asisten/scripts/verify-appliance.sh --category security

# Output JSON para integración
sh ~/helix_asisten/scripts/verify-appliance.sh --json
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
bash update.sh
git add -A && git commit -m "sync: $(date +%Y-%m-%d)"
git push
```
