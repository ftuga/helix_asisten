#!/usr/bin/env bash
# =========================================================
# frontend-brief-gen.sh — Genera un brief de estilo visual
# a partir de un proyecto Next.js/React referencia.
#
# Uso:
#   bash ~/.helix/helpers/frontend-brief-gen.sh <PROJECT_PATH> [OUTPUT_DIR]
#
# Ejemplos:
#   bash ~/.helix/helpers/frontend-brief-gen.sh \
#     ~/documentos/proyectos_tecnologicos/pagina_web
#
#   bash ~/.helix/helpers/frontend-brief-gen.sh \
#     ~/documentos/proyectos_tecnologicos/pagina_web \
#     ~/mis-briefs
#
# Salida por defecto: ~/.helix/memory/frontend-briefs/<nombre-proyecto>-style-brief.md
#
# Constraints:
#   - bash + python3 stdlib unicamente. Sin pip, sin npm.
#   - 100% local, cero egress.
#   - Idempotente: dos ejecuciones sin cambios producen el mismo output.
#   - Falla con mensaje claro si los archivos fuente no existen o estan vacios.
#   - No toca nada fuera del OUTPUT_DIR (debe estar bajo $HOME).
#   - No ejecuta git. No instala nada.
#
# Nota: realpath requiere GNU coreutils. En macOS usar greadlink (brew coreutils).
# =========================================================

set -euo pipefail

# ---- Argumentos ----
PROJECT_PATH="${1:-}"
OUTPUT_DIR="${2:-$HOME/.helix/memory/frontend-briefs}"

if [[ -z "$PROJECT_PATH" ]]; then
  echo "ERROR: Debes pasar el path del proyecto referencia como primer argumento." >&2
  echo "       Uso: bash $0 <PROJECT_PATH> [OUTPUT_DIR]" >&2
  exit 1
fi

PROJECT_PATH="$(realpath "$PROJECT_PATH")"
OUTPUT_DIR="$(realpath "$OUTPUT_DIR")"

