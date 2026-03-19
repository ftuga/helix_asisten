# Helix — Configuración del Agente Auto-Evolutivo

Backup completo de Helix para Claude Code. Clona y ejecuta `install.sh` en cualquier máquina nueva.

## Instalación rápida

```bash
git clone git@github.com:ftuga/helix_asisten.git ~/helix_asisten
bash ~/helix_asisten/install.sh
```

Luego instalar los MCPs (el script te los muestra).

## Estructura

```
claude/              → ~/.claude/ (config global)
  CLAUDE.md          → Instrucciones globales de Helix + protocolo de capas
  settings.json      → Agent Teams habilitado
  *.sh / *.py        → Scripts de auto-evolución (evolve, session-start/end, self-check)
  agents/            → 18 agentes activos + 17 deshabilitados
  commands/          → claude-flow-help/memory/swarm
  memory/            → design-system, agents-index, evolution-log, topics
  skills/            → 28 skills reutilizables

template/            → ~/.claude-template/ (base para nuevos proyectos)
  CLAUDE.md          → Template CLAUDE.md de proyecto
  init-project.sh    → Script de inicialización
  .claude/           → Memoria y skills del template

helix-engine/        → Motor Helix inyectable en cualquier proyecto
  .mcp.json          → MCP claude-flow con v3 + HNSW + SONA activados
  .claude/
    agents/          → 26 categorías: sparc, swarm, v3, github, optimization...
    commands/        → analysis, automation, github, hooks, monitoring, sparc...
    helpers/         → hook-handler.cjs, auto-memory-hook.mjs, router.cjs,
                       session.cjs, intelligence.cjs, memory.cjs, statusline.cjs...
    skills/          → 31 skills: v3-*, swarm-*, agentdb-*, reasoningbank-*, sparc-*
    settings.json    → Hooks: PreToolUse, PostToolUse, UserPromptSubmit, SessionStart/End
    statusline.mjs   → Status line dinámica
  .claude-flow/
    config.yaml      → RuFlo V3: hierarchical-mesh, HNSW, SONA, ReasoningBank
    CAPABILITIES.md  → Referencia completa de capacidades
    security/        → Audit config
```

## MCPs requeridos

| MCP | Propósito |
|-----|-----------|
| `context7` | Documentación actualizada de librerías |
| `claude-flow` | Orquestación de swarms (Capa 2) |
| `browser-tools` | Auditorías de browser |
| `puppeteer` | Verificación visual de UI |

## Modos de Helix

| Modo | Descripción |
|------|-------------|
| `helix_control_total` | 4 capas: Ollama + Subagents + Swarm + Teams |
| `helix_minimal` | Solo subagents especializados |
| `helix_off` | Claude responde directo |

Declarar en el `CLAUDE.md` de cada proyecto: `HELIX_MODE: helix_control_total`

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

## Nota sobre Ollama (Capa 0)

Ollama no es una config técnica — es un protocolo de comportamiento en `claude/CLAUDE.md`.
Helix evalúa si usar Ollama primero (logs/texto largo) basado en la señal de la tarea, no por config cableada.
El modelo local se instala con: `ollama pull <modelo>` en la nueva máquina.
