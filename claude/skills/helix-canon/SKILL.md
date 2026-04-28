---
name: helix-canon
description: Auto-formación trazable de agentes Helix contra documentación canónica (libros, PEPs, RFCs, papers). Extrae reglas con cita por página y las inyecta como contexto verificable. Invocar para auditar un agente existente contra una fuente canónica, agregar curriculum, o registrar nuevas reglas.
version: 0.1
status: piloto
---

# Helix Canon

Sistema continuo de aprendizaje de agentes contra fuentes externas auditadas. Complementa `agent-create` (que valida una sola vez al crear) con un ciclo mensual que mantiene los agentes alineados a la literatura del dominio.

Diseño completo: `~/.claude/memory/topics/canon-design.md`

## Cuándo invocar

- El usuario pregunta "audita el agente X contra Y" (libro, PEP, RFC).
- Se crea un agente nuevo con `agent-create` → declarar también su `canon:` curriculum.
- Cron mensual ejecuta `canon-monthly.sh` (Fase 2, no implementado aún).
- El usuario reporta una respuesta del agente que parece dudosa → ejecutar self-check anti-canon.

## Cuándo NO invocar

- Preguntas conversacionales rápidas (no necesitan canon).
- Agentes sin curriculum declarado (sin frontmatter `canon:`).
- Modificaciones triviales de prompt (typo, formato).

## Flujo (piloto Fase 1)

### Paso 1: Declarar curriculum

Agregar al frontmatter del agente en `~/.claude/agents/<name>.md`:

```yaml
canon:
  - title: <Título exacto>
    edition: <ed>
    author: <autor>
    year: <YYYY>
    url_or_isbn: <ID>
    chapters: <N>
canon_progress: { <book_id>: 0/<N> }
```

### Paso 2: Lectura de capítulo

```bash
bash ~/.claude/helpers/canon-read.sh <agent> <book_id> <chapter>
```

Esto:
1. Valida que el agente existe y declara canon
2. Lee el capítulo (vía `context7` para docs web, `pageindex` MCP para PDFs)
3. Extrae 3-5 reglas con prompt estructurado
4. Guarda en `~/.claude/memory/canon/<agent>/<book_id>.md`

### Paso 3: Validación manual

Antes de marcar el capítulo como "leído":
- ¿Las citas son verificables (cap + página correctas)?
- ¿Las reglas son accionables (no platitudes)?
- ¿La aplicabilidad está acotada (no "siempre/nunca" sin contexto)?

Si pasa → actualizar `canon_progress` (incrementar contador).

### Paso 4: Inyección runtime (Fase 2)

Cuando el agente se invoca, su `canon/<agent>/*.md` se carga como contexto adicional. El agente DEBE citar al recomendar prácticas (ej: *"sugiere `__slots__` [Fluent Python 3rd, Cap 5, p.142]"*).

### Paso 5: Self-check anti-canon (Fase 2)

Hook PostToolUse(Agent) compara la salida del agente contra reglas canon:
- Output que cita canon → OK
- Output con afirmación técnica sin canon → flag `[NO-CANON]`
- Output que contradice canon → flag `[ANTI-CANON]` + cita la regla

## Formato de regla extraída

```markdown
## R-<book_id>-<chapter>-<page>
**Regla:** <enunciado claro, accionable, ≤2 líneas>
**Cita:** <Libro Edición, Cap N §sección, p.NNN>
**Aplicabilidad:** <cuándo aplica / cuándo NO>
**Confianza:** alta | media | baja (con justificación si <alta)
```

## Riesgos conocidos

| Riesgo | Mitigación |
|---|---|
| Drift canon vs proyecto | `canon-overrides.md` por proyecto marca aplica/no-aplica |
| Libro outdated | Campo `year` + flag automático si <currentYear-5 en dominios de cambio rápido |
| Sobrecarga de contexto | Keep top-N por relevancia + sumario rolling si >2KB |
| Falsa autoridad de un solo libro | Curriculum requiere ≥2 fuentes por dominio |

## Estado actual (2026-04-27)

- [x] Diseño v0.1 → `topics/canon-design.md`
- [x] Helper stub → `helpers/canon-read.sh`
- [x] Skill creada (este archivo)
- [ ] Piloto python-pro + PEP-8 (próximo paso)
- [ ] Implementación real de extracción (vía context7/pageindex)
- [ ] Cron mensual
- [ ] Inyección runtime
- [ ] Self-check anti-canon hook

## Próximo experimento

Piloto: `python-pro` + PEP-8.
- PEP-8 es corto, accesible via context7, alta densidad de reglas.
- Extraer 5 reglas → validar manualmente → si pasa, escalar a Fluent Python 3rd cap 1.
