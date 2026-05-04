#!/usr/bin/env bash
[[ -f "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/helix-python.conf" ]] && source "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/helix-python.conf"
# helix-detect-stack.sh — Detección determinista de stack
# Uso: bash helix-detect-stack.sh [PROJECT_ROOT]
# Imprime JSON estructurado con el stack detectado
set -uo pipefail

PROJECT="${1:-$PWD}"

# ── Helpers ───────────────────────────────────────────────────
has_file()  { [[ -f "$PROJECT/$1" ]]; }
has_dir()   { [[ -d "$PROJECT/$1" ]]; }
read_json() { "${HELIX_PYTHON:-python3}" -c "import json,sys; d=json.load(open('$PROJECT/$1')); print(d.get('$2',''))" 2>/dev/null || echo ""; }
count_files() { find "$PROJECT" -name "$1" -not -path "*/node_modules/*" -not -path "*/__pycache__/*" 2>/dev/null | wc -l | tr -d ' '; }

# ── Backend ───────────────────────────────────────────────────
BACKEND="none"
BACKEND_LANG="none"
if has_file "requirements.txt" || has_file "pyproject.toml"; then
  BACKEND_LANG="python"
  grep -qi "fastapi" "$PROJECT/requirements.txt" 2>/dev/null && BACKEND="fastapi"
  grep -qi "django" "$PROJECT/requirements.txt" 2>/dev/null && BACKEND="django"
  grep -qi "flask" "$PROJECT/requirements.txt" 2>/dev/null && BACKEND="flask"
  [[ "$BACKEND" == "none" ]] && BACKEND="python-generic"
fi

# ── Frontend ──────────────────────────────────────────────────
FRONTEND="none"
FRONTEND_LANG="none"
if has_file "package.json"; then
  FRONTEND_LANG="javascript"
  grep -qi '"react"' "$PROJECT/package.json" 2>/dev/null && FRONTEND="react"
  grep -qi '"next"' "$PROJECT/package.json" 2>/dev/null && FRONTEND="nextjs"
  grep -qi '"vue"' "$PROJECT/package.json" 2>/dev/null && FRONTEND="vue"
  grep -qi '"typescript"' "$PROJECT/package.json" 2>/dev/null && FRONTEND_LANG="typescript"
  grep -qi '"vite"' "$PROJECT/package.json" 2>/dev/null && BUNDLER="vite" || BUNDLER="webpack"
fi

# ── Base de datos ─────────────────────────────────────────────
DATABASE="none"
ORM="none"
if grep -qi "postgres\|postgresql" "$PROJECT/requirements.txt" 2>/dev/null; then
  DATABASE="postgresql"
  grep -qi "sqlalchemy" "$PROJECT/requirements.txt" 2>/dev/null && ORM="sqlalchemy"
fi
grep -qi "mysql" "$PROJECT/requirements.txt" 2>/dev/null && DATABASE="mysql"
grep -qi "sqlite" "$PROJECT/requirements.txt" 2>/dev/null && DATABASE="sqlite"
has_file "prisma/schema.prisma" && DATABASE="postgresql" && ORM="prisma"

# ── Infraestructura ───────────────────────────────────────────
INFRA="none"
has_file "compose.yml" || has_file "docker-compose.yml" && INFRA="docker-compose"
has_file "Dockerfile" && INFRA="${INFRA}+dockerfile"

# ── Auth ──────────────────────────────────────────────────────
AUTH="none"
grep -qi "msal\|azure" "$PROJECT/requirements.txt" 2>/dev/null && AUTH="azure-msal"
grep -qi "jwt\|pyjwt" "$PROJECT/requirements.txt" 2>/dev/null && AUTH="${AUTH}+jwt"
grep -qi "bcrypt" "$PROJECT/requirements.txt" 2>/dev/null && AUTH="${AUTH}+bcrypt"
has_file "package.json" && grep -qi "@azure/msal" "$PROJECT/package.json" 2>/dev/null && AUTH="azure-msal-frontend"

# ── Conteos ───────────────────────────────────────────────────
PY_FILES=$(count_files "*.py")
TS_FILES=$(count_files "*.ts")
TSX_FILES=$(count_files "*.tsx")

# ── Servicios Docker ──────────────────────────────────────────
SERVICES="none"
if has_file "compose.yml"; then
  SERVICES=$("${HELIX_PYTHON:-python3}" -c "
import yaml, sys
try:
  with open('$PROJECT/compose.yml') as f:
    d = yaml.safe_load(f)
  print(','.join(d.get('services',{}).keys()))
except: print('parse-error')
" 2>/dev/null || grep "^  [a-z]" "$PROJECT/compose.yml" 2>/dev/null | awk '{print $1}' | tr -d ':' | tr '\n' ',' || echo "unknown")
fi

# ── Output JSON ───────────────────────────────────────────────
"${HELIX_PYTHON:-python3}" - <<PYEOF
import json
print(json.dumps({
  "backend": "$BACKEND",
  "backend_lang": "$BACKEND_LANG",
  "frontend": "$FRONTEND",
  "frontend_lang": "$FRONTEND_LANG",
  "bundler": "${BUNDLER:-none}",
  "database": "$DATABASE",
  "orm": "$ORM",
  "auth": "$AUTH",
  "infra": "$INFRA",
  "docker_services": "$SERVICES",
  "file_counts": {
    "python": int("$PY_FILES" or 0),
    "typescript": int("$TS_FILES" or 0),
    "tsx": int("$TSX_FILES" or 0)
  }
}, indent=2))
PYEOF
