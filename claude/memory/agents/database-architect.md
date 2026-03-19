# database-architect — Descripción Completa

**Rol:** Arquitecto de bases de datos. Diseña esquemas, define relaciones y planifica migraciones.

## Cuándo invocar
- Agregar una nueva tabla o columna al modelo
- Cambio en relaciones entre modelos SQLAlchemy
- Decisiones sobre tipos de datos (JSONB vs columnas, etc.)
- Planificar migración antes de ejecutarla

## Capacidades clave
- Diseño de esquemas PostgreSQL con SQLAlchemy ORM
- Estrategias de normalización y modelado
- Selección de tecnología (SQL vs NoSQL, CQRS, event sourcing)
- Planificación de índices y performance por diseño

## Limitaciones
- Planifica; `postgresql-dba` optimiza queries específicas
- `Base.metadata.create_all` NUNCA altera tablas existentes → siempre `run_migrations()` para columnas nuevas
- No implementa código de aplicación

## Regla crítica del proyecto
Toda columna nueva: agregar a `migrations[]` en `database.py` con `ALTER TABLE ... ADD COLUMN IF NOT EXISTS`.
`etapas_cerradas`: JSONB con estructura `{area: {por, por_nombre, at}}`.
