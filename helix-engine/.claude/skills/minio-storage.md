# Skill: minio-storage
> Auto-generada · Versión v1.0
> **Descripción:** Upload/download/presigned URLs con MinIO para adjuntos y cotizaciones

## Cuándo usar esta skill
- Al subir archivos (adjuntos generales, cotizaciones de compras)
- Al generar links de descarga/preview
- Al depurar el problema de iframes negros

## Convención de Nombres

```python
# Adjuntos generales
key = f"retiros/{retiro_id}/{filename}"

# Cotizaciones de compras (filtro frontend por prefijo)
key = f"retiros/{retiro_id}/COT-{activo_id[:8]}-{filename}"
# área siempre = "compras"
```

## Upload y Presigned URL

```python
from app.storage import upload_file, get_presigned_url, delete_file

# Upload
key = upload_file(
    f"retiros/{retiro_id}/{filename}",
    file_bytes,
    content_type  # "image/png", "application/pdf", etc.
)

# URL temporal (para preview/download)
url = get_presigned_url(key, expires_seconds=3600)
```

## ⚠️ Problema: iframes negros con MinIO

```typescript
// ❌ MAL — iframes con presigned URLs de MinIO = pantalla negra (CORS/CSP)
<iframe src={adjunto.download_url} />

// ✅ BIEN — Según tipo de archivo:
if (adjunto.nombre.match(/\.(jpg|jpeg|png|gif|webp)$/i)) {
  // Imágenes → modal con <img>
  return <img src={adjunto.download_url} />;
} else if (adjunto.nombre.endsWith('.pdf')) {
  // PDFs → nueva pestaña
  window.open(adjunto.download_url, '_blank');
}
```

## Filtro de Cotizaciones en Frontend

```typescript
// Cotizaciones de un activo específico
const cotizaciones = retiro.adjuntos.filter(adj =>
  adj.area === 'compras' &&
  adj.nombre.startsWith(`COT-${activoId.slice(0, 8)}-`)
);

// En sección adjuntos — mostrar nombre limpio
const displayName = adj.nombre.startsWith('COT-')
  ? `Cotización: ${adj.nombre.split('-').slice(2).join('-')}`
  : adj.nombre;
```

## enrich_retiro — Download URLs

```python
# download_url se genera en enrich_retiro, no en el modelo
# Siempre pasarlo por enrich_retiro antes de devolver al frontend
def enrich_retiro(retiro, db):
    for adj in retiro.adjuntos:
        adj.download_url = get_presigned_url(adj.key, expires_seconds=3600)
    return retiro
```

## Dependencias
- `docker-compose`

## Historial de cambios
| Versión | Fecha | Cambio |
|---|---|---|
| v1.0 | INIT | Patrones de upload, presigned URLs y fix de iframes |
