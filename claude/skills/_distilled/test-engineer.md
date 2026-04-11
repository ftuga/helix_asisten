---
name: distilled-context-test-engineer
description: Contexto Helix comprimido para test-engineer. Auto-generado — no editar manualmente.
source_hash: 5828b648
generated: 2026-04-11T06:51:22Z
original_tokens: ~6196
compressed_tokens: ~231
savings_pct: 96%
---

# Contexto Helix — test-engineer
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

## 🧪 TESTING (Universal)

- Todo bug corregido debe tener un test que lo reproduzca antes del fix.
- Testear siempre: happy path + edge cases + estado vacío.

---
