---
name: strategic-compact
description: Sugiere /compact en momentos estratégicos (no arbitrarios) basado en conteo de tool calls. Evita compactaciones a mitad de tarea. Hook PreToolUse que dispara al alcanzar 50 tool calls y cada 25 después.
triggers:
  - "/strategic-compact"
  - "configurar compactación estratégica"
  - "compact automático"
---

# Strategic Compact — Compactación estratégica de contexto

Evita que el contexto se compacte en medio de una implementación importante.
En lugar de compactar por tamaño, compacta en **momentos lógicos**: cuando terminaste de explorar, cuando cerraste un hito, cuando vas a cambiar de tema.

## Instalación del hook

Agregar a `~/.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit|MultiEdit|Bash",
        "hooks": [
          {
            "type": "command",
            "command": "bash \"$HOME/.claude/skills/strategic-compact/suggest-compact.sh\""
          }
        ]
      }
    ]
  }
}
```

## Configuración

| Variable | Default | Descripción |
|----------|---------|-------------|
| `COMPACT_THRESHOLD` | `50` | Tool calls antes del primer aviso |
| `COMPACT_INTERVAL` | `25` | Tool calls entre avisos posteriores |

```bash
# En ~/.claude/session-env o .env del proyecto
export COMPACT_THRESHOLD=50
export COMPACT_INTERVAL=25
```

## Cuándo compactar (momentos estratégicos)

**Compactar DESPUÉS de:**
- Completar la fase de exploración/research
- Finalizar un plan y antes de implementar
- Cerrar un hito importante
- Cambiar de tarea no relacionada

**NO compactar:**
- A mitad de una implementación multi-archivo
- Cuando hay TodoWrite con tareas en progreso
- Durante un loop autónomo activo

## Qué sobrevive vs qué se pierde en /compact

| Persiste | Se pierde |
|----------|-----------|
| CLAUDE.md e instrucciones | Análisis y razonamiento intermedio |
| TodoWrite (tareas) | Contenido de archivos previamente leídos |
| Archivos en disco | Historial de tool calls |
| Estado de git | Conversación y contexto acumulado |
| Memoria en `~/.claude/memory/` | Resultados de búsquedas |

**Práctica:** antes de compactar, escribir contexto crítico en un archivo (`notas-sesion.md`, `progress.md`, etc.)
