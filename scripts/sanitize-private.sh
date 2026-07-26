#!/usr/bin/env bash
# ============================================================
# sanitize-private.sh — Deja los .md del repo aptos para el público
#
# El leak del 2026-07-01 (campaña ‹cliente-aseguradora›) entró por el bloque SESIONES del
# CLAUDE.md que `update.sh` copiaba verbatim. La doctrina exige desde entonces
# que METRICS/SESSIONS vayan vacíos en el repo, pero NADA lo aplicaba: era una
# nota en un CLAUDE.md, no un paso ejecutable.
#
# Dos operaciones:
#   1. Vaciar los bloques por marker: SESSIONS y METRICS son metadata de
#      sesiones reales del creator — nunca tienen valor público.
#   2. Filtrar por patrón las FILAS que nombren clientes en el resto del
#      documento (EVOLUTION_LOG, SECURITY, OPERABILITY). Se descarta la fila,
#      no el bloque: el aprendizaje técnico del resto sí es valor público.
#
# Idempotente: dos corridas producen el mismo resultado.
# NO toca el CLAUDE.md vivo (~/.helix) — sólo la copia del repo.
#
# Acepta 1..N archivos. El vaciado por marker sólo aplica donde existan los
# markers (CLAUDE.md); el filtrado por patrón aplica a todos.
#
# Uso: bash sanitize-private.sh <archivo.md> [archivo2.md ...]
# ============================================================
set -euo pipefail

TARGETS=("$@")
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PATTERNS_FILE="$REPO_DIR/scripts/private-patterns.txt"

if [[ ${#TARGETS[@]} -eq 0 ]]; then
  echo "Uso: $0 <archivo.md> [archivo2.md ...]" >&2
  exit 1
fi

# Guard: nunca operar sobre el árbol vivo. Un bug acá reescribiría la doctrina
# del creator en vez de la copia pública.
TARGET_LIST=""
for t in "${TARGETS[@]}"; do
  [[ -f "$t" ]] || continue
  abs="$(cd "$(dirname "$t")" && pwd)/$(basename "$t")"
  case "$abs" in
    "$HOME/.helix/"*|"$HOME/.claude/"*)
      echo "❌ $abs pertenece al árbol VIVO — este script sólo sanitiza copias del repo." >&2
      exit 1 ;;
  esac
  TARGET_LIST+="$abs"$'\n'
done

if [[ -z "$TARGET_LIST" ]]; then
  echo "  = sin archivos que sanitizar"
  exit 0
fi

[[ -f "$PATTERNS_FILE" ]] || { echo "❌ no encuentro $PATTERNS_FILE" >&2; exit 1; }

TARGET_LIST="$TARGET_LIST" PATTERNS_FILE="$PATTERNS_FILE" python3 <<'PYEOF'
import os, re, sys

targets = [t for t in os.environ["TARGET_LIST"].split("\n") if t.strip()]
patterns_file = os.environ["PATTERNS_FILE"]

# ── cargar patrones ──────────────────────────────────────────
pats = []
with open(patterns_file, encoding="utf-8") as f:
    for line in f:
        line = line.rstrip("\n")
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        fields = line.split("|")
        pat = fields[0]
        action = fields[2].strip() if len(fields) > 2 else "drop"
        # El formato del archivo es ERE con clases POSIX; se traduce a Python.
        py = pat.replace("[[:space:]]", r"\s")
        try:
            pats.append((re.compile(py, re.IGNORECASE), pat, action))
        except re.error:
            print(f"  ⚠️  patrón inválido, ignorado: {pat}", file=sys.stderr)

def sanitize(target):
    """Devuelve (emptied, dropped, redacted) y reescribe el archivo si cambió."""
    text = open(target, encoding="utf-8").read()
    original = text
    # SEGURIDAD: en archivos de código, descartar una línea puede romper un
    # heredoc, cerrar mal un bloque o dejar sintaxis inválida. Fuera de .md
    # sólo se redacta, nunca se descarta.
    code_file = not target.endswith(".md")

    # ── 1. vaciar bloques por marker (sólo donde existan) ────────
    EMPTY_BLOCKS = [
        ("SESSIONS", "> Metadata de sesiones del creator — vaciado en el repo público."),
        ("METRICS",  "> Métricas locales del creator — vaciadas en el repo público."),
    ]
    emptied = []
    for name, note in EMPTY_BLOCKS:
        s, e = f"<!-- {name}_START -->", f"<!-- {name}_END -->"
        rx = re.compile(re.escape(s) + r".*?" + re.escape(e), re.S)
        m = rx.search(text)
        if not m:
            continue
        replacement = f"{s}\n{note}\n{e}"
        if m.group(0) != replacement:
            text = rx.sub(replacement, text, count=1)
            emptied.append(name)

    # ── 2. filtrar/redactar líneas con contexto de cliente ───────
    # Cae la fila, no el bloque. `redact` conserva la línea reemplazando el
    # identificador: un aprendizaje técnico que sólo menciona de paso un repo
    # privado no debe perderse del repo público.
    PLACEHOLDER = "\u2039privado\u203a"
    kept, dropped, redacted = [], [], []
    for line in text.split("\n"):
        if not line.strip():
            kept.append(line)
            continue
        # drop gana sobre redact: si la línea nombra un cliente, cae completa
        drop_hit = None if code_file else next(
            (raw for rx, raw, act in pats if act == "drop" and rx.search(line)), None)
        if drop_hit:
            dropped.append(drop_hit)
            continue
        new_line = line
        for rx, raw, act in pats:
            if (act == "redact" or code_file) and rx.search(new_line):
                new_line = rx.sub(PLACEHOLDER, new_line)
                redacted.append(raw)
        kept.append(new_line)
    text = "\n".join(kept)

    if text != original:
        open(target, "w", encoding="utf-8").write(text)
    return emptied, dropped, redacted


def tally(items):
    out = {}
    for i in items:
        out[i] = out.get(i, 0) + 1
    return sorted(out.items(), key=lambda kv: -kv[1])


total_files = 0
for target in targets:
    emptied, dropped, redacted = sanitize(target)
    if not (emptied or dropped or redacted):
        continue
    total_files += 1
    print(f"  \u2022 {os.path.basename(target)}")
    if emptied:
        print(f"      bloques vaciados: {', '.join(emptied)}")
    for pat, n in tally(dropped):
        print(f"      drop   {n}\u00d7 {pat}")
    for pat, n in tally(redacted):
        print(f"      redact {n}\u00d7 {pat}")

if total_files == 0:
    print(f"  = {len(targets)} archivo(s) ya estaban limpios")
else:
    print(f"  \u2713 {total_files} de {len(targets)} archivo(s) saneados")
PYEOF
