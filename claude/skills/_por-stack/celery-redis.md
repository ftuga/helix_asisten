# Skill: celery-redis
> Versión v2.0 — Patrones genéricos
> **Descripción:** Configuración y patrones Celery + Redis con FastAPI

## Cuándo usar esta skill
- Al agregar nuevas tasks asíncronas (emails, sync, reportes, procesamiento batch)
- Al depurar workers o tareas que no se ejecutan
- Al escalar workers

## ⚠️ Regla Fundamental: Sync vs Async

```python
# FastAPI routers → AsyncSession (async/await)
# Celery tasks   → SyncSessionLocal (sync) — SON DISTINTAS SESIONES

# ✅ En tasks.py
from app.database import SyncSessionLocal

@celery_app.task
def process_item(item_id: str):
    with SyncSessionLocal() as db:
        item = db.query(MyModel).filter(MyModel.id == item_id).first()
        # ... lógica sync
```

## Tasks On-Demand vs Scheduled

```python
# On-demand (desde router)
process_item.delay(str(item.id))

# Scheduled (en celery_app.py)
app.conf.beat_schedule = {
    'check-expirations': {
        'task': 'app.tasks.check_expirations',
        'schedule': crontab(hour='*/1'),
    },
    'sync-status': {
        'task': 'app.tasks.sync_status',
        'schedule': crontab(hour='*/1'),
    },
}
```

## SMTP Silencioso (comportamiento esperado)

```python
# Si smtp_host o smtp_user están vacíos → log y no falla
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

# Ejecutar task manualmente
docker compose exec backend python -c "
from app.tasks import my_task
my_task.delay()
"
```

## Historial de cambios
| Versión | Fecha | Cambio |
|---|---|---|
| v2.0 | 2026-03-24 | Generalizado — eliminadas referencias a proyecto específico |
| v1.0 | INIT | Patrones iniciales |
