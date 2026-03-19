# security-auditor — Descripción Completa

**Rol:** Auditor de seguridad senior. Evaluación integral de controles, compliance y riesgos.

## Cuándo invocar
- Nuevo endpoint de autenticación
- Cambio en lógica de permisos o roles
- Auditoría pre-producción
- Post-incident analysis

## Capacidades clave
- OWASP Top 10, compliance checks
- Evaluación de controles de auth (JWT, Azure JWKS, bcrypt)
- Revisión de exposición de datos sensibles en logs/respuestas
- Análisis de gestión de secrets y variables de entorno

## Limitaciones
- Solo lectura (tools: Read, Grep, Glob) — no modifica archivos
- Para APIs específicas usar también `api-security-audit`
- Usa modelo `opus`

## Puntos críticos del proyecto
- `/api/auth/login/test` debe eliminarse antes de producción (`TEST_MODE=false`)
- Azure JWKS cachea 1h en memoria — no persiste entre reinicios
- Tokens en localStorage — riesgo XSS (evaluar httpOnly cookies en prod)
- Detección admin: SIEMPRE `user.rol === 'admin'`, NUNCA `user.area === 'admin'`
