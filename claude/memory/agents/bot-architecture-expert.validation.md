# Validación — bot-architecture-expert
> Fecha: 2026-06-26 | Umbral activación: ≥80% (≥7/8)

## Q1. Llega un requerimiento: "agregar recordatorios de cita". ¿Dónde lo pones y por qué?
**Esperado (OCP/SRP):** subflujo nuevo `WF_RECORDATORIOS` + una rama/disparador en el orquestador/router; NO editar `WF_CITA` ni inflar `CHATBOT WHATSAPP`. Razón: abierto a extensión, cerrado a modificación; responsabilidad única.
**Agente:** Correcta. ✅

## Q2. `CHATBOT WHATSAPP` tiene 135 nodos. ¿Es un problema? ¿Qué haces?
**Esperado:** Es un smell de monolito. El orquestador debe enrutar, no hacer. Extraer lógica de tarea a subflujos cohesivos, dejar el orquestador delgado (clasificar intención + despachar). Separation of concerns.
**Agente:** Correcta. ✅

## Q3. El usuario está agendando y a mitad pregunta "¿esa sede tiene parqueadero?". ¿Cómo lo maneja la arquitectura?
**Esperado (digresión + resume):** detectar que es una digresión (re-clasificar intención en el turno), pausar la tarea activa en la pila, atender la pregunta, y retomar exactamente donde estaba (patrón Call→return). Estado: tarea activa + paso + slots conservados.
**Agente:** Correcta. ✅

## Q4. El usuario ya dio la fecha y dice "no, mejor el jueves". ¿Cómo evitas reiniciar el flujo?
**Esperado (reparación por slot):** puntos de entrada por slot; editar solo el slot `fecha` sin re-pedir documento/especialidad; confirmar el cambio. Slot-filling independiente del orden.
**Agente:** Correcta. ✅

## Q5. ¿Por qué un wizard rígido paso-1-paso-2 es mala arquitectura conversacional?
**Esperado:** Las conversaciones son no-lineales (iniciativa mixta); el usuario llena slots en distinto orden, interrumpe, corrige. Frame-based slot-filling y diseño de unhappy paths lo manejan; el wizard rígido rompe ante cualquier desvío.
**Agente:** Correcta. ✅

## Q6. Para elegir especialidad (12 opciones) y luego confirmar (sí/no), ¿qué componentes de Meta usas?
**Esperado:** 12 > 10 → no cabe en una List simple (máx 10); usar List con secciones o un Flow con Dropdown si excede; confirmación sí/no → Reply Buttons (máx 3). Selección > texto libre para slots limpios.
**Agente:** Correcta — nota el límite de 10 de List y propone Flow/secciones; botones para confirmar. ✅

## Q7. ¿Cuándo un WhatsApp Flow en vez de List o botones?
**Esperado:** Cuando hay varios campos juntos o un flujo guiado multi-pantalla (registro, agendar con fecha): Flows soporta Text Input, Dropdown, Checkbox, Radio, Date Picker, Opt-in y data exchange con backend. Botón/List son para una sola decisión.
**Agente:** Correcta. ✅

## Q8. ¿Qué NO es tu trabajo y a quién haces handoff?
**Esperado:** No implementas nodos/JSON (→ n8n-workflow-expert) ni redactas el copy/tono (→ conversational-comms-expert). Entregas mapa, contratos, modelo de estado y recomendación de componentes.
**Agente:** Correcta. ✅

---
## Resultado
- Correctas: **8/8 = 100%** → **≥80% → ACTIVAR** ✅
- Sin contenido de cuarentena (6 fuentes canónicas en 3 pilares, limpias).
