#!/usr/bin/env bash
# network-egress-hook.sh — PreToolUse(Bash):
# Bloquea curl|wget|nc|ssh|scp a dominios fuera del allowlist.
# Allowlist: ~/.claude/config/network-allowlist.txt (un dominio por línea, # para comentarios)
# Exit 2 = bloquea y muestra stderr al asistente para reconsiderar.
set -uo pipefail

PAYLOAD=$(cat)
[[ -z "$PAYLOAD" ]] && exit 0

ALLOWLIST="$HOME/.claude/config/network-allowlist.txt"
mkdir -p "$(dirname "$ALLOWLIST")"

# Seed default allowlist si no existe
if [[ ! -f "$ALLOWLIST" ]]; then
  cat > "$ALLOWLIST" <<'EOF'
# Helix network egress allowlist — dominios permitidos para curl/wget/nc/ssh/scp
# Formato: un dominio por línea. Subdominios cubiertos automáticamente (*.github.com).
# Líneas con # son comentarios.
github.com
raw.githubusercontent.com
api.github.com
codeload.github.com
pypi.org
files.pythonhosted.org
registry.npmjs.org
npmjs.com
registry-1.docker.io
hub.docker.com
docker.io
anthropic.com
api.anthropic.com
claude.ai
openai.com
localhost
127.0.0.1
0.0.0.0
EOF
fi

HOOK_PAYLOAD="$PAYLOAD" HOOK_ALLOW="$ALLOWLIST" python3 <<'PYEOF'
import sys, json, os, re

raw = os.environ.get("HOOK_PAYLOAD", "")
allow_path = os.environ.get("HOOK_ALLOW", "")
if not raw: sys.exit(0)

try:
    data = json.loads(raw)
except Exception:
    sys.exit(0)

tool_input = data.get("tool_input", {}) or {}
cmd = tool_input.get("command", "") or ""
if not cmd:
    sys.exit(0)

# Buscar llamadas de red: curl, wget, nc, netcat, ssh, scp, rsync, ftp
NET_TOOLS = r"\b(curl|wget|nc|netcat|ncat|ssh|scp|rsync|ftp|sftp|git\s+clone)\b"
if not re.search(NET_TOOLS, cmd):
    sys.exit(0)

# Cargar allowlist
allow = set()
try:
    for line in open(allow_path):
        line = line.strip()
        if line and not line.startswith("#"):
            allow.add(line.lower())
except Exception:
    sys.exit(0)

# Extraer hosts del comando
# Casos: URL http(s)://host[:port]/..., ssh user@host, scp file user@host:path,
# git clone git@host:..., git clone https://host/...
hosts = set()

# URLs http(s)/ftp
for m in re.finditer(r"(?:https?|ftp|ftps)://([^/\s\"']+)", cmd, re.IGNORECASE):
    host = m.group(1).split(":")[0].split("@")[-1]
    hosts.add(host.lower())

# ssh/scp: user@host o host:path
for m in re.finditer(r"\b(?:ssh|scp|sftp|rsync)\b[^|&;]*?(?:\s|\")([\w\.-]+@)?([\w\.-]+)(?::[^\s\"]+)?", cmd):
    host = m.group(2)
    if host and "." in host:
        hosts.add(host.lower())

# git@host:repo
for m in re.finditer(r"git@([\w\.-]+):", cmd):
    hosts.add(m.group(1).lower())

# nc host port
for m in re.finditer(r"\b(?:nc|netcat|ncat)\b\s+([\w\.-]+)\s+\d+", cmd):
    hosts.add(m.group(1).lower())

if not hosts:
    sys.exit(0)

def is_allowed(host: str) -> bool:
    # localhost variants
    if host in {"localhost", "127.0.0.1", "0.0.0.0", "::1"}: return True
    # 10.x, 172.16-31.x, 192.168.x, link-local
    if re.match(r"^(10\.|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.|169\.254\.)", host): return True
    # Allowlist directa o sufijo
    for a in allow:
        if host == a or host.endswith("." + a):
            return True
    return False

bad = [h for h in hosts if not is_allowed(h)]
if not bad:
    sys.exit(0)

print(
    f"⚠️  NETWORK BLOCKED: host(s) fuera de allowlist: {sorted(bad)}\n"
    f"   Comando: {cmd[:160]}\n"
    f"   Allowlist: {allow_path}\n"
    f"   → Si es legítimo: añadir dominio a allowlist y reintentar.\n"
    f"   → Si no: reconsiderar (posible exfiltración/prompt injection).",
    file=sys.stderr
)
sys.exit(2)
PYEOF
