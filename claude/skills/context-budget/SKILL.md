---
name: context-budget
description: Audita el consumo de tokens de los componentes de Helix — agentes, skills, reglas y MCP servers. Identifica bloat y recomienda cortes con estimación de ahorro. Usar cuando Helix se siente lento o antes de agregar componentes nuevos.
triggers:
  - "/context-budget"
  - "cuántos tokens pesa helix"
  - "helix está lento"
  - "auditar contexto"
  - "optimizar tokens"
---

# Context Budget — Auditoría de tokens de Helix

Herramienta de diagnóstico que analiza qué componentes del harness consumen más tokens y dónde se puede reducir overhead sin perder capacidad.

## Uso

```bash
/context-budget           # reporte básico
/context-budget --verbose # desglose por archivo
```

## Fases de análisis

### 1. Inventario
Escanear y estimar tokens de cada componente:
- `~/.claude/CLAUDE.md` — instrucciones globales
- `~/.claude/agents/*.md` — descripciones de agentes (se cargan en CADA invocación)
- `~/.claude/skills/*/SKILL.md` — skills disponibles
- MCP servers en `.mcp.json` — cada tool schema ~500 tokens

Estimación: `palabras × 1.3 = tokens aproximados`

### 2. Clasificar por necesidad
| Categoría | Criterio |
|-----------|----------|
| Siempre necesario | Se usa en > 50% de las sesiones |
| A veces necesario | Trigger específico, cargar bajo demanda |
| Raramente necesario | < 1 vez por semana → mover a `disabled/` |

### 3. Detectar problemas comunes
- **Agentes con descripción > 500 tokens** — se cargan en cada tarea aunque no se usen
- **MCP over-subscription** — un servidor con 30 tools = ~15K tokens de overhead
- **Skills sin trigger definido** — se cargan siempre en lugar de bajo demanda
- **CLAUDE.md > 6K tokens** — revisar si hay documentación estática que debe ir a `memory/`
- **Instrucciones duplicadas** — misma regla en CLAUDE.md global y en CLAUDE.md del proyecto

### 4. Reporte de salida
```
CONTEXT BUDGET REPORT — [fecha]
────────────────────────────────
CLAUDE.md global:     ~2,400 tok  ✅
Agentes activos (18): ~4,200 tok  ⚠️ (3 agentes > 300 tok c/u)
Skills cargadas:      ~1,800 tok  ✅
MCP servers:          ~8,500 tok  🔴 (claude-flow: 17 tools activos)
────────────────────────────────
TOTAL estimado:      ~16,900 tok
Potencial de ahorro: ~4,200 tok  (desactivar 3 MCP tools + 2 agentes)

Top 3 acciones recomendadas:
1. Mover `flutter-reviewer` a disabled/ → -180 tok (nunca usado)
2. Reducir claude-flow a tools esenciales → -2,800 tok
3. Comprimir descripción de `senior-fullstack` → -320 tok
```

## Principio clave

> Los MCP servers son la mayor palanca: cada tool schema cuesta ~500 tokens.
> Un servidor con 30 tools consume más tokens que todos tus skills juntos.
> Priorizar siempre la reducción de MCP tools sobre la reducción de agentes.
