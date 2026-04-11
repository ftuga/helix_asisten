# Skill: docker-compose
> Auto-generada · Versión v1.0
> **Descripción:** Comandos frecuentes Docker Compose

## Comandos Esenciales

```bash
# ── Inicio y Rebuild ──────────────────────────────────────
docker compose up -d --build           # Todo desde cero
docker compose up -d --build backend   # Solo backend (más rápido)
docker compose up -d --build frontend  # Necesario si cambian VITE_*

# ── Código Python (sin rebuild) ───────────────────────────
docker compose restart backend         # Aplica cambios — bind-mount activo

# ── Logs ─────────────────────────────────────────────────
docker compose logs -f backend
docker compose logs -f celery_worker celery_beat
docker compose logs -f --tail=50 backend  # últimas 50 líneas

# ── Base de datos ─────────────────────────────────────────
PG_USER=$(grep POSTGRES_USER .env | cut -d'=' -f2)
PG_DB=$(grep POSTGRES_DB .env | cut -d'=' -f2)
docker compose exec postgres psql -U "$PG_USER" -d "$PG_DB"

# Backup
docker compose exec postgres pg_dump -U "$PG_USER" "$PG_DB" > backup_$(date +%Y%m%d).sql

# ── Escalar ───────────────────────────────────────────────
docker compose up -d --scale celery_worker=3

# ── Estado ───────────────────────────────────────────────
docker compose ps                      # Estado de todos los servicios
docker compose top                     # Procesos corriendo
```

## ⚠️ Reglas Críticas

```bash
# Variables VITE_* se hornean al buildear la imagen
# Cambiarlas REQUIERE rebuild del frontend
docker compose up -d --build frontend

# NUNCA hardcodear '‹entidad›' — leer del .env
PG_USER=$(grep POSTGRES_USER .env | cut -d'=' -f2)
```

## Puertos Internos

| Servicio | Puerto | Acceso externo |
|---|---|---|
| Backend FastAPI | 8000 | ❌ Solo via Nginx |
| Frontend Nginx | 80/443 | ✅ |
| PostgreSQL | 5432 | ❌ |
| Redis | 6379 | ❌ |
| MinIO API | 9000 | ❌ |
| MinIO Console | 9001 | ⚠️ Solo dev |

## Producción — Cambios Pendientes en compose.yml

```yaml
# Descomentar:
healthcheck: ...          # Para todos los servicios
ports: ["443:443"]        # nginx
volumes: certbot...       # SSL

# Agregar:
networks:
  internal:
    internal: true        # Sin acceso externo

# Eliminar:
ports: ["9001:9001"]      # MinIO console
```

## Dependencias
- Ninguna (skill base)

## Historial de cambios
| Versión | Fecha | Cambio |
|---|---|---|
| v1.0 | INIT | Comandos esenciales y notas de producción |
