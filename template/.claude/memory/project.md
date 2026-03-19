# Documentación del Proyecto — [NOMBRE]
> Completar al inicio del proyecto. Cargar bajo demanda cuando se necesite referencia.

## Overview

**[Nombre del proyecto]** — [Descripción breve en 1-2 líneas]

## Stack

| Servicio | Tecnología |
|---|---|
| Backend API | [FastAPI / Django / Express / ...] |
| Base de datos | [PostgreSQL / MySQL / MongoDB / ...] |
| Frontend | [React + Vite / Next.js / Vue / ...] |
| Autenticación | [Azure AD / Auth0 / JWT propio / ...] |
| Infraestructura | [Docker Compose / K8s / ...] |

## Commands

```bash
# Agregar comandos frecuentes del proyecto
```

## Environment Variables

| Variable | Descripción |
|---|---|
| `DATABASE_URL` | Conexión a la base de datos |
| `SECRET_KEY` | Clave para firmar JWTs |

## Roles y Permisos

> Describir el modelo de roles del proyecto.

## Common Task Patterns

### Nuevo endpoint
1. Definir schema/DTO
2. Implementar en router/controller
3. Registrar en router principal
4. Agregar método en cliente API frontend
5. Agregar type en types.ts

### Nueva página frontend
1. Crear componente en pages/
2. Agregar route con protección adecuada
3. Agregar link en navegación

## Test Users (solo local)

| Email | Rol |
|---|---|
| `admin@test.com` | admin |

## Production Readiness Checklist
- [ ] Eliminar endpoints de test/debug
- [ ] Configurar variables de entorno de producción
- [ ] Verificar HTTPS y certificados SSL
- [ ] Revisar permisos de red (no exponer servicios internos)

## Mapa del Código

> Completar al explorar el proyecto.

### Backend
| Archivo | Responsabilidad | Fragilidad |
|---|---|---|
| — | — | — |

### Frontend
| Archivo | Responsabilidad | Fragilidad |
|---|---|---|
| — | — | — |
