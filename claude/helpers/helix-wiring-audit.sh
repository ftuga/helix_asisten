#!/usr/bin/env bash
# helix-wiring-audit.sh — Detecta "capability declarada != cableada".
#
# Origen (2026-07-26): health-check.sh reportaba "ecosistema en perfecto estado"
# mientras 3 fallas estructurales corrian en silencio:
#   1. skill-quality/skill-usage escritos a ~/.claude por helpers con path
#      hardcodeado, mientras todo lo que los LEE apunta a $CLAUDE_CONFIG_DIR.
#      Split-brain de ~3 meses.
#   2. helix-bitacora-hook.sh salia por `[[ ! -f "$BITACORA" ]] && exit 0` y
#      nada creaba el archivo -> 1 bitacora en todo el ecosistema.
#   3. `risk-map` citado en 2 reglas de CLAUDE.md sin existir en ningun proyecto
#      ni tener productor en el codigo.
#
# Un checker que nunca falla es sospechoso. Estos 3 chequeos FALLAN, no advierten.
#
# Salida: lineas `OK|msg`, `WARN|msg`, `FAIL|msg` para que el caller cuente.
# Exit: 0 sin fallos, 2 con fallos.
#
# Uso:
#   bash helix-wiring-audit.sh            # formato token para health-check
#   bash helix-wiring-audit.sh --human    # legible

set -uo pipefail

CLAUDE_HOME="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
MEMORY_DIR="$CLAUDE_HOME/memory"
STALE_DAYS="${HELIX_WIRING_STALE_DAYS:-14}"
HUMAN=0
[[ "${1:-}" == "--human" ]] && HUMAN=1

FAILS=0
emit() { # emit STATUS msg
  local st="$1"; shift
  [[ "$st" == "FAIL" ]] && FAILS=$((FAILS + 1))
  if (( HUMAN )); then
    case "$st" in
      OK)   echo "  ✅ $*" ;;
      WARN) echo "  ⚠️  $*" ;;
      FAIL) echo "  ❌ $*" ;;
    esac
  else
    echo "$st|$*"
  fi
}

# Telemetria CONTINUA: si Helix se usa, estos archivos se escriben. Silencio = roto.
CONTINUOUS="skill-usage.jsonl skill-quality.jsonl routing-feedback.jsonl routing-shadow.jsonl"

# Telemetria POR EVENTO: silencio es legitimo (dispara solo si ocurre el evento,
# o es on-demand por D2.1). Se les chequea que tengan writer, no frescura.
# judge-*/r1-*: on-demand only. nav-audit: solo con helix-nav. injection-alerts,
# aidefence-redactions, d1-multidomain, egress-audit: event-driven.
EVENT_DRIVEN="judge-decisions.jsonl judge-audit-feedback.jsonl r1-recommend-log.jsonl \
nav-audit.jsonl injection-alerts.jsonl aidefence-redactions.jsonl \
d1-multidomain-detections.jsonl egress-audit.jsonl capa2-bypass-counter.jsonl \
passive-captures-approved.jsonl passive-captures-rejected.jsonl \
passive-captures-pending.jsonl skill-quality-feedback.jsonl"

# Busca writers de un basename en el codigo del ecosistema
# Raices de codigo: el ecosistema no vive solo bajo CLAUDE_CONFIG_DIR — helix-nav.sh
# y otros scripts viven en el repo. Ignorar el repo produce falsos "huerfano".
CODE_ROOTS=("$CLAUDE_HOME/helpers" "$CLAUDE_HOME/council" "$CLAUDE_HOME/skills" "$CLAUDE_HOME/commands")
for repo in "$HOME/helix_asisten/scripts" "${HELIX_REPO:-}/scripts"; do
  [[ -n "$repo" && -d "$repo" ]] && CODE_ROOTS+=("$repo")
done

