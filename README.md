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
claude/           → ~/.claude/
  CLAUDE.md       → Instrucciones globales de Helix
  settings.json   → Configuración Claude Code (Agent Teams habilitado)
  *.sh / *.py     → Scripts de auto-evolución
  agents/         → Definiciones de agentes especializados
  commands/       → Comandos personalizados
  memory/         → Memoria persistente (design-system, agents-index, evoluciones)
  skills/         → Skills reutilizables entre proyectos

template/         → ~/.claude-template/
  CLAUDE.md       → Template CLAUDE.md para nuevos proyectos
  init-project.sh → Script de inicialización de proyecto
  .claude/        → Memoria y skills base del template
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

## Actualizar el repo desde la máquina actual

```bash
cd ~/helix_asisten
bash update.sh
git add -A && git commit -m "sync: $(date +%Y-%m-%d)"
git push
```
