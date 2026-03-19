# Skill: celery-redis
> Auto-generada · Versión v1.0
> **Descripción:** Configuración y patrones Celery + Redis para SerSocial IPS

## Cuándo usar esta skill
- Al agregar nuevas tasks asíncronas (emails, sync, reportes)
- Al depurar workers o tareas que no se ejecutan
- Al escalar workers

## ⚠️ Regla Fundamental: Sync vs Async

```python
# FastAPI routers → AsyncSession (async/await)
# Celery tasks   → SyncSessionLocal (sync) — SON DISTINTAS

# ✅ En tasks.py
from app.database import SyncSessionLocal

@celery_app.task
def send_inicio_retiro(retiro_id: str):
    with SyncSessionLocal() as db:
        retiro = db.query(Retiro).filter(Retiro.id == retiro_id).first()
        # ... lógica sync
```

## Tasks On-Demand vs Scheduled

```python
# On-demand (desde router)
send_inicio_retiro.delay(str(retiro.id))

# Scheduled (en celery_app.py)
app.conf.beat_schedule = {
    'check-vencimientos': {
        'task': 'app.tasks.check_vencimientos',
        'schedule': crontab(hour='*/1'),  # cada hora
    },
    'sync-status': {
        'task': 'app.tasks.sync_status_retiros',
        'schedule': crontab(hour='*/1'),
    },
}
```

## SMTP Silencioso (comportamiento esperado)

```python
# Si smtp_host o smtp_user están vacíos → log y no falla
# Útil para desarrollo sin SMTP configurado
if not settings.smtp_host or not settings.smtp_user:
    logger.info(f"SMTP no configurado — email omitido: {subject}")
    return
```

## Comandos de Diagnóstico

```bash
# Ver logs del worker en tiempo real
docker compose logs -f celery_worker

# Ver logs del scheduler
docker compose logs -f celery_beat

# Escalar workers
docker compose up -d --scale celery_worker=3

# Ejecutar task manualmente (en shell de Python dentro del container)
docker compose exec backend python -c "
from app.tasks import check_vencimientos
check_vencimientos.delay()
"
```

## Dependencias
- `docker-compose`

## Historial de cambios
| Versión | Fecha | Cambio |
|---|---|---|
| v1.0 | INIT | Patrones sync/async y comandos de diagnóstico |
