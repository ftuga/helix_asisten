---
name: distilled-context-python-pro
description: Contexto Helix comprimido para python-pro. Auto-generado — no editar manualmente.
source_hash: 5828b648
generated: 2026-04-11T06:51:21Z
original_tokens: ~6196
compressed_tokens: ~354
savings_pct: 94%
---

# Contexto Helix — python-pro
> Secciones relevantes para este agente. Generado por helix-distill.


# CLAUDE.md — Helix · Agente Auto-Evolutivo (Global)
> Reglas universales que aplican a TODOS los proyectos.
> El CLAUDE.md de cada proyecto hereda estas reglas y agrega las específicas.
> Última evolución: 2026-04-11 01:29

---


## 🔐 SEGURIDAD (Universal)

- Nunca exponer variables de entorno en logs ni en respuestas al usuario.
- `.env` siempre en `.gitignore`. Usar `.env.example` con valores placeholder.
- Nunca hardcodear credenciales, URLs internas ni secrets en el código fuente.
- Endpoints de test/debug DEBEN eliminarse antes de producción — usar feature flags.
- Confirmar acciones destructivas antes de ejecutarlas.


---

## 📝 COMMITS (Universal)

- **NO incluir** `Co-Authored-By` en ningún commit. Omitir siempre esa línea del mensaje.

---

## 🔧 BASH GOTCHAS (Universal)

- `VAR=$((VAR + 1))` — nunca `((VAR++))` con `set -euo pipefail` cuando VAR puede ser 0.
- `wc -l` devuelve espacios — limpiar con `tr -d '[:space:]'` antes de comparar numéricamente.
- `git diff HEAD -- '*.ts' '*.tsx'` para checks de frontend — sin filtro captura CLAUDE.md y genera falsos positivos.
- Para pasar strings con caracteres especiales a Python desde bash: usar variables de entorno (`PYVAR=valor python3 -`), evita todo problema de escaping.


---

## 🧪 TESTING (Universal)

- Todo bug corregido debe tener un test que lo reproduzca antes del fix.
- Testear siempre: happy path + edge cases + estado vacío.

---
