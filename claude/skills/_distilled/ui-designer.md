---
name: distilled-context-ui-designer
description: Contexto Helix comprimido para ui-designer. Auto-generado — no editar manualmente.
source_hash: 5828b648
generated: 2026-04-11T06:51:22Z
original_tokens: ~6196
compressed_tokens: ~316
savings_pct: 94%
---

# Contexto Helix — ui-designer
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

## 🎨 DISEÑO UI (Universal)

> Sistema de diseño completo en `~/.claude/memory/design-system.md`
> Cargar cuando se trabaje en componentes frontend o páginas.

**Reglas mínimas siempre activas:**
- Mobile-first siempre — nunca diseñar solo para desktop y adaptar después.
- Touch targets mínimo 44×44px. Inputs font-size ≥ 16px en móvil (evita zoom iOS).
- Nunca información accesible solo por hover — en móvil no existe.
- Usar Puppeteer MCP para verificar visualmente antes de entregar cualquier UI.

---
