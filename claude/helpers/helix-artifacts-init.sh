#!/usr/bin/env bash
# helix-artifacts-init.sh — Crea los artefactos de proyecto que la doctrina
# asume existentes. IDEMPOTENTE: nunca sobreescribe.
#
# Origen (2026-07-26): auditoria de cableado.
#   · `risk-map` se citaba en 2 reglas de CLAUDE.md y NO EXISTIA en ningun
#     proyecto ni tenia productor en el codigo.
#   · helix-bitacora-hook.sh sale por `[[ ! -f "$BITACORA" ]] && exit 0`.
#     El hook corria en cada Write/Edit desde abril, saliendo en silencio,
#     porque nada creaba el archivo. 1 bitacora en 8 proyectos.
#
# Se mantiene el opt-in por existencia (un proyecto cliente no debe recibir
# artefactos sin que alguien lo pida), pero ahora HAY un productor real.
#
# Uso:
#   bash helix-artifacts-init.sh <PROJECT_ROOT> [--force-empty]
#   bash helix-artifacts-init.sh <PROJECT_ROOT> --check   # solo reporta

set -euo pipefail

PROJECT_ROOT="${1:-$PWD}"
MODE="${2:-create}"

[[ -d "$PROJECT_ROOT" ]] || { echo "❌ no existe: $PROJECT_ROOT" >&2; exit 1; }
PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd)"
PROJECT_NAME="$(basename "$PROJECT_ROOT")"
MEM_DIR="$PROJECT_ROOT/.claude/memory"
TODAY="$(date +%Y-%m-%d)"

BITACORA="$MEM_DIR/helix-bitacora.md"
RISKMAP="$MEM_DIR/helix-risk-map.md"

if [[ "$MODE" == "--check" ]]; then
  echo "proyecto: $PROJECT_NAME"
  echo "  helix-bitacora.md : $([[ -f "$BITACORA" ]] && echo presente || echo AUSENTE)"
  echo "  helix-risk-map.md : $([[ -f "$RISKMAP" ]] && echo presente || echo AUSENTE)"
  exit 0
fi

mkdir -p "$MEM_DIR"
CREATED=0

# ── bitacora ───────────────────────────────────────────────────
if [[ -f "$BITACORA" ]]; then
  echo "  = helix-bitacora.md ya existe — sin tocar"
else
  cat > "$BITACORA" <<EOF
# Bitácora — $PROJECT_NAME

> La escribe \`helix-bitacora-hook.sh\` (PostToolUse Write|Edit|MultiEdit) más las
> entradas que agrega Helix tras cambios significativos, recomendaciones no
> triviales y errores cometidos (regla #6 de la doctrina).
>
> **Es narrativa: dice qué pasó, no qué está vigente.** Lo vigente va al
> risk-map y a las decisiones de diseño del CLAUDE.md del proyecto.
>
> Inicializada: $TODAY por \`helix-artifacts-init.sh\`

## 📝 Cambios Realizados
| Fecha | Archivo(s) | Cambio | Sesión |
|-------|-----------|--------|--------|
| $TODAY | (inicialización) | bitácora creada | $TODAY |

## 💡 Recomendaciones
| Fecha | Recomendación | Estado |
|-------|--------------|--------|

## 🐛 Errores Cometidos
| Fecha | Error | Solución | Aprendizaje |
|-------|-------|----------|-------------|

## 🧠 Decisiones de Diseño Validadas
| Fecha | Decisión | Por qué |
|-------|---------|---------|
EOF
  echo "  + helix-bitacora.md creado"
  CREATED=$((CREATED + 1))
fi

# ── risk-map ───────────────────────────────────────────────────
if [[ -f "$RISKMAP" ]]; then
  echo "  = helix-risk-map.md ya existe — sin tocar"
else
  cat > "$RISKMAP" <<EOF
# Risk Map — $PROJECT_NAME

> Zonas del código donde un cambio descuidado rompe algo que no es obvio.
> Lo consume la **regla #3** de la doctrina (declarar línea/función y esperar OK
> antes de tocar una zona ⚠️) y el **checklist pre-cierre** (todo bug encontrado
> se registra acá).
>
> Inicializado: $TODAY por \`helix-artifacts-init.sh\`

## Estado

**VACÍO — sin zonas registradas todavía.**

Un risk-map vacío es información válida: significa "nadie mapeó esto aún",
no "no hay riesgo". Los consumidores (ej. el brief de subagentes) deben
degradar sin fallar cuando esta sección está vacía, y **nunca** interpretar
el vacío como "zona segura".

## Zonas

<!-- Formato — una entrada por zona. Los consumidores parsean estos campos.

### ⚠️ <nombre corto de la zona>
- **Path:** \`ruta/al/archivo.ext\` (o glob)
- **Nivel:** critico | alto | medio
- **Por qué:** qué se rompe y cómo se manifiesta
- **Antes de tocar:** qué verificar / a quién preguntar
- **Registrado:** YYYY-MM-DD · origen (bug, incidente, review)
-->

## Bugs registrados

<!-- Todo bug encontrado entra acá con fecha, síntoma y si ya tiene test que lo reproduzca. -->
EOF
  echo "  + helix-risk-map.md creado"
  CREATED=$((CREATED + 1))
fi

echo "  → $PROJECT_NAME: $CREATED artefacto(s) nuevo(s) en .claude/memory/"
