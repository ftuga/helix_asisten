# M3 — Rúbrica de Claridad para Pilot HELIX-LANG v3

> **Status:** TEMPLATE — el creator debe completar los ejemplos PASS/FAIL antes de iniciar el piloto.
> **Origen:** Helix Council session `20260507T215307Z-109qf`, precondition P1 (blocking) + DA6 mitigación devil's advocate.
> **Hard constraint:** este archivo DEBE existir y tener al menos 3 PASS + 3 FAIL completados antes de que `helix-council.sh finalize` con `HELIX_M3_GATE=1` permita registrar PASS.

---

## Definición operativa de M3

> Cita literal del creator (`~/.helix/CLAUDE.md` §IDIOMA Y TONO + decisión P2 sesión 20260507):
> *"ahorre pero no pierda contexto. De nada me sirve ahorrar el 100% si no soluciona, para eso no uso Claude."*

**M3 PASS:** el creator lee el `user_facing_summary` del council finalize y entiende decisión + razonamiento + riesgos sin necesitar:
- Re-leer el summary completo más de **1 vez**, O
- Hacer más de **2 lookups** al vocabulario declarado (`S:vocab`) para descifrar handoffs, O
- Más de **2 iteraciones de debug** ("¿qué quiso decir el agente X aquí?") durante la lectura.

**M3 FAIL:** cualquiera de las condiciones de PASS se viola.

**Idioma del summary:** mirror del último turno del creator. Fallback español neutro colombiano si ambiguo.
**Cobertura:** el summary debe incluir decisión + razón + riesgos + acción recomendada (mismo contrato que `~/.helix/council/inter-agent-language.md` §audit_log.user_facing_summary).

---

## Ejemplos pre-registrados

> **INSTRUCCIONES PARA EL CREATOR:** llená cada ejemplo abajo ANTES del piloto. No usar el output del piloto mismo para llenar (eso sería contaminar la rúbrica con lo que querés validar). Usar councils históricos, deliberaciones anteriores, o ejemplos hipotéticos.

### PASS-1 (ES) — completar
```
Idioma del summary: ES
Decisión hipotética: <pegar aquí un summary que vos considerás claro>
Por qué pasa: <explicar qué hace que sea entendible — claridad de decisión, riesgos visibles, etc.>
```

### PASS-2 (ES) — completar
```
Idioma del summary: ES
Decisión hipotética: <pegar otro summary claro>
Por qué pasa: <explicación>
```

### PASS-3 (EN) — completar
```
Summary language: EN
Hypothetical decision: <paste a summary you consider clear>
Why it passes: <explanation>
```

### PASS-4 (opcional, EN o ES) — completar si querés mayor robustez

---

### FAIL-1 (ES) — completar
```
Idioma del summary: ES
Decisión hipotética: <pegar un summary que NO entendés sin esfuerzo>
Por qué falla: <qué le falta — referencias rotas, jerga sin definir, decisión ambigua, etc.>
```

### FAIL-2 (ES) — completar
```
Idioma del summary: ES
Decisión hipotética: <otro summary que falla>
Por qué falla: <explicación>
```

### FAIL-3 (EN) — completar
```
Summary language: EN
Hypothetical decision: <paste a summary that fails>
Why it fails: <explanation>
```

### FAIL-4 (opcional)

---

## Cómo se aplica esta rúbrica en el piloto

1. Council A (meta-circular, ES) corre con HELIX-LANG v3 activo.
2. Synthesizer/Arbiter producen `user_facing_summary`.
3. Creator ejecuta `HELIX_M3_GATE=1 helix-council.sh finalize <session_id>`.
4. El script imprime el summary y solicita al creator: tipear `PASS` o `FAIL`.
5. Si es FAIL: el creator pega cuál de los criterios FAIL aplicó (ej: "como FAIL-2: jerga sin definir").
6. Si es PASS: el creator declara cuál PASS le sirvió de referencia (ej: "como PASS-1").
7. Resultado se registra inmutable en el audit log junto con la cita del ejemplo de referencia.

---

## Reglas duras

- Esta rúbrica se firma una sola vez. Si durante el piloto el creator quiere agregar un nuevo ejemplo, debe hacerlo en archivo separado (`m3-rubric-amendments.md`) y NO altera la rúbrica original.
- Si el piloto FAIL: la rúbrica queda intacta. El piloto se aborta. No se ajusta la rúbrica para que el piloto pase — eso sería invalidar la pre-registración.
- Si el piloto PASS pero con uso heavy de ejemplos como referencia (>2 invocaciones), flag amber: el spec posiblemente no es claro by-design.

---

## Audit y reversibilidad

- Archivo se versiona en git (`~/.helix/skills/helix-lang/m3-rubric.md`).
- Cualquier modificación post-piloto se commitea con tag `m3-rubric-post-pilot`.
- Reversibilidad: `git restore` revierte la rúbrica a su estado pre-piloto.

---

## Pendiente — antes del piloto

- [ ] Creator completa PASS-1, PASS-2, PASS-3 (mínimo 3)
- [ ] Creator completa FAIL-1, FAIL-2, FAIL-3 (mínimo 3)
- [ ] Creator confirma definición operativa al inicio (umbrales 1 / 2 / 2)
- [ ] Commit con mensaje `chore(helix-lang): m3 rubric pre-registered for v3 pilot session <session_id>`
- [ ] `helix-council.sh` modificado para honrar `HELIX_M3_GATE=1` (Sprint 1 de implementation)
