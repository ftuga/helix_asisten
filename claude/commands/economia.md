# /economia — Activar Modo Economía de Helix

Activa restricciones estrictas de uso de tokens para esta sesión.
Útil cuando el presupuesto de tokens es limitado o querés conservar cuota.

## Al ejecutar este comando

1. Confirmar al usuario: "Modo economía activado. Restricciones activas:"

```
✅ Sin subagentes (solo si ≥3 dominios + coordinación activa)
✅ Sin swarm/Capa 2
✅ Respuestas en bullets — sin explicaciones extendidas
✅ Grep antes que Read — Read con limit/offset siempre
✅ Sin sugerencias proactivas fuera del scope
✅ Capa 0 (Ollama) agresiva — escalar solo si insuficiente
```

2. Si el proyecto tiene `.claude/memory/`:
   ```bash
   touch {PROJECT_ROOT}/.claude/memory/.helix-economia
   ```
   Así session-start detecta el modo en próximas sesiones.

3. Para desactivar: `/economia off` o borrar `.helix-economia`

## Al detectar `.helix-economia` en session-start

Agregar al output: `[HELIX-ECONOMIA-ACTIVO] Modo economía persistente detectado.`
Helix aplica todas las restricciones automáticamente.

## Variantes

- `/economia on`  — activar (default)
- `/economia off` — desactivar y borrar `.helix-economia`
- `/economia?`    — mostrar si está activo y qué restricciones aplican
