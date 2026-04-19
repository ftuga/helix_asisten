#!/usr/bin/env bash
# secrets-scanner-hook.sh — PreToolUse(Write|Edit|MultiEdit|Bash):
# Detecta secretos antes de escribir a disco. Exit 2 bloquea.
# Regex: AWS, GCP, GitHub tokens, JWT largos, SSH privados, .env values comunes.
set -uo pipefail

PAYLOAD=$(cat)
[[ -z "$PAYLOAD" ]] && exit 0

HOOK_PAYLOAD="$PAYLOAD" python3 <<'PYEOF'
import sys, json, os, re

raw = os.environ.get("HOOK_PAYLOAD", "")
if not raw: sys.exit(0)

try:
    data = json.loads(raw)
except Exception:
    sys.exit(0)

tool_name = data.get("tool_name", "")
tool_input = data.get("tool_input", {}) or {}

# Extraer contenido candidato según tool
candidates = []
fp = tool_input.get("file_path", "")
if tool_name in ("Write",):
    candidates.append(("content", tool_input.get("content", "")))
elif tool_name in ("Edit",):
    candidates.append(("new_string", tool_input.get("new_string", "")))
elif tool_name in ("MultiEdit",):
    for e in tool_input.get("edits", []) or []:
        candidates.append(("new_string", e.get("new_string", "")))
elif tool_name == "Bash":
    # Heredocs / echo > file / tee /append
    cmd = tool_input.get("command", "") or ""
    # Capturar contenido heredoc
    for m in re.finditer(r"<<[-]?\s*['\"]?(\w+)['\"]?\s*\n(.*?)\n\1", cmd, re.DOTALL):
        candidates.append(("heredoc", m.group(2)))
    # Capturar echo "..." > file
    for m in re.finditer(r"echo\s+[\"'](.+?)[\"']\s*>>?\s*", cmd):
        candidates.append(("echo", m.group(1)))
    if not candidates:
        sys.exit(0)
else:
    sys.exit(0)

# Skip ficheros claramente de documentación/ejemplo/tests
def is_safe_target(path: str) -> bool:
    path_l = path.lower()
    for marker in [".env.example", ".example", "/test/", "/tests/", "_test.", ".test.",
                   "/fixtures/", "readme.md", "/docs/", ".gitignore",
                   # Helix internals (mismos hooks registran patrones)
                   "/.claude/helpers/", "/.claude/skills/",
                   "/memory/injection-alerts.jsonl", "/memory/reflexions.jsonl"]:
        if marker in path_l: return True
    return False

if fp and is_safe_target(fp):
    sys.exit(0)

PATTERNS = [
    # AWS
    (r"\bAKIA[0-9A-Z]{16}\b", "AWS:access-key-id"),
    (r"\baws_secret_access_key\s*=\s*['\"]?[A-Za-z0-9/+=]{40}['\"]?", "AWS:secret"),
    # GCP
    (r"-----BEGIN\s+PRIVATE\s+KEY-----", "GCP:service-account-key"),
    # GitHub
    (r"\bghp_[A-Za-z0-9]{36}\b", "GitHub:PAT"),
    (r"\bgho_[A-Za-z0-9]{36}\b", "GitHub:OAuth"),
    (r"\bghs_[A-Za-z0-9]{36}\b", "GitHub:Server"),
    (r"\bgithub_pat_[A-Za-z0-9_]{82}\b", "GitHub:FineGrained"),
    # OpenAI / Anthropic
    (r"\bsk-[A-Za-z0-9]{32,}\b", "OpenAI:apiKey"),
    (r"\bsk-ant-[A-Za-z0-9\-_]{40,}\b", "Anthropic:apiKey"),
    # Slack
    (r"\bxox[baprs]-[A-Za-z0-9-]{10,}\b", "Slack:token"),
    # Stripe
    (r"\b(sk|rk)_live_[A-Za-z0-9]{24,}\b", "Stripe:liveKey"),
    # Google API
    (r"\bAIza[0-9A-Za-z\-_]{35}\b", "Google:APIKey"),
    # SSH private keys
    (r"-----BEGIN\s+(RSA|OPENSSH|DSA|EC|PGP)\s+PRIVATE\s+KEY-----", "SSH:privateKey"),
    # JWT largos con firma real
    (r"\beyJ[A-Za-z0-9_-]{15,}\.[A-Za-z0-9_-]{15,}\.[A-Za-z0-9_-]{20,}\b", "JWT:signed"),
    # DB connection strings con password
    (r"(?i)(postgres|mysql|mongodb)(\+\w+)?://[^:\s]+:[^@\s]{4,}@", "DB:conn-with-password"),
]

hits = []
for label, content in candidates:
    if not isinstance(content, str) or not content:
        continue
    for pat, tag in PATTERNS:
        try:
            m = re.search(pat, content)
            if m:
                hits.append((tag, m.group(0)[:60], label))
        except re.error:
            continue

if not hits:
    sys.exit(0)

tags = sorted({h[0] for h in hits})
print(
    f"🔐 SECRET BLOCKED: {len(hits)} match(es) en {tool_name}\n"
    f"   Tipos: {', '.join(tags)}\n"
    f"   File: {fp or '(bash cmd)'}\n"
    f"   → Mover a variable de entorno o secret manager.\n"
    f"   → Si es falso positivo, usar .env.example o archivo de fixtures.",
    file=sys.stderr
)
sys.exit(2)
PYEOF
