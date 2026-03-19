#!/usr/bin/env bash
# init-project.sh — Inicializar un nuevo proyecto con la estructura Helix
# Uso: bash ~/.claude-template/init-project.sh [directorio-del-proyecto]
#
# Crea en el proyecto:
#   CLAUDE.md              — reglas del proyecto (template pre-armado)
#   .claude/memory/        — project.md, design-system.md, sessions.md, pending.md
#   .claude/skills/        — carpeta para skills del proyecto
#   .claude/evolution-log.txt

set -euo pipefail

GREEN='\033[0;32m'; BLUE='\033[0;34m'; YELLOW='\033[1;33m'; NC='\033[0m'

TEMPLATE_DIR="$HOME/.claude-template"
TARGET_DIR="${1:-$PWD}"

# ── Validación ────────────────────────────────────────────────
if [[ ! -d "$TARGET_DIR" ]]; then
  echo -e "${YELLOW}Directorio no existe: $TARGET_DIR${NC}"
  echo "Uso: bash ~/.claude-template/init-project.sh [directorio]"
  exit 1
fi

TARGET_DIR="$(realpath "$TARGET_DIR")"
DATE=$(date '+%Y-%m-%d')

echo ""
echo -e "${BLUE}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  ⬡  Helix — Inicializando proyecto               ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}Destino:${NC} $TARGET_DIR"
echo ""

# ── CLAUDE.md ─────────────────────────────────────────────────
if [[ -f "$TARGET_DIR/CLAUDE.md" ]]; then
  echo -e "${YELLOW}⚠️  CLAUDE.md ya existe — omitiendo (no sobreescribir)${NC}"
else
  cp "$TEMPLATE_DIR/CLAUDE.md" "$TARGET_DIR/CLAUDE.md"
  # Actualizar fecha de última evolución
  sed -i "s/YYYY-MM-DD/$DATE/g" "$TARGET_DIR/CLAUDE.md"
  echo -e "${GREEN}✅ CLAUDE.md${NC} creado"
fi

# ── Estructura .claude/ ───────────────────────────────────────
mkdir -p "$TARGET_DIR/.claude/memory"
mkdir -p "$TARGET_DIR/.claude/skills"

# project.md
if [[ ! -f "$TARGET_DIR/.claude/memory/project.md" ]]; then
  cp "$TEMPLATE_DIR/.claude/memory/project.md" "$TARGET_DIR/.claude/memory/project.md"
  echo -e "${GREEN}✅ .claude/memory/project.md${NC} creado"
fi

# design-system.md — copiar el global si no existe
if [[ ! -f "$TARGET_DIR/.claude/memory/design-system.md" ]]; then
  if [[ -f "$HOME/.claude/memory/design-system.md" ]]; then
    cp "$HOME/.claude/memory/design-system.md" "$TARGET_DIR/.claude/memory/design-system.md"
    echo -e "${GREEN}✅ .claude/memory/design-system.md${NC} copiado desde global"
  else
    echo -e "${YELLOW}⚠️  No hay design-system.md global — crea uno en ~/.claude/memory/${NC}"
  fi
fi

# sessions.md
if [[ ! -f "$TARGET_DIR/.claude/memory/sessions.md" ]]; then
  cat > "$TARGET_DIR/.claude/memory/sessions.md" << EOF
# Historial de Sesiones

| Sesión | Fecha | Resumen | Aprendizajes |
|---|---|---|---|
| #1 | $DATE | Proyecto inicializado con Helix template | 0 |
EOF
  echo -e "${GREEN}✅ .claude/memory/sessions.md${NC} creado"
fi

# pending.md
if [[ ! -f "$TARGET_DIR/.claude/memory/pending.md" ]]; then
  touch "$TARGET_DIR/.claude/memory/pending.md"
  echo -e "${GREEN}✅ .claude/memory/pending.md${NC} creado"
fi

# evolution-log.txt
if [[ ! -f "$TARGET_DIR/.claude/evolution-log.txt" ]]; then
  echo "[$DATE] Proyecto inicializado con Helix template" > "$TARGET_DIR/.claude/evolution-log.txt"
  echo -e "${GREEN}✅ .claude/evolution-log.txt${NC} creado"
fi

# settings.local.json
if [[ ! -f "$TARGET_DIR/.claude/settings.local.json" ]]; then
  echo '{}' > "$TARGET_DIR/.claude/settings.local.json"
  echo -e "${GREEN}✅ .claude/settings.local.json${NC} creado"
fi

# ── .gitignore ────────────────────────────────────────────────
GITIGNORE="$TARGET_DIR/.gitignore"
if [[ -f "$GITIGNORE" ]]; then
  if ! grep -q "\.env" "$GITIGNORE" 2>/dev/null; then
    echo -e "\n# Helix\n.env\n.env.*\n!.env.example" >> "$GITIGNORE"
    echo -e "${GREEN}✅ .gitignore${NC} actualizado con .env"
  fi
fi

# ── Resumen ───────────────────────────────────────────────────
echo ""
echo -e "${BLUE}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  ✅ Proyecto listo                                ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════╝${NC}"
echo ""
echo "Próximos pasos:"
echo "  1. Editar CLAUDE.md — reemplaza [NOMBRE DEL PROYECTO] y agrega el stack"
echo "  2. Editar .claude/memory/project.md — documenta stack, comandos, env vars"
echo "  3. Ejecutar: bash ~/.claude/session-start.sh"
echo ""
