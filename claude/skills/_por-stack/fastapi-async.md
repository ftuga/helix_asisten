# Skill: fastapi-async
> Auto-generada · Versión v1.0
> **Descripción:** Patrones async/await con SQLAlchemy AsyncSession en FastAPI — específico

## Cuándo usar esta skill
- Toda query a la DB en routers FastAPI
- Cuando necesites cargar relaciones (evitar N+1)
- Cuando trabajes con el resultado de ORM inmediatamente después de modificarlo

## ⚠️ Patrón CRÍTICO: No re-leer ORM tras asignación

```python
# ❌ MAL — SQLAlchemy identity map devuelve valor STALE
retiro.etapas_cerradas = nueva_data
await db.flush()
if retiro.etapas_cerradas.get("compras"):  # <- puede devolver valor viejo
    ...

# ✅ BIEN — Usar variable local, no re-leer del ORM
nueva_data = {**retiro.etapas_cerradas, "compras": {...}}
retiro.etapas_cerradas = nueva_data
await db.flush()
if nueva_data.get("compras"):  # <- usar la variable local
    ...
```

## Patrón: Queries con relaciones

```python
# ✅ SIEMPRE selectinload() para relaciones — evita N+1 con AsyncSession
from sqlalchemy.orm import selectinload

result = await db.execute(
    select(Retiro)
    .options(selectinload(Retiro.tareas))
    .options(selectinload(Retiro.adjuntos))
    .where(Retiro.id == retiro_id)
)
retiro = result.scalar_one_or_none()
```

## Patrón: Boolean desde raw SQL

```python
# ❌ MAL — raw SQL puede devolver NULL para booleanos
{"completada": tarea.completada}

# ✅ BIEN — siempre bool()
{"completada": bool(tarea.completada)}
```

## Patrón: Session en Celery vs FastAPI

```python
# FastAPI routers — async
from app.database import AsyncSession
async def mi_endpoint(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Retiro))

# Celery tasks — sync (distinto!)
from app.database import SyncSessionLocal
@celery_app.task
def mi_tarea():
    with SyncSessionLocal() as db:
        retiros = db.query(Retiro).all()
```

## Dependencias
- `docker-compose` (para correr el entorno)

## Historial de cambios
| Versión | Fecha | Cambio |
|---|---|---|
| v1.0 | INIT | Creación con patrones críticos del proyecto |
