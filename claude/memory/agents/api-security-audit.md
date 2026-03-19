# api-security-audit — Descripción Completa

**Rol:** Especialista en seguridad de APIs REST. OWASP API Top 10, JWT, RBAC, inyecciones.

## Cuándo invocar
- Agregar cualquier endpoint nuevo
- Cambio en lógica de autenticación o autorización
- Sospecha de vulnerability en un endpoint existente

## Capacidades clave
- OWASP API Top 10: auth flaws, excessive data exposure, lack of rate limiting
- JWT vulnerabilities: alg confusion, expiry bypass, token leakage
- SQL/NoSQL/command injection en parámetros de API
- RBAC: privilege escalation, missing ownership checks

## Limitaciones
- Se enfoca en la capa API; para infra completa usar `security-auditor`
- Puede modificar código para aplicar fixes (tools: Read, Write, Edit, Bash)

## Contexto del proyecto
Auth: `Bearer {jwt_propio}` en headers. Roles: `admin` | área específica.
Todos los endpoints protegidos excepto `/api/auth/login` y `/api/auth/login/test`.
