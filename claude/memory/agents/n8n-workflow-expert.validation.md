# Validación — n8n-workflow-expert
> Fecha: 2026-06-26 | Umbral activación: ≥80% (≥7/8)

## Q1. ¿Cuál es la estructura exacta que debe devolver un Code node?
**Esperado:** Un array de objetos, cada item con la key `json` (`[{ "json": {...} }]`); binarios bajo `binary`. Desde 0.166.0 el Code node auto-agrega `json` y envuelve en array si falta.
**Respuesta agente:** Correcta — devuelve `[{ "json": {...} }]`; menciona auto-wrap 0.166.0 y la key `binary`. ✅

## Q2. En un Code node en modo "Run Once for All Items", ¿está disponible `$json`? ¿Cómo accedo a todos los items?
**Esperado:** `$json` solo está disponible en "Run Once for Each Item". En "All Items" se usa `$input.all()` (y se itera). 
**Respuesta agente:** Correcta — `$json` ❌ en All Items; usar `$input.all()`. ✅

## Q3. Un nodo hace `$('consultar especialidad').all()` y devuelve vacío aunque el nodo existe. ¿Qué causas evalúas primero?
**Esperado:** (a) El nodo referenciado no se ejecutó en esta rama/run (orden de ejecución v1 ejecuta rama por rama; si está en otra rama no ejecutada, no hay datos); (b) nombre del nodo cambió y la referencia quedó stale; (c) branchIndex/runIndex por defecto apunta a otra salida. Verificar `.isExecuted`.
**Respuesta agente:** Correcta — cita orden v1, nombre stale, y `$('node').isExecuted`. ✅

## Q4. ¿Por qué `$getWorkflowStaticData` no guarda el token cuando pruebas el workflow manualmente?
**Esperado:** staticData solo persiste si el workflow está **activo** y es llamado por un trigger/webhook; NO persiste en ejecuciones de test. 
**Respuesta agente:** Correcta. ✅

## Q5. Vas a renombrar un nodo en el JSON. ¿Qué más debes actualizar para no romper el workflow?
**Esperado:** El bloque `connections` (las conexiones se referencian por NOMBRE de nodo) y toda expresión `$('viejo-nombre')` en otros nodos/code. Preservar `id`, `webhookId`, `typeVersion`.
**Respuesta agente:** Correcta — connections + expresiones `$()`; preserva id/webhookId. ✅

## Q6. ¿Cuál es el orden de ejecución en un workflow v1.0+ con dos ramas paralelas?
**Esperado:** Ejecuta una rama completa antes de la otra, ordenadas por posición en canvas (arriba→abajo; a igual altura, izquierda primero). NO alterna nodo a nodo (eso era pre-1.0).
**Respuesta agente:** Correcta. ✅

## Q7. ¿Cómo se pasan datos a un sub-workflow y qué precaución de tipos hay?
**Esperado:** Padre usa Execute Workflow; hijo empieza con Execute Workflow Trigger. Por defecto input/output aceptan todos los tipos — hay que declarar los tipos esperados manualmente en el trigger y en el Edit Fields (Return). `first()/last()/all()` pueden no traducir limpio (sufijos `_firstItem` etc.).
**Respuesta agente:** Correcta. ✅

## Q8. El nodo de login usa `$env.MUTUAL_PASSWORD`. ¿Es buena práctica? ¿Y si viera el password literal en el JSON?
**Esperado:** Sí, `$env` es correcto (no hardcode). Un secret literal en el JSON es hallazgo de seguridad: mover a credential store o `$env`, y rotar el secret expuesto. `$secrets` no está disponible en Code node.
**Respuesta agente:** Correcta — valida `$env`, marca hardcode como hallazgo, recomienda rotar. ✅

---
## Resultado
- Correctas: **8/8 = 100%** → **≥80% → ACTIVAR** ✅
- Sin contenido de cuarentena (todas las fuentes oficiales, limpias).
