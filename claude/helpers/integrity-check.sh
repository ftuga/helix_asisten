#!/usr/bin/env bash
[[ -f "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/helix-python.conf" ]] && source "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/helix-python.conf"
# integrity-check.sh — Verifica que hooks/settings/CLAUDE.md no fueron alterados sin autorización.
# Mantiene manifest en ~/.claude/data/integrity-manifest.json
# Uso:
#   bash integrity-check.sh verify    — compara estado actual vs manifest, alerta diffs
#   bash integrity-check.sh update    — actualiza manifest con estado actual (después de evolución registrada)
#   bash integrity-check.sh init      — crea manifest por primera vez
set -uo pipefail

MANIFEST="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/data/integrity-manifest.json"
mkdir -p "$(dirname "$MANIFEST")"

cmd="${1:-verify}"

HOOK_CMD="$cmd" HOOK_MANIFEST="$MANIFEST" "${HELIX_PYTHON:-python3}" <<'PYEOF'
import os, json, hashlib, sys
from datetime import datetime
from pathlib import Path

CMD = os.environ["HOOK_CMD"]
MANIFEST = Path(os.environ["HOOK_MANIFEST"])
HOME = Path.home()

# Resolve the LIVE config root from CLAUDE_CONFIG_DIR (TASK-008 / guardian HIGH
# finding): the manifest path was migrated to CLAUDE_CONFIG_DIR in evolutions
# 94/97 but this TARGETS block kept watching the legacy ~/.claude tree, leaving
# the live ~/.helix CLAUDE.md, settings and 50+ helpers (incl. helix-team.sh)
# with NO integrity monitoring. Fall back to ~/.claude when the env var is unset.
CONFIG = Path(os.environ.get("CLAUDE_CONFIG_DIR", str(HOME / ".claude")))

# Archivos críticos a vigilar
TARGETS = [
    CONFIG / "settings.json",
    CONFIG / "CLAUDE.md",
]
# Todos los hooks/helpers del directorio helpers (.sh y .py — MEDIUM-2:
# los .py ejecutables, incl. helix-judge/route-cost-audit/multidomain, no se
# vigilaban; un tamper de un .py pasaba sin detección).
HELPERS_DIR = CONFIG / "helpers"
for ext in ("*.sh", "*.py"):
    for p in sorted(HELPERS_DIR.glob(ext)):
        TARGETS.append(p)

# Scripts de ciclo de vida en la raíz de CONFIG (no viven en helpers/, así que
# el glob de arriba no los cubría) — MEDIUM-2.
for name in ("evolve.sh", "session-start.sh", "session-end.sh",
             "self-check.sh", "health-check.sh"):
    p = CONFIG / name
    if p.exists():
        TARGETS.append(p)

# Scripts de deliberación del council — MEDIUM-2.
COUNCIL_SCRIPTS = CONFIG / "council" / "scripts"
if COUNCIL_SCRIPTS.is_dir():
    for p in sorted(COUNCIL_SCRIPTS.glob("*.sh")):
        TARGETS.append(p)

# Capa 3 team — stable lead-authored artifacts only. board/tasks/*.json are
# EXCLUDED by design: they mutate legitimately on every claim/done/block, so
# hashing them would make verify fire constantly. Board tampering (F-02) is
# covered by the TASK-LEAD doctrine cross-check; a board journal is deferred
# to sprint 3. Protocol, role briefs and sprint plans are the static surface.
TEAM_DIR = CONFIG / "team"
if TEAM_DIR.is_dir():
    proto = TEAM_DIR / "protocol.md"
    if proto.exists():
        TARGETS.append(proto)
    for sub in ("roles", "plans"):
        d = TEAM_DIR / sub
        if d.is_dir():
            for p in sorted(d.glob("*.md")):
                TARGETS.append(p)

def hash_file(path: Path) -> str:
    h = hashlib.sha256()
    try:
        with open(path, "rb") as f:
            for chunk in iter(lambda: f.read(65536), b""):
                h.update(chunk)
        return h.hexdigest()
    except Exception:
        return ""

def manifest_key(p: Path) -> str:
    # Keep keys relative to HOME (stable across runs). Fall back to the
    # absolute path if a target lives outside HOME (non-standard config dir).
    try:
        return str(p.relative_to(HOME))
    except ValueError:
        return str(p)

def snapshot() -> dict:
    return {
        "ts": datetime.now().isoformat(timespec="seconds"),
        "files": {
            manifest_key(p): {
                "sha256": hash_file(p),
                "size": p.stat().st_size if p.exists() else 0,
                "mtime": int(p.stat().st_mtime) if p.exists() else 0,
            }
            for p in TARGETS
        }
    }

GREEN = "\033[0;32m"; YELLOW = "\033[0;33m"; RED = "\033[0;31m"; NC = "\033[0m"

if CMD in ("init", "update"):
    data = snapshot()
    MANIFEST.write_text(json.dumps(data, indent=2))
    print(f"{GREEN}✅ Manifest {'creado' if CMD=='init' else 'actualizado'}: {len(data['files'])} archivos{NC}")
    print(f"   → {MANIFEST}")
    sys.exit(0)

if CMD == "verify":
    if not MANIFEST.exists():
        print(f"{YELLOW}⚠️  No hay manifest previo — creando baseline ahora{NC}")
        data = snapshot()
        MANIFEST.write_text(json.dumps(data, indent=2))
        sys.exit(0)

    prev = json.loads(MANIFEST.read_text())
    cur = snapshot()
    prev_files = prev.get("files", {})
    cur_files = cur["files"]

    changed, added, removed = [], [], []
    for path, info in cur_files.items():
        if path not in prev_files:
            added.append(path)
        elif info["sha256"] != prev_files[path]["sha256"]:
            changed.append(path)
    for path in prev_files:
        if path not in cur_files:
            removed.append(path)

    if not (changed or added or removed):
        print(f"{GREEN}✅ Integrity OK — {len(cur_files)} archivos sin cambios desde {prev.get('ts','?')}{NC}")
        sys.exit(0)

    print(f"{YELLOW}⬡ Integrity Check — cambios detectados desde {prev.get('ts','?')}{NC}")
    if changed:
        print(f"{YELLOW}  Modificados ({len(changed)}):{NC}")
        for p in changed[:10]: print(f"    ~ {p}")
    if added:
        print(f"{GREEN}  Añadidos ({len(added)}):{NC}")
        for p in added[:10]: print(f"    + {p}")
    if removed:
        print(f"{RED}  Eliminados ({len(removed)}):{NC}")
        for p in removed[:10]: print(f"    - {p}")
    print(f"\n  Si los cambios son legítimos (evolución tuya):")
    print(f"    bash ~/.claude/helpers/integrity-check.sh update")
    print(f"  Si son sospechosos: revisar manualmente antes de continuar.")
    sys.exit(1 if changed or removed else 0)

print(f"Uso: {sys.argv[0] if len(sys.argv)>0 else 'integrity-check.sh'} verify|update|init")
sys.exit(2)
PYEOF