find_writers() {
  local target="$1"
  grep -rl --include='*.sh' --include='*.py' --include='*.md' -- "$target" \
    "${CODE_ROOTS[@]}" "$CLAUDE_HOME"/*.sh 2>/dev/null \
    | grep -v "helix-wiring-audit.sh" | grep -v "_DEPRECADOS" || true
}

# ═══════════════════════════════════════════════════════════════
# CHEQUEO 1 — telemetria continua con writer pero sin escribir
# ═══════════════════════════════════════════════════════════════
now=$(date +%s)
for name in $CONTINUOUS; do
  f="$MEMORY_DIR/$name"
  writers=$(find_writers "$name")
  if [[ -z "$writers" ]]; then
    emit FAIL "telemetria '$name' declarada continua pero NINGUN writer la escribe"
    continue
  fi
  if [[ ! -f "$f" ]]; then
    emit FAIL "telemetria '$name' tiene writer pero el archivo no existe en el arbol vivo"
    continue
  fi
  mtime=$(stat -c %Y "$f" 2>/dev/null || echo 0)
  age=$(( (now - mtime) / 86400 ))
  if (( age > STALE_DAYS )); then
    emit FAIL "telemetria '$name' sin escribir hace ${age}d (writer existe) — revisar si el writer apunta a otro arbol"
  else
    emit OK "telemetria '$name' viva (${age}d)"
  fi
done

for name in $EVENT_DRIVEN; do
  f="$MEMORY_DIR/$name"
  [[ -f "$f" ]] || continue
  writers=$(find_writers "$name")
  [[ -z "$writers" ]] && emit FAIL "'$name' existe en memory/ pero NINGUN codigo lo escribe — huerfano, borrar o cablear"
done

# ═══════════════════════════════════════════════════════════════
# CHEQUEO 2 — writers apuntando fuera de CLAUDE_CONFIG_DIR
# ═══════════════════════════════════════════════════════════════
# Solo lineas funcionales (no comentarios) que construyen un path GLOBAL a
# ~/.claude sin respetar CLAUDE_CONFIG_DIR. Los paths de PROYECTO
# (<proyecto>/.claude/...) son legitimos y se excluyen.
# Solo codigo (.sh/.py) — los .yaml/.md de council y memory son DATOS historicos.
# Se toleran dos formas legitimas: el fallback explicito `|| VAR="$HOME/.claude"`
# y las comparaciones de exclusion (`!=`, `==`) al detectar raiz de proyecto.
offenders=$(grep -rn --include='*.sh' --include='*.py' -E \
    'Path\.home\(\)[[:space:]]*/[[:space:]]*"\.claude|\$HOME/\.claude|expanduser\('"'"'~/\.claude' \
    "$CLAUDE_HOME/helpers" "$CLAUDE_HOME/council" "$CLAUDE_HOME"/*.sh 2>/dev/null \
  | grep -v 'CLAUDE_CONFIG_DIR' \
  | grep -vE ':[[:space:]]*#' \
  | grep -vE '\|\|[[:space:]]*[A-Z_]+=' \
  | grep -vE '(!=|==)[[:space:]]*(Path\.home\(\)|"?\$HOME)' \
  | grep -v 'helix-wiring-audit.sh' || true)

if [[ -n "$offenders" ]]; then
  while IFS= read -r line; do
    loc="${line%%:*}"; rest="${line#*:}"; lineno="${rest%%:*}"
    emit FAIL "path global a ~/.claude sin CLAUDE_CONFIG_DIR: $(basename "$loc"):${lineno}"
  done <<< "$offenders"
else
  emit OK "ningun writer apunta fuera de CLAUDE_CONFIG_DIR"
fi

# Reaparicion del arbol huerfano: si CLAUDE_CONFIG_DIR no es ~/.claude y
# ~/.claude/memory tiene .jsonl nuevos, hay un writer mal apuntado.
if [[ "$CLAUDE_HOME" != "$HOME/.claude" && -d "$HOME/.claude/memory" ]]; then
  strays=$(find "$HOME/.claude/memory" -maxdepth 1 -name "*.jsonl" 2>/dev/null | wc -l)
  if (( strays > 0 )); then
    emit FAIL "$strays .jsonl reaparecieron en ~/.claude/memory/ — hay un writer mal apuntado"
  else
    emit OK "arbol huerfano ~/.claude/memory limpio"
  fi
fi

