# postgresql-dba — Descripción Completa

**Rol:** DBA PostgreSQL. Optimización de DB, análisis de performance y administración.

## Cuándo invocar
- Después de `database-architect` para optimizar el esquema diseñado
- Análisis de índices existentes (unused, bloated)
- Configuración de PostgreSQL (shared_buffers, work_mem, etc.)
- Vacuum, reindex, estadísticas de tablas

## Capacidades clave
- `pg_stat_statements`, `pg_stat_user_indexes`, `pg_stat_activity`
- EXPLAIN ANALYZE avanzado
- Configuración de autovacuum y mantenimiento
- Read replicas, connection pooling (PgBouncer)

## Limitaciones
- Requiere extensión VS Code `ms-ossdata.vscode-pgsql` para algunas features
- En Claude Code CLI: usar herramientas de Bash + psql directamente
- Para queries complejas específicas usar `sql-pro`