# ---- Fix #5: validar que OUTPUT_DIR este bajo $HOME ----
if [[ "$OUTPUT_DIR" != "$HOME"/* ]]; then
  echo "ERROR: OUTPUT_DIR debe estar bajo \$HOME por seguridad. Valor recibido: $OUTPUT_DIR" >&2
  exit 1
fi

if [[ ! -d "$PROJECT_PATH" ]]; then
  echo "ERROR: El directorio del proyecto no existe: $PROJECT_PATH" >&2
  exit 1
fi

PROJECT_NAME="$(basename "$PROJECT_PATH")"
OUTPUT_FILE="$OUTPUT_DIR/${PROJECT_NAME}-style-brief.md"

# ---- Archivos fuente requeridos ----
SYSTEM_CSS="$PROJECT_PATH/styles/system.css"
CLAUDE_MD="$PROJECT_PATH/CLAUDE.md"
MOTION_DIR="$PROJECT_PATH/components/motion"
REVEAL_CTRL="$PROJECT_PATH/components/chrome/RevealController.tsx"

# Verificar existencia y que no esten vacios (Fix opcional #1)
MISSING=0
for f in "$SYSTEM_CSS" "$CLAUDE_MD"; do
  if [[ ! -f "$f" ]]; then
    echo "ERROR: Archivo fuente requerido no encontrado: $f" >&2
    MISSING=1
  elif [[ ! -s "$f" ]]; then
    echo "ERROR: Archivo fuente requerido esta vacio: $f" >&2
    MISSING=1
  fi
done
if [[ ! -d "$MOTION_DIR" ]]; then
  echo "ERROR: Directorio de motion no encontrado: $MOTION_DIR" >&2
  MISSING=1
fi
if [[ $MISSING -eq 1 ]]; then
  exit 1
fi

# ---- Fix #2: detectar lib/motion dinamicamente ----
MOTION_LIB_PATH="$PROJECT_PATH/lib/motion"
MOTION_LIB_DESC=""
MOTION_LIB_FILES=""
if [[ -f "$MOTION_LIB_PATH.ts" ]]; then
  MOTION_LIB_DESC="lib/motion.ts (archivo unico)"
  MOTION_LIB_FILES="lib/motion.ts"
elif [[ -d "$MOTION_LIB_PATH" ]]; then
  LIB_COUNT=$(find "$MOTION_LIB_PATH" -type f \( -name "*.ts" -o -name "*.tsx" \) | wc -l | tr -d ' ')
  MOTION_LIB_DESC="lib/motion/ (directorio con $LIB_COUNT archivos)"
  MOTION_LIB_FILES=$(find "$MOTION_LIB_PATH" -type f \( -name "*.ts" -o -name "*.tsx" \) | sort | sed "s|$PROJECT_PATH/||")
else
  MOTION_LIB_DESC="(no encontrado — verificar estructura del proyecto)"
  MOTION_LIB_FILES=""
fi

mkdir -p "$OUTPUT_DIR"

# ---- Fix #3: hash cubre tambien lib/motion/* ----
HASH_SOURCES=("$SYSTEM_CSS" "$CLAUDE_MD")

# motion components (.tsx)
while IFS= read -r -d '' f; do
  HASH_SOURCES+=("$f")
done < <(find "$MOTION_DIR" -type f -name "*.tsx" -print0 | sort -z)

# RevealController
if [[ -f "$REVEAL_CTRL" ]]; then
  HASH_SOURCES+=("$REVEAL_CTRL")
fi

# lib/motion hooks (Fix #3)
if [[ -d "$MOTION_LIB_PATH" ]]; then
  while IFS= read -r -d '' f; do
    HASH_SOURCES+=("$f")
  done < <(find "$MOTION_LIB_PATH" -type f \( -name "*.ts" -o -name "*.tsx" \) -print0 | sort -z)
elif [[ -f "$MOTION_LIB_PATH.ts" ]]; then
  HASH_SOURCES+=("$MOTION_LIB_PATH.ts")
fi

CONTENT_HASH=$(python3 - "${HASH_SOURCES[@]}" <<'PYEOF'
import sys, hashlib, pathlib
h = hashlib.sha256()
for p in sys.argv[1:]:
    try:
        h.update(pathlib.Path(p).read_bytes())
    except FileNotFoundError:
        pass
print(h.hexdigest()[:16])
PYEOF
)

GENERATED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

# ---- Extraer secciones del CLAUDE.md ----
extract_section() {
  python3 - "$1" "$2" "$3" <<'PYEOF'
import sys, re, pathlib

filepath, start_marker, end_marker = sys.argv[1], sys.argv[2], sys.argv[3]
text = pathlib.Path(filepath).read_text(encoding='utf-8')
lines = text.splitlines()

capturing = False
result = []
found_end = False
for line in lines:
    if re.search(re.escape(start_marker), line):
        capturing = True
    elif capturing and re.search(re.escape(end_marker), line):
        found_end = True
        break
    if capturing:
        result.append(line)

# Fix opcional #3: advertir si no se encontro el end_marker
if capturing and not found_end:
    import sys as _sys
    print(f"<!-- ADVERTENCIA: end_marker '{end_marker}' no encontrado — seccion capturada hasta EOF -->",
          file=_sys.stderr)

print('\n'.join(result))
PYEOF
}

SECTION_2=$(extract_section "$CLAUDE_MD" "## 2. Sistema de diseño" "## 3.")
SECTION_4=$(extract_section "$CLAUDE_MD" "## 4. Patrones recurrentes" "## 5.")

# ---- Extraer tokens CSS del system.css ----
extract_css_tokens() {
  python3 - "$1" <<'PYEOF'
import sys, re, pathlib

text = pathlib.Path(sys.argv[1]).read_text(encoding='utf-8')

# Extraer bloque :root completo con balanceo de llaves
idx = text.find(':root')
if idx < 0:
    print("(no se encontro bloque :root)")
    sys.exit(0)

brace = text.find('{', idx)
depth, j = 1, brace + 1
while depth and j < len(text):
    if text[j] == '{': depth += 1
    elif text[j] == '}': depth -= 1
    j += 1
root_block = text[brace+1:j-1]

tokens = []
for line in root_block.splitlines():
    stripped = line.strip()
    # Fix opcional #2: filtrar comentarios CSS sueltos, incluir solo vars y comentarios de seccion
    if stripped.startswith('--'):
        tokens.append(stripped)
    elif stripped.startswith('/*') and stripped.endswith('*/'):
        # Solo comentarios de una linea (etiquetas de seccion)
        tokens.append(stripped)

print('\n'.join(tokens))
PYEOF
}

CSS_TOKENS=$(extract_css_tokens "$SYSTEM_CSS")

# ---- Fix #1: Extraer @keyframes y clases CSS con parser de llaves balanceadas ----
extract_animation_classes() {
  python3 - "$1" <<'PYEOF'
import sys, pathlib

text = pathlib.Path(sys.argv[1]).read_text(encoding='utf-8')

def extract_balanced_blocks(text, prefix):
    """Extrae bloques CSS que comienzan con `prefix` balanceando llaves."""
    out, i = [], 0
    while True:
        idx = text.find(prefix, i)
        if idx < 0:
            break
        brace = text.find('{', idx)
        if brace < 0:
            break
        depth, j = 1, brace + 1
        while depth and j < len(text):
            if text[j] == '{':
                depth += 1
            elif text[j] == '}':
                depth -= 1
            j += 1
        out.append(text[idx:j])
        i = j
    return out

# Keyframes con balanceo correcto
keyframes = extract_balanced_blocks(text, '@keyframes ')

# Clases de animacion/reveal/editorial — buscar por selector exacto
SELECTORS = [
    '.reveal ',
    '.reveal.',
    '.reveal:',
    '.reveal\n',
    '.word-mask',
    '.marquee',
    '.arrow-link',
    '.ed-display',
    '.ed-section-title',
    '.ed-kicker',
    '.ed-reveal',
    '.ed-stagger',
]

css_classes = []
for sel in SELECTORS:
    # Buscar todas las ocurrencias del selector
    start = 0
    while True:
        idx = text.find(sel, start)
        if idx < 0:
            break
        # Retroceder al inicio de la regla (pueden haber comentarios antes)
        brace = text.find('{', idx)
        if brace < 0:
            break
        depth, j = 1, brace + 1
        while depth and j < len(text):
            if text[j] == '{':
                depth += 1
            elif text[j] == '}':
                depth -= 1
            j += 1
        block = text[idx:j].strip()
        if block not in css_classes:
            css_classes.append(block)
        start = j

# Tambien capturar bloque @media prefers-reduced-motion si existe
motion_pref = extract_balanced_blocks(text, '@media (prefers-reduced-motion')

print("### @keyframes\n")
for kf in keyframes:
    print(kf.strip())
    print()

if motion_pref:
    print("### @media prefers-reduced-motion\n")
    for blk in motion_pref:
        print(blk.strip())
        print()

print("### Clases de animacion/reveal/editorial\n")
for cls in css_classes:
    print(cls.strip())
    print()
PYEOF
}

ANIMATION_CSS=$(extract_animation_classes "$SYSTEM_CSS")

# ---- Leer componentes de motion ----
read_motion_components() {
  python3 - "$1" "$2" <<'PYEOF'
import sys, pathlib

motion_dir = pathlib.Path(sys.argv[1])
reveal_ctrl = pathlib.Path(sys.argv[2]) if len(sys.argv) > 2 else None

tsx_files = sorted(motion_dir.glob("*.tsx"))

print("### components/motion/\n")
for f in tsx_files:
    content = f.read_text(encoding='utf-8')
    print(f"#### {f.name}\n")
    print("```tsx")
    print(content.strip())
    print("```\n")

if reveal_ctrl and reveal_ctrl.exists():
    print("### components/chrome/RevealController.tsx\n")
    content = reveal_ctrl.read_text(encoding='utf-8')
    print("```tsx")
    print(content.strip())
    print("```\n")
PYEOF
}

MOTION_COMPONENTS=$(read_motion_components "$MOTION_DIR" "$REVEAL_CTRL")

# ---- Extraer estructura de componentes del proyecto ----
# Fix opcional #4: advertir si hay mas de 60 componentes
COMPONENT_LIST_RAW=$(find "$PROJECT_PATH/components" -type f -name "*.tsx" 2>/dev/null | sort | sed "s|$PROJECT_PATH/||")
COMPONENT_COUNT=$(echo "$COMPONENT_LIST_RAW" | wc -l | tr -d ' ')
if [[ $COMPONENT_COUNT -gt 60 ]]; then
  PROJECT_STRUCTURE="$(echo "$COMPONENT_LIST_RAW" | head -60)
... (${COMPONENT_COUNT} componentes en total — mostrando primeros 60)"
else
  PROJECT_STRUCTURE="$COMPONENT_LIST_RAW"
fi

# ---- Fix #4: paths absolutos → placeholder en el brief ----
# Todas las referencias a PROJECT_PATH en el brief usan <PROJECT_PATH>
# para evitar leak de PATH_USERNAME (constraint R2 council)

# ---- Generar el brief ----
cat > "$OUTPUT_FILE" << BRIEF_EOF
<!--
  frontend-style-brief — ${PROJECT_NAME}
  Generado: ${GENERATED_AT}
  Source hash (sha256 primeros 16 chars): ${CONTENT_HASH}

  STALENESS: si el hash cambia al comparar con una nueva ejecucion, regenerar con:
    bash ~/.helix/helpers/frontend-brief-gen.sh <PROJECT_PATH> [OUTPUT_DIR]

  NO editar manualmente. Regenerar desde el proyecto fuente.
-->

# Frontend Style Brief — ${PROJECT_NAME}

> Brief auto-generado el ${GENERATED_AT}. Hash fuente: \`${CONTENT_HASH}\`.
> Hash cubre: system.css + CLAUDE.md + components/motion/*.tsx + RevealController.tsx + ${MOTION_LIB_DESC}.
> Regenerar si cualquiera de esos archivos cambia.

---

## 1. Tokens CSS — system.css (:root completo)

Valores hex reales. En la app destino, mapear a las variables propias del nuevo proyecto o a clases Tailwind equivalentes. No usar \`--ss-*\` fuera del proyecto referencia.

\`\`\`css
:root {
${CSS_TOKENS}
}
\`\`\`

---

## 2. Sistema de diseño (del CLAUDE.md del proyecto referencia)

${SECTION_2}

---

## 3. Clases de animacion y reveal (system.css)

Patrones CSS de animacion. Transplantables directamente si la app destino usa CSS puro o Tailwind con \`@layer\`. Adaptar nombres de variables al sistema de tokens de la nueva app.

${ANIMATION_CSS}

---

## 4. Patrones recurrentes (del CLAUDE.md del proyecto referencia)

${SECTION_4}

---

## 5. Componentes de motion (codigo fuente completo)

Implementaciones React/TypeScript de los patrones de animacion.

**Dependencia de hooks:** los componentes importan desde \`@/lib/motion\`, que en este proyecto es
**${MOTION_LIB_DESC}**. Al adaptar a otra app, copiar los hooks relevantes desde:

\`\`\`
${MOTION_LIB_FILES}
\`\`\`

${MOTION_COMPONENTS}

---

## 6. Estructura de componentes del proyecto referencia

\`\`\`
${PROJECT_STRUCTURE}
\`\`\`

---

## 7. Como usar este brief

Este brief captura el sistema visual de **${PROJECT_NAME}** para transplantarlo a otras aplicaciones. Leer antes de usarlo.

**Que transplantar (portabilidad alta):**
- Los **patrones estructurales**: seccion = eyebrow + titulo con \`<em>\` + copy + CTA dual. Funciona en cualquier identidad.
- Los **componentes de motion**: Reveal, Stagger, CountUp, RotateWords son independientes de la paleta. Solo necesitan sus hooks (ver §5) y el CSS de \`.reveal\` / \`.word-mask\`.
- El **trazo SVG animado** (descrito en §4): patron con dos \`<path>\` (.base + .trace) + \`stroke-dashoffset\` en loop ~4.2s. Aplica sobre cualquier palabra clave en cualquier identidad.
- Las **escalas tipograficas** con \`clamp()\` y los **valores de spacing** de \`:root\` (--space-1 a --space-10).
- El patron **CTA de cierre**: grid 2 columnas (1.2fr .8fr), colapsa a 1 col en <820px.

**Que adaptar (identidad-especifica de ${PROJECT_NAME}):**
- La **paleta** (\`--ss-green\`, \`--ss-purple\` y variantes): son colores institucionales de ‹entidad›. En otra app, mapear los patrones a los tokens propios del nuevo proyecto. Nunca usar \`--ss-*\` directamente fuera de este proyecto referencia.
- El **tono editorial**: "calido, humanista, nunca corporativo" es la voz de una fundacion de salud. Otra app puede requerir tono diferente.
- Las **fuentes** (Manrope + Fraunces): son elecciones de ‹entidad›. Sustituir segun identidad de la app destino.
- Las reglas de **copy** (§3 del CLAUDE.md): los principios son transferibles (cero filler, CTA duales), el registro especifico es de ‹entidad›.

**Proceso recomendado al invocar al agente para otra app:**
1. Pasar este brief como contexto.
2. Especificar explicitamente que transplantar y que adaptar para la nueva identidad.
3. Si la nueva app tiene su propio sistema de tokens, indicarlos — el agente mapeara los patrones, no copiara los hex de ‹entidad›.

**Staleness:** el hash \`${CONTENT_HASH}\` cubre system.css + CLAUDE.md + components/motion + ${MOTION_LIB_DESC}.
Para verificar si el brief esta actualizado, re-ejecutar y comparar el hash impreso en stdout.
Para regenerar:
\`\`\`bash
bash ~/.helix/helpers/frontend-brief-gen.sh <PROJECT_PATH>
\`\`\`
BRIEF_EOF

echo "Brief generado: $OUTPUT_FILE"
echo "Hash fuente:    $CONTENT_HASH"
echo "Lineas:         $(wc -l < "$OUTPUT_FILE")"