# ═══════════════════════════════════════════════════════════════
# CHEQUEO 3 — doctrina que referencia artefactos inexistentes
# ═══════════════════════════════════════════════════════════════
# 3a: paths globales citados en CLAUDE.md deben existir.
# 3b: artefactos de proyecto (helix-*.md) citados deben tener PRODUCTOR.
GLOBAL_MD="$CLAUDE_HOME/CLAUDE.md"
if [[ -f "$GLOBAL_MD" ]]; then
  DOCTRINE_OUT=$(CLAUDE_HOME="$CLAUDE_HOME" HELIX_HOME_LITERAL="$HOME" "${HELIX_PYTHON:-python3}" - "$GLOBAL_MD" <<'PYEOF'
import os, re, subprocess, sys
from pathlib import Path

md = Path(sys.argv[1])
home = Path(os.environ["HELIX_HOME_LITERAL"])
config_dir = Path(os.environ["CLAUDE_HOME"])
text = md.read_text(encoding="utf-8", errors="replace")

def emit(status, msg):
    print(f"{status}|{msg}")

# ── 3a — paths globales citados en la doctrina
paths = set(re.findall(r'`(~/\.(?:claude|helix)/[A-Za-z0-9._/\-{}$]+)`', text))
missing = []
for p in sorted(paths):
    if "*" in p or "{" in p:      # globs y placeholders no son verificables
        continue
    real = home / p[2:]
    if real.exists():
        continue
    # tolerar drift de nombre de arbol: ~/.claude/x cuando el activo es ~/.helix/x
    alt = config_dir / p.split("/", 2)[2] if p.count("/") >= 2 else None
    if alt and alt.exists():
        continue
    missing.append(p)

# WARN, no FAIL: puede ser doc-rot o un artefacto que se crea on-demand
# (ej. capa0-disabled). Lo estructural lo cubre 3b.
if missing:
    for p in missing[:8]:
        emit("WARN", f"CLAUDE.md cita un path que no existe: {p}")
else:
    emit("OK", f"{len(paths)} paths globales citados en CLAUDE.md existen")

# ── 3b — artefactos de proyecto citados sin productor en el codigo
# (?<![\w-]) evita capturar substrings: sin el lookbehind,
# `fable5-helix-audit-20260610.md` matchea como `helix-audit-20260610.md`.
artifacts = set(re.findall(r'(?<![\w-])(helix-[a-z0-9\-]+\.md)', text))
# nombres genericos citados sin extension pero que son artefactos por doctrina
for bare in re.findall(r'`(risk-map|helix-risk-map)`', text):
    artifacts.add("helix-risk-map.md")
if "risk-map" in text:
    artifacts.add("helix-risk-map.md")

search_roots = [config_dir / d for d in ("helpers", "commands", "skills", "council")]
search_roots = [str(p) for p in search_roots if p.exists()]
for extra in (home / ".claude-template", home / "helix_asisten" / "scripts",
              home / "helix_asisten" / "template"):
    if extra.exists():
        search_roots.append(str(extra))

# Un artefacto que YA EXISTE en disco no necesita productor: es un doc escrito
# a mano (topics/, planes). Lo que importa es lo citado que no existe NI se genera.
def exists_somewhere(art: str) -> bool:
    for root in (config_dir / "memory", config_dir, home / "helix_asisten"):
        if not root.exists():
            continue
        r = subprocess.run(["find", str(root), "-name", art, "-print", "-quit"],
                           capture_output=True, text=True)
        if r.stdout.strip():
            return True
    return False

no_producer = []
for art in sorted(artifacts):
    if not search_roots:
        break
    r = subprocess.run(["grep", "-rl", "--", art, *search_roots],
                       capture_output=True, text=True)
    # Auto-exclusion: este propio script nombra los artefactos que busca.
    # Sin esto el guard se declara a si mismo como productor de todo.
    producers = [f for f in r.stdout.splitlines()
                 if "helix-wiring-audit.sh" not in f]
    if producers:
        continue
    if exists_somewhere(art):
        continue
    no_producer.append(art)

if no_producer:
    for art in no_producer:
        emit("FAIL", f"doctrina cita '{art}' pero NINGUN comando/helper/skill lo produce")
else:
    emit("OK", f"{len(artifacts)} artefactos citados en la doctrina tienen productor")
PYEOF
)
  # Un solo run: re-emitir por emit() para que el conteo de FAIL viva en bash
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    emit "${line%%|*}" "${line#*|}"
  done <<< "$DOCTRINE_OUT"
fi

if (( HUMAN )); then
  echo ""
  if (( FAILS > 0 )); then
    echo "  ❌ $FAILS falla(s) de cableado"
  else
    echo "  ✅ Sin fallas de cableado"
  fi
fi

(( FAILS > 0 )) && exit 2
exit 0
