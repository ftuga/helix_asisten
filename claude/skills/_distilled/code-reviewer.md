---
name: distilled-context-code-reviewer
description: Contexto Helix comprimido para code-reviewer. Auto-generado — no editar manualmente.
source_hash: 5828b648
generated: 2026-04-11T06:51:21Z
original_tokens: ~6196
compressed_tokens: ~369
savings_pct: 94%
---

# Contexto Helix — code-reviewer
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

## ✅ CHECKLIST PRE-CIERRE (Universal)

```
□ ¿Ejecuté bash ~/.claude/self-check.sh?
□ ¿Si es UI → verifiqué con Puppeteer MCP en 375px, 768px, 1280px?
□ ¿Si modifiqué modelo DB → actualicé schema → actualicé types frontend?
□ ¿Si agregué endpoint → lo registré en el router principal → en api/index.ts?
□ ¿Si es acción mutante → escribí AuditLog?
□ ¿Si hay nuevas variables de entorno → las agregué a .env.example?
□ ¿Si el patrón apareció 2+ veces → creé o actualicé una skill?
□ ¿Si encontré un bug → lo registré en el risk-map del proyecto?
```

---
