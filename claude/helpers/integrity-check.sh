#!/usr/bin/env bash
[[ -f "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/helix-python.conf" ]] && source "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/helix-python.conf"
# integrity-check.sh — Verifica que hooks/settings/CLAUDE.md no fueron alterados sin autorización.
# Mantiene manifest en ~/.claude/data/integrity-manifest.json
# Uso:
#   bash integrity-check.sh verify    — compara estado actual vs manifest, alerta diffs
#   bash integrity-check.sh update    — actualiza manifest con estado actual (después de evolución registrada)
#   bash integrity-check.sh init      — crea manifest por primera vez
set -uo pipefail

# Layout split (v3.16+): Helix vive en ~/.helix/. Legacy: en ~/.claude/.
HELIX_ROOT="${CLAUDE_CONFIG_DIR:-$HOME/.helix}"
[[ -d "$HELIX_ROOT" ]] || HELIX_ROOT="$HOME/.claude"  # fallback legacy
MANIFEST="$HELIX_ROOT/data/integrity-manifest.json"
mkdir -p "$(dirname "$MANIFEST")"

cmd="${1:-verify}"

HOOK_CMD="$cmd" HOOK_MANIFEST="$MANIFEST" HELIX_ROOT="$HELIX_ROOT" "${HELIX_PYTHON:-python3}" <<'PYEOF'
import os, json, hashlib, sys
from datetime import datetime
from pathlib import Path

CMD = os.environ["HOOK_CMD"]
MANIFEST = Path(os.environ["HOOK_MANIFEST"])
HELIX_ROOT = Path(os.environ["HELIX_ROOT"])

# Archivos críticos a vigilar (relativos a HELIX_ROOT, no hardcoded ~/.claude)
TARGETS = [
    HELIX_ROOT / "settings.json",
    HELIX_ROOT / "CLAUDE.md",
]
# Hooks del directorio helpers (.sh, .cjs, .py — antes solo .sh)
HELPERS_DIR = HELIX_ROOT / "helpers"
for ext in ("*.sh", "*.cjs", "*.py"):
    for p in sorted(HELPERS_DIR.glob(ext)):
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

def snapshot() -> dict:
    return {
        "ts": datetime.now().isoformat(timespec="seconds"),
        "root": str(HELIX_ROOT),
        "files": {
            str(p.relative_to(HELIX_ROOT)): {
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
        print(f"{YELLOW}  Añadidos ({len(added)}) — revisar si esperabas estos archivos:{NC}")
        for p in added[:10]: print(f"    + {p}")
    if removed:
        print(f"{RED}  Eliminados ({len(removed)}):{NC}")
        for p in removed[:10]: print(f"    - {p}")
    print(f"\n  Si los cambios son legítimos (evolución tuya):")
    print(f"    bash ~/.claude/helpers/integrity-check.sh update")
    print(f"  Si son sospechosos: revisar manualmente antes de continuar.")
    sys.exit(1 if (changed or removed or added) else 0)

print(f"Uso: {sys.argv[0] if len(sys.argv)>0 else 'integrity-check.sh'} verify|update|init")
sys.exit(2)
PYEOF
