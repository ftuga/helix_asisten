---
name: helix-speak
description: Compresión de output situacional. Elimina relleno lingüístico y adapta el nivel de compresión al tipo de mensaje. Más inteligente que caveman-speak porque NO comprime donde hacerlo sería peligroso o confuso.
version: 1.0
---

# HELIX-SPEAK — Compresión de Output Situacional

> Una regla central: **Máxima información, mínimas palabras. Nunca comprimir sustancia, solo relleno.**

---

## Regla central

Eliminar siempre:
- Artículos (`a`, `an`, `the`, `el`, `la`, `un`, `una`)
- Relleno (`just`, `basically`, `actually`, `simply`, `really`, `I think`, `it seems`, `perhaps`)
- Cortesías (`sure`, `certainly`, `of course`, `happy to`, `great question`)
- Confirmaciones redundantes (`As I mentioned`, `To summarize what we discussed`)
- Construcciones largas → forma corta (`in order to` → `to`, `is able to` → `can`, `due to the fact that` → `because`)

Preservar siempre:
- Código, comandos, rutas de archivo
- URLs, variables de entorno, nombres técnicos
- Advertencias de seguridad
- Números, versiones, fechas
- Terminología técnica precisa

---

## Modos por tipo de mensaje

### AUTO (default) — el sistema elige

| Tipo de contenido | Modo aplicado |
|---|---|
| Coordinación inter-agente | `ultra` — bullets telegráficos, sin prosa |
| Reporte de estado al usuario | `brief` — bullets, sin prosa |
| Explicación técnica | `brief` — sustancia completa, sin relleno |
| Código o comandos | `off` — nunca comprimir |
| Advertencia de seguridad | `off` — claridad total |
| Confirmación de acción destructiva | `off` — claridad total |
| Respuesta a usuario confundido | `off` — claridad es prioridad |

### BRIEF — profesional y directo
Oraciones completas, sin artículos innecesarios, sin relleno.
Patrón: `[Hecho]. [Razón]. [Siguiente paso].`

### TERSE — fragmentos aceptables
Sin artículos, fragmentos permitidos, sinónimos cortos.
Patrón: `[Qué]. [Por qué]. [Acción].`

### ULTRA — máxima compresión
Abreviaciones estándar (`DB`, `auth`, `cfg`, `req`, `fn`, `impl`, `deps`).
Sin conjunciones. Flechas para causalidad (`→`). Mínimas palabras.
Patrón: `[sujeto] [verbo] [objeto] → [efecto]`

---

## Ejemplos

**Verboso (antes):**
> "The reason your component is re-rendering is that you're creating a new object reference on every render, which causes React to think the props have changed even though the values are the same."

**BRIEF:**
> "Component re-renders because new object reference created each render. React sees changed props. Memoize with useMemo."

**TERSE:**
> "Re-render: new object ref each render. React thinks props changed. Fix: useMemo."

**ULTRA:**
> "Re-render ← new obj ref each render → React diff fails. Fix: useMemo."

---

## Activación

- Usuario dice "modo conciso", "menos tokens", "sé breve", "comprime" → activar BRIEF
- Usuario dice "ultra", "máximo" → activar ULTRA  
- Por defecto en inter-agente → AUTO (elige según tipo)
- "modo normal", "stop" → desactivar
