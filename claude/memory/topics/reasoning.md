
## Archivado 2026-03-08 20:53 — Razonamiento
### [2024] Completado requiere doble condición
**Decisión:** `completado` exige `progreso_global == 100` AND cierre de etapa compras (si hay activos).
**Por qué:** Compras solo puede actuar después de que TIC reporte activos. Cerrar compras implica que TIC hizo su parte. Unificar en una sola condición eliminaría la validación cruzada.
**Alternativa descartada:** Solo verificar `progreso_global == 100` — descartada porque compras no tiene tareas asignadas, su progreso siempre sería 0.



## Archivado 2026-03-08 20:53 — Razonamiento
### [2024] Completado requiere doble condición
**Decisión:** `completado` exige `progreso_global == 100` AND cierre de etapa compras (si hay activos).
**Por qué:** Compras solo puede actuar después de que TIC reporte activos. Cerrar compras implica que TIC hizo su parte. Unificar en una sola condición eliminaría la validación cruzada.
**Alternativa descartada:** Solo verificar `progreso_global == 100` — descartada porque compras no tiene tareas asignadas, su progreso siempre sería 0.


