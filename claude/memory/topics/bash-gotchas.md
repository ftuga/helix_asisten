# Bash Gotchas (Universal)

Patrones que quemaron sesiones previas. Cargar cuando se escriba/revise scripts bash.

## Aritmética con `set -euo pipefail`

- `VAR=$((VAR + 1))` — nunca `((VAR++))` cuando VAR puede ser 0 (sale con exit 1).

## Comparaciones numéricas

- `wc -l` devuelve espacios en algunos shells — limpiar con `tr -d '[:space:]'` antes de comparar.

## git diff filtrado

- `git diff HEAD -- '*.ts' '*.tsx'` para checks de frontend. Sin filtro captura CLAUDE.md y genera falsos positivos.

## Pasar strings a Python desde bash

- Usar variables de entorno (`PYVAR=valor python3 -`), evita todo problema de escaping con `'`, `"`, `$`.

## HELIX-COMPRESS v2 — `helix-distill.sh`

Tres comandos testeados:
1. `run`: slices CLAUDE.md por agente (78-96% ahorro por agente).
2. `compress-project [DIR]`: comprime `helix-*.md` del proyecto con backup.
3. `compress-file FILE [task]`: extrae bloques relevantes de código (`.py`/`.ts`/`.js` por función, `.md` por sección, otros por keywords ±10 líneas).

Fixes aplicados: HTML comment stripping, doble-run Python eliminado, `--keep` arg parsing, pipe-vs-heredoc stdin bug.
