# Skill: fastapi-async
> Versión v2.0 — Patrones genéricos
> **Descripción:** Patrones async/await con SQLAlchemy AsyncSession en FastAPI

## Cuándo usar esta skill
- Toda query a la DB en routers FastAPI
- Cuando necesites cargar relaciones (evitar N+1)
- Cuando trabajes con el resultado de ORM inmediatamente después de modificarlo

## ⚠️ Patrón CRÍTICO: No re-leer ORM tras asignación

```python
# ❌ MAL — SQLAlchemy identity map devuelve valor STALE tras flush
entity.jsonb_field = new_data
await db.flush()
if entity.jsonb_field.get("key"):  # <- puede devolver valor viejo

# ✅ BIEN — Usar variable local, no re-leer del ORM
new_data = {**entity.jsonb_field, "key": value}
entity.jsonb_field = new_data
await db.flush()
if new_data.get("key"):  # <- usar la variable local
    ...
```

## Patrón: Queries con relaciones

```python
# ✅ SIEMPRE selectinload() para relaciones — evita N+1 con AsyncSession
from sqlalchemy.orm import selectinload

result = await db.execute(
    select(Parent)
    .options(selectinload(Parent.children))
    .options(selectinload(Parent.attachments))
    .where(Parent.id == parent_id)
)
entity = result.scalar_one_or_none()
```

## Patrón: Boolean desde raw SQL

```python
# ❌ MAL — raw SQL puede devolver NULL para booleanos
{"active": row.active}

# ✅ BIEN — siempre bool()
{"active": bool(row.active)}
```

## Patrón: Session en Celery vs FastAPI

```python
# FastAPI routers — async
from app.database import AsyncSession
async def my_endpoint(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(MyModel))

# Celery tasks — sync (¡distinto pool de conexiones!)
from app.database import SyncSessionLocal
@celery_app.task
def my_task():
    with SyncSessionLocal() as db:
        items = db.query(MyModel).all()
```

## Historial de cambios
| Versión | Fecha | Cambio |
|---|---|---|
| v2.0 | 2026-03-24 | Generalizado — eliminadas referencias a proyecto específico |
| v1.0 | INIT | Patrones iniciales |
