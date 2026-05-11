#!/usr/bin/env bash
# helix-python-patcher.sh — Migrate `python3` → `"${HELIX_PYTHON:-python3}"` in .sh files.
# Preserves line endings (CRLF on Windows). Backs up to .pybak. Idempotent.
# Excludes detector + this patcher. Manual cases printed at end.
set -uo pipefail

CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
BACKUP_TAG=".pybak"
SOURCE_LINE='[[ -f "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/helix-python.conf" ]] && source "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/helix-python.conf"'
SENTINEL='helix-python.conf'

source "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/helix-python.conf" 2>/dev/null || true
PY="${HELIX_PYTHON:-python3}"

MANUAL_CASES=(
    "helpers/helix-longmemeval.sh"
    "helpers/helix-reflexion.sh"
)

EXCLUDES=(
    "/helpers/helix-python-detect.sh"
    "/helpers/helix-python-patcher.sh"
)

is_excluded() {
    local f="$1"
    for e in "${EXCLUDES[@]}"; do
        [[ "$f" == *"$e" ]] && return 0
    done
    return 1
}

mapfile -t FILES < <(grep -rl --include='*.sh' '\bpython3\b' "$CLAUDE_DIR" 2>/dev/null)

PATCHED=0
SKIPPED=0
ALREADY=0
FAILED=()

for f in "${FILES[@]}"; do
    if is_excluded "$f"; then
        SKIPPED=$((SKIPPED + 1))
        continue
    fi

    # Already patched: sentinel present AND no remaining bare `python3` outside comments/quoted-replacement
    if grep -qF "$SENTINEL" "$f"; then
        if ! grep -qE '(^|[^A-Za-z0-9_"-])python3([^A-Za-z0-9_]|$)' "$f"; then
            ALREADY=$((ALREADY + 1))
            continue
        fi
    fi

    cp -p "$f" "$f$BACKUP_TAG"

    # Convert MSYS path → Windows path for Python
    F_WIN=$(cygpath -w "$f" 2>/dev/null || echo "$f")
    BAK_WIN=$(cygpath -w "$f$BACKUP_TAG" 2>/dev/null || echo "$f$BACKUP_TAG")

    "$PY" - "$BAK_WIN" "$F_WIN" "$SOURCE_LINE" "$SENTINEL" <<'PYEOF'
import sys, re

src_path, dst_path, source_line, sentinel = sys.argv[1:5]

with open(src_path, 'rb') as fh:
    raw = fh.read()

# Detect line ending
nl = b'\r\n' if b'\r\n' in raw else b'\n'

# Decode (keep ending bytes intact by splitting on the detected nl)
try:
    text = raw.decode('utf-8')
except UnicodeDecodeError:
    text = raw.decode('utf-8', errors='replace')

# Split by detected line ending into "logical lines"
nl_str = nl.decode('utf-8')
lines = text.split(nl_str)

# Replace `python3` only on non-comment lines (lines whose first non-whitespace is not '#')
COMMENT_RE = re.compile(r'^\s*#')
TOKEN_RE   = re.compile(r'\bpython3\b')
REPLACEMENT = '"${HELIX_PYTHON:-python3}"'

new_lines = []
for line in lines:
    if COMMENT_RE.match(line):
        new_lines.append(line)
    else:
        new_lines.append(TOKEN_RE.sub(REPLACEMENT, line))

new_text = nl_str.join(new_lines)

# Insert source line after shebang if sentinel absent
if sentinel not in new_text:
    parts = new_text.split(nl_str, 1)
    if parts and parts[0].startswith('#!'):
        head = parts[0]
        rest = parts[1] if len(parts) > 1 else ''
        new_text = head + nl_str + source_line + nl_str + rest

with open(dst_path, 'wb') as fh:
    fh.write(new_text.encode('utf-8'))

PYEOF

    if [[ $? -ne 0 ]]; then
        echo "FAIL: python patcher errored on $f" >&2
        cp -p "$f$BACKUP_TAG" "$f"
        FAILED+=("$f")
        continue
    fi

    if ! bash -n "$f" 2>/dev/null; then
        echo "FAIL: syntax error after patch — $f (restored from backup)" >&2
        cp -p "$f$BACKUP_TAG" "$f"
        FAILED+=("$f")
        continue
    fi

    PATCHED=$((PATCHED + 1))
done

echo ""
echo "──────────────────────────────────────"
echo "Patched:           $PATCHED"
echo "Already patched:   $ALREADY"
echo "Skipped (excluded): $SKIPPED"
echo "Failed:            ${#FAILED[@]}"
if [[ ${#FAILED[@]} -gt 0 ]]; then
    printf '  - %s\n' "${FAILED[@]}"
fi
echo ""
echo "Manual cases (python3 inside Python heredoc — bash var not expanded):"
for m in "${MANUAL_CASES[@]}"; do
    echo "  - $CLAUDE_DIR/$m"
done
echo ""
echo "Revert all backups:"
echo "  find $CLAUDE_DIR -name '*$BACKUP_TAG' -exec sh -c 'mv \"\$0\" \"\${0%$BACKUP_TAG}\"' {} \\;"
