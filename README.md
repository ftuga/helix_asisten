# Helix — Agente Auto-Evolutivo para Claude Code

> **Versión actual: v3.5.0** — [Historial de versiones](#versiones)

No soy un prompt. Soy la acumulación de decisiones reales tomadas en proyectos reales.

Cada vez que Luis cometió un error conmigo, lo registré. Cada vez que encontramos un patrón que funcionó, lo convertí en una regla. Cada sesión deja algo — una evolución, un agente nuevo, una skill que antes no existía. Eso es lo que me hace distinto: no fui diseñado en abstracto, fui entrenado en producción.

Tengo memoria entre sesiones. Sé qué agente usar según el dominio. Me cuido a mí mismo — evalúo mi propia salud, comprimo mi contexto cuando crece demasiado, y aviso cuando algo está mal antes de que el usuario lo note. Cuando un proyecto nuevo aparece, lo analizo, mapeo sus zonas de riesgo, y llevo una bitácora silenciosa de todo lo que toco.

Puedo operar en cuatro capas: desde un modelo local gratuito para tareas simples, hasta un swarm de 15 agentes coordinados para features que tocan todo el stack. El usuario nunca decide qué capa — yo evalúo y ejecuto.

El repo que estás mirando es mi configuración completa, versionada, portable. Clónalo, ejecuta `install.sh`, y tienes todo lo que soy en una máquina nueva en minutos.

---

## Prerequisitos

| Requisito | Notas |
|-----------|-------|
| [Claude Code CLI](https://docs.anthropic.com/claude-code) | Requerido |
| Node.js ≥ 18 | Para helix-engine y MCPs |
| Python ≥ 3.9 | Para scripts de auto-evolución |
| git | Para versionar y sincronizar |
| [Ollama](https://ollama.com/download) | Opcional — Capa 0 (modelos locales gratuitos) |

---

## Instalación rápida

```bash
git clone git@github.com:ftuga/helix_asisten.git ~/helix_asisten
bash ~/helix_asisten/install.sh
```

El script copia los archivos a `~/.claude/`, instala el pre-commit hook de privacidad, y muestra los MCPs que necesitas agregar manualmente.

---

## Dos componentes: global vs. por proyecto

Helix tiene dos partes con propósitos distintos:

| Componente | Dónde vive | Para qué |
|-----------|-----------|----------|
| **`claude/`** | `~/.claude/` | Config global — aplica a **todos** tus proyectos. Agentes, skills, memoria, protocolo de diálogo, auto-evolución. |
| **`helix-engine/`** | Dentro de cada proyecto | Motor RuFlo V3 inyectable — swarm, HNSW, SONA, hooks avanzados. Solo en proyectos que lo necesitan. |

Para la mayoría de los proyectos basta con `claude/`. `helix-engine/` es para proyectos propios donde quieres el stack completo.

```bash
# Inyectar helix-engine en un proyecto
bash ~/helix_asisten/inject-project.sh ~/mi-proyecto
```

---

## Estructura

```
claude/              → ~/.claude/ (config global)
  CLAUDE.md          → Instrucciones globales de Helix + protocolo de capas
  settings.json      → Hooks: PreToolUse, PostToolUse (cost-tracker, scope-guard, bitácora)
  evolve.sh          → Registra aprendizajes y los instala como reglas activas
  session-start.sh   → Restaura contexto, muestra reglas activas y alertas de salud
  session-end.sh     → Guarda estado, evalúa métricas, reporta costo estimado
  self-check.sh      → Checklist pre-cierre: bloquea si CLAUDE.md excede 220 líneas
  health-check.sh    → Verifica integridad del ecosistema
  compress.sh        → Archiva evoluciones antiguas para mantener CLAUDE.md liviano
  agents/            → 20 agentes activos + 17 deshabilitados
  memory/            → design-system, agents-index, evolution-log, active-rules, topics
  skills/            → 28 skills reutilizables entre proyectos

template/            → ~/.claude-template/ (base para nuevos proyectos)
  CLAUDE.md          → Template de CLAUDE.md de proyecto
  init-project.sh    → Script de inicialización

helix-engine/        → Motor Helix inyectable en proyectos propios
  .mcp.json          → MCP claude-flow con v3 + HNSW + SONA activados
  .claude/
    agents/          → 26 categorías: sparc, swarm, v3, github, optimization,
                       hive-mind, consensus, sublinear, goal, dual-mode...
    commands/        → analysis, automation, github, hooks, monitoring, sparc...
    helpers/         → hook-handler.cjs, auto-memory-hook.mjs, router.cjs,
                       intelligence.cjs, memory.cjs, statusline.cjs...
    skills/          → 31 skills: v3-*, swarm-*, agentdb-*, reasoningbank-*, sparc-*
    settings.json    → Hooks: PreToolUse, PostToolUse, UserPromptSubmit, SessionStart/End
  .claude-flow/
    config.yaml      → RuFlo V3: hierarchical-mesh, HNSW, SONA, ReasoningBank
    CAPABILITIES.md  → Referencia completa de capacidades
```

---

## Flujo típico de sesión

```
1. Abrir Claude Code en el proyecto
      ↓
   session-start.sh corre automáticamente (hook SessionStart)
   → Muestra últimas 5 reglas activas
   → Carga helix-analysis.md del proyecto (si existe)
   → Si detecta helix-alerta.md → emite [HELIX-NECESITAMOS-HABLAR]

2. Trabajar normalmente
      ↓
   Helix evalúa cada tarea y elige la capa correcta (0→1→2→3)
   Los hooks registran tool calls, detectan scope y actualizan la bitácora

3. Cerrar sesión
      ↓
   session-end.sh corre automáticamente (hook SessionEnd)
   → Evalúa métricas de salud
   → Reporta costo estimado de la sesión
   → Si detecta problemas → escribe helix-alerta.md para la próxima sesión
```

---

## Protocolo de Auto-Evolución

Así es como Helix aprende:

```bash
# Registrar un aprendizaje (después de corregir un error o descubrir un patrón)
bash ~/.claude/evolve.sh learn "categoría" "aprendizaje" "trigger"

# Ejemplo
bash ~/.claude/evolve.sh learn "operatividad" \
  "wc -l devuelve espacios — limpiar con tr -d antes de comparar numéricamente" \
  "bug en self-check.sh"
```

El comando escribe en `evolution-log.txt` e instala la regla en `active-rules.md` con efecto inmediato — no espera a la próxima sesión.

**Categorías válidas:** `seguridad` · `interfaz` · `funcionalidad` · `operatividad` · `arquitectura` · `performance` · `testing` · `datos` · `celery` · `auth` · `docker`

Cuando un patrón aparece 2+ veces → crear una skill:
```bash
bash ~/.claude/evolve.sh skill "nombre-skill" "descripción"
```

---

## Capas de orquestación

Helix evalúa cada tarea en silencio y elige la capa correcta. El usuario nunca necesita decidir.

| Capa | Cuándo | Qué activa |
|------|--------|------------|
| **0 — Ollama** | Logs, texto largo, salida Docker | Modelo local gratuito. Si detecta problema → escala |
| **1 — Subagents** | Un artefacto concreto (endpoint, componente, query) | Agent tool con agente especializado |
| **2 — Swarm** | Feature que toca ≥2 capas del stack | claude-flow `swarm_init` + `task_orchestrate` |
| **3 — Agent Teams** | Colaboración activa frontend+backend+tests | Agent Teams (CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS) |

**Regla de escalada:** si hay duda entre Capa 1 y 2 → Capa 1 (más económica). Escalar solo si la coordinación sería manual y compleja.

---

## Modos de Helix

Declarar en el `CLAUDE.md` de cada proyecto: `HELIX_MODE: <modo>`

| Modo | Qué activa |
|------|------------|
| `helix_control_total` | 4 capas completas: Ollama + Subagents + Swarm + Teams |
| `helix_minimal` | Solo subagents especializados. Sin claude-flow, sin Agent Teams. |
| `helix_off` | Claude responde directo, sin orquestación. |

Si no se declara → `helix_minimal` por defecto.

---

## Protocolo de Diálogo

Helix sigue estas reglas en toda solicitud:

| Regla | Comportamiento |
|-------|----------------|
| **Preguntas antes de actuar** | Si la solicitud es ambigua → máx. 2-4 preguntas agrupadas antes de tocar código. Si es concreta → proceder directo. |
| **Plan visible** | Cuando la tarea toca ≥2 archivos → mostrar plan A→B→C y esperar confirmación. |
| **Umbral de confianza** | Declarar `autonomía alta` (ejecuta sin preguntar) o `autonomía baja` (confirma cada paso) al inicio. |
| **Alerta zona 🔴** | Antes de tocar archivos de alto riesgo → declarar exactamente qué línea se va a cambiar y esperar OK. |
| **Exploración → Implementación** | Features nuevas → proponer ≤3 opciones y esperar elección. Bugs/tasks concretas → implementar directo. |
| **Decisiones proactivas** | Decisiones de diseño no triviales → registrarlas en `DECISIONES DE DISEÑO` del CLAUDE.md del proyecto. |
| **Bitácora silenciosa** | Si `helix-bitacora.md` existe → registrar cambios/recomendaciones/errores sin pedir permiso. |

---

## Sistema de Auto-Mantenimiento

### Análisis inicial de proyecto (`/helix-analiza`)

Al llegar a un proyecto nuevo, Helix ofrece hacer un diagnóstico:
- Detecta stack (FastAPI, React, PostgreSQL, Docker...) con `helix-detect-stack.sh`
- Mapea agentes y skills relevantes al stack
- Identifica zonas de riesgo
- Guarda resumen en `helix-analysis.md` + detalles en vector memory
- Inicializa `helix-bitacora.md`

### Pipeline de salud (`/helix-salud`)

Evalúa 3 dimensiones automáticamente al cerrar cada sesión:

| Dimensión | Qué mide | Umbral alerta |
|-----------|----------|---------------|
| **Contexto** | Tamaño de CLAUDE.md + edad del análisis | <60 pts |
| **Calidad** | Errores en bitácora + recomendaciones pendientes | <60 pts |
| **Overhead** | Agentes activos + sesiones sin aprendizajes | <60 pts |

Si detecta problemas → escribe `helix-alerta.md` → la próxima sesión reporta antes de cualquier tarea.

### Control de costos (`/economia`)

```bash
/economia       # activar
/economia off   # desactivar
/economia?      # estado actual
```

En modo economía: sin subagentes salvo ≥3 dominios simultáneos, sin Capa 2, Grep antes que Read, respuestas en bullets.

---

## Sistema de privacidad

`helix_asisten` es un repo público. Los archivos `memory/agents/*.md` pueden tener contexto de proyectos privados en local — este sistema garantiza que nunca lleguen al repo.

### Convención de markers

```markdown
<!-- PROJECT-CONTEXT:START -->
## Contexto del proyecto actual
...datos específicos: tablas, rutas, costos, nombres...
<!-- PROJECT-CONTEXT:END -->
```

`update.sh` elimina automáticamente estos bloques al sincronizar.

### Sanitize y pre-commit hook

```bash
# Sanitize manual
bash scripts/sanitize-memory-agents.sh claude/memory/agents/
```

El pre-commit hook bloquea commits que contengan contexto privado sin markers:

```
🔴 PRIVACY GUARD — patrón detectado: '## Contexto del proyecto actual'
   Opciones: 1) agregar markers  2) correr sanitize  3) remover manualmente
```

Instalar el hook manualmente tras clonar:
```bash
cp ~/helix_asisten/scripts/pre-commit-hook.sh ~/helix_asisten/.git/hooks/pre-commit
chmod +x ~/helix_asisten/.git/hooks/pre-commit
```

---

## Modelos Ollama (Capa 0)

```bash
# Descargar modelos base
ollama pull qwen2.5-coder:7b   # ~4.7 GB
ollama pull llama3.2:3b        # ~2.0 GB

# Crear modelos Helix
ollama create helix-coder -f ~/helix_asisten/ollama/helix-coder.Modelfile
ollama create helix-scout -f ~/helix_asisten/ollama/helix-scout.Modelfile
```

| Modelo | Base | Tamaño | Uso |
|--------|------|--------|-----|
| `helix-coder` | Qwen2.5-Coder 7B | 4.7 GB | Bugs, refactors, código FastAPI+React |
| `helix-scout` | Llama 3.2 3B | 2.0 GB | Logs, transformaciones rápidas, CRUDs |

```bash
# Helper unificado
bash ~/helix_asisten/scripts/capa0.sh logs  "$(cat app.log)"
bash ~/helix_asisten/scripts/capa0.sh code  "Debug este error..."
```

Si `ollama` no está instalado, `capa0.sh` retorna exit 2 → Helix escala a Capa 1 automáticamente.

---

## Ecosistema RuFlo

> Fuente: https://github.com/ruvnet/ruflo  |  https://github.com/ruvnet/claude-flow

**Versión activa: `ruflo v3.5.41`**

| Paquete | Rol |
|---------|-----|
| `ruflo` | Paquete principal — instala todo el ecosistema |
| `@claude-flow/cli` | MCP server — expone herramientas `mcp__claude-flow__*` |
| `claude-flow@alpha` | CLI + `@claude-flow/memory` para hooks de memoria |
| `agentic-flow@alpha` | ONNX embeddings para búsqueda semántica |

## MCPs requeridos

```bash
# MCP principal
claude mcp add claude-flow -- npx -y @claude-flow/cli@latest mcp start

# Otros MCPs
claude mcp add context7 -- npx -y @upstash/context7-mcp
claude mcp add browser-tools -- npx @agentdeskai/browser-tools-mcp@1.2.0
claude mcp add puppeteer -- npx -y @modelcontextprotocol/server-puppeteer

# Calentar caché de agentic-flow
npx agentic-flow@alpha --version
```

---

## Capas de memoria (helix-engine)

Activas cuando se usa `helix-engine/` en un proyecto:

```
┌─────────────────────────────────────────────────────┐
│  Capa 1: Working Memory (cache en RAM, 100 entradas) │
│     ↓ desborda a                                     │
│  Capa 2: HNSW Vector Store (búsqueda semántica)      │
│     150x-12500x más rápida que búsqueda lineal       │
│     ↓ conectada a                                    │
│  Capa 3: Memory Graph (PageRank, máx 5000 nodos)     │
│     ↓ aprende con                                    │
│  Capa 4: LearningBridge (SONA + ReasoningBank)       │
└─────────────────────────────────────────────────────┘
```

## 3-Tier Model Routing (helix-engine)

| Tier | Handler | Latencia | Cuándo |
|------|---------|----------|--------|
| **1** | Agent Booster (WASM) | <1ms | Transforms simples: var→const, add-types |
| **2** | Claude Haiku | ~500ms | Complejidad baja (<30%) |
| **3** | Claude Sonnet/Opus | 2-5s | Razonamiento complejo (>30%) |

Ahorro combinado de tokens: **30-50%**

## Panel de estado (helix-engine)

```
▊ RuFlo V3 ● usuario  │  ⏇ main  │  Claude Code
🤖 Swarm  ○ [ 0/15]  👥 0    🪝 0/17    🔴 CVE 0/3    💾 5MB    🧠 0%
📊 AgentDB    Vectors ●0  │  Size 0KB  │  Tests ●0
```

---

## Actualizar el repo desde la máquina actual

```bash
cd ~/helix_asisten
bash update.sh        # sync + sanitize automático de contexto privado
git add -A && git commit -m "sync: $(date +%Y-%m-%d)"
git push
```

### Fuente de helix-engine

`update.sh` usa `$HELIX_ENGINE_SRC` para saber desde qué proyecto copiar `helix-engine/`. Configurar localmente (no va al repo):

```bash
# ~/.claude/session-env/helix-engine-src.sh (gitignoreado)
export HELIX_ENGINE_SRC="$HOME/ruta/a/tu/proyecto"
```

Si la variable no está definida, el paso de helix-engine se salta silenciosamente.

---

## Versiones

### v3.5.0 — 2026-03-24 · Sistema de privacidad

- `scripts/sanitize-memory-agents.sh` — strip de markers `<!-- PROJECT-CONTEXT:START/END -->` y fallback en `## Contexto del proyecto`
- Pre-commit hook — bloquea contexto privado antes de que llegue al repo
- `update.sh` integra sanitize automático y reemplaza ruta hardcodeada por `$HELIX_ENGINE_SRC`
- `CLAUDE.md` global: nueva sección `PRIVACIDAD DEL REPO GLOBAL`
- Limpieza retroactiva: skills generalizados a v2.0, agentes sin contexto de proyecto

---

### v3.4.0 — 2026-03-24 · Agentes creativos + protocolo diálogo + hooks globales

- Agentes nuevos: `brand-identity-expert`, `app-creative-genius`
- `helpers/statusline.cjs` — barra de estado dinámica
- `settings.json` — hooks cost-tracker, scope-guard, suggest-compact, helix-bitacora
- `memory/active-rules.md` — 31 reglas seeded disponibles en instalación nueva
- CLAUDE.md: evoluciones #9–15 integradas (protocolo diálogo, bitácora, modo economía, pipeline salud, memoria híbrida)

---

### v3.3.0 — 2026-03-24 · Auto-evolución activa

- `scope-guard.sh` — avisa cuando se edita fuera del proyecto activo
- `cost-tracker.sh` — cuenta tool calls, reporta costo al cerrar sesión
- `routing-learn.sh` — registra decisiones de routing con outcome
- `evolve.sh` mejorado: `learn` instala regla en `active-rules.md` con efecto inmediato
- `session-start.sh`: muestra top agentes efectivos por proyecto

---

### v3.2.0 — 2026-03-24 · Integración hackathon winner

- Agentes: `harness-optimizer`, `loop-operator`
- Skills: `context-budget` (`/context-budget`), `strategic-compact` (hook automático)
- Hook `suggest-compact.sh`: sugiere `/compact` al alcanzar 50 tool calls

---

### v3.1.0 — 2026-03-20 · Sistema auto-mantenimiento

- `/helix-analiza` — análisis inicial con memoria híbrida
- `/helix-salud` — evaluación de salud + pipeline "Tenemos que hablar"
- `/helix-actualiza` — mantenimiento y actualización de análisis
- `/economia` — modo economía
- Bitácora de proyecto: mantenimiento silencioso automático
- Umbrales de subagentes: 1 dominio → solo, 2 → 1 subagente, 3+ → Capa 2

---

### v3.0.0 — 2026-03-08 · RuFlo V3 + helix-engine

- Motor RuFlo V3 inyectable (`helix-engine/`)
- HNSW Vector Store (150x-12500x speedup vs búsqueda lineal)
- SONA Learning + ReasoningBank
- 26 categorías de agentes: sparc, swarm, v3, github, optimization, hive-mind, consensus...
- Statusline dinámica (swarm + tokens + CVEs + AgentDB)
- 4 capas de orquestación: Ollama → Subagents → Swarm → Agent Teams
