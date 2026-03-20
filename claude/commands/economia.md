# /economia — Modo Economía de Helix

Activa restricciones estrictas de uso de tokens Y realiza limpieza de contexto
para dejar la sesión lo más liviana posible antes de trabajar.

---

## Al ejecutar `/economia` (o `/economia on`)

### Paso 1 — Limpieza inmediata de contexto

```bash
wc -l ~/.claude/CLAUDE.md
```

- Si CLAUDE.md >180 líneas → `bash ~/.claude/compress.sh` antes de continuar
- No cargar archivos de memoria adicionales en esta sesión
- Si helix-analysis.md existe → solo leer el resumen ejecutivo (≤150 palabras),
  ignorar helix-analysis-full.md

### Paso 2 — Activar restricciones

Confirmar al usuario con lista compacta:

```
💰 Modo economía activado
✅ Sin subagentes (solo si ≥3 dominios + coordinación activa)
✅ Sin swarm / Capa 2
✅ Respuestas en bullets — sin prosa explicativa
✅ Grep antes que Read — Read con limit/offset siempre
✅ Sin sugerencias proactivas fuera del scope
✅ Capa 0 (Ollama) agresiva para logs/texto/CRUDs
✅ CLAUDE.md comprimido: {antes} → {después} líneas
```

### Paso 3 — Persistir para próximas sesiones

```bash
mkdir -p {PROJECT_ROOT}/.claude/memory
touch {PROJECT_ROOT}/.claude/memory/.helix-economia
```

session-start detecta `.helix-economia` y activa el modo automáticamente.

---

## Al ejecutar `/economia off`

```bash
rm -f {PROJECT_ROOT}/.claude/memory/.helix-economia
```

Confirmar: "Modo economía desactivado. Comportamiento normal restaurado."

---

## Al ejecutar `/economia?`

Reportar estado actual:
- ¿Está `.helix-economia` activo?
- ¿Cuántas líneas tiene CLAUDE.md ahora?
- ¿Cuánto contexto se ha usado en esta sesión (aproximado)?
- Recordar: "Ejecutá `/helix-actualiza` para mantenimiento completo."

---

## Al detectar `[HELIX-ECONOMIA-ACTIVO]` en session-start

Aplicar todas las restricciones automáticamente desde el primer mensaje.
Comprimir CLAUDE.md si supera 180 líneas antes de comenzar la sesión.
