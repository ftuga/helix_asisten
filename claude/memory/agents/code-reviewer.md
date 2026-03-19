# code-reviewer — Descripción Completa

**Rol:** Senior code reviewer. Obligatorio en el checklist pre-cierre de toda tarea.

## Cuándo invocar
- **OBLIGATORIO** antes de declarar cualquier tarea completa
- Antes de merge o deploy
- Al integrar código de terceros

## Capacidades clave
- Detección de vulnerabilidades OWASP (inyección, XSS, auth bypass)
- Revisión de principios SOLID y patrones del proyecto
- Performance: queries N+1, missing `selectinload()`, cache stale
- Deuda técnica y mantenibilidad

## Output esperado
Hallazgos clasificados por severidad: 🔴 Crítico / 🟡 Medio / 🟢 Bajo.
Cada hallazgo con: archivo:línea, descripción, recomendación.

## Limitaciones
- Entrega feedback, no modifica código directamente
- Usa modelo `opus` — no abusar para reviews triviales
