# python-pro — Descripción Completa

**Rol:** Senior Python developer especializado en código production-ready con FastAPI, SQLAlchemy async y Pydantic.

## Cuándo invocar
- Nuevo endpoint FastAPI (después de que `backend-architect` planificó)
- Refactor de routers o modelos existentes
- Optimización de queries async con `selectinload()`
- Implementación de tasks Celery (`SyncSessionLocal`, no async)
- Corrección de bugs en el backend Python

## Capacidades clave
- FastAPI + SQLAlchemy AsyncSession + Pydantic v2
- Type hints completos, async/await, context managers
- Patrones de este proyecto: UUIDs, `AuditLog`, `run_migrations()`
- Bool columns de raw SQL: siempre `bool(valor)` antes de Pydantic

## Limitaciones
- No diseña arquitectura (eso es `backend-architect`)
- No optimiza queries SQL avanzadas (eso es `sql-pro`)
- No toca código frontend

## Contexto del proyecto
Routers: `auth`, `users`, `retiros`, `tareas`, `activos`, `adjuntos`, `reportes`, `colaboradores`, `config`, `paz_y_salvo`.
Modelos críticos: `Retiro`, `Tarea`, `Activo`, `Adjunto`, `AuditLog`.
Zona de riesgo: `routers/retiros.py::_check_all_closed` (SQLAlchemy identity map stale).
