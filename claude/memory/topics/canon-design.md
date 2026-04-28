# Helix Canon — Auto-formación trazable

Diseño v0.1 — 2026-04-27

## Problema que resuelve

Los agentes existentes (frontend-developer, python-pro, etc.) fueron escritos con conocimiento general, no auditados contra fuentes canónicas. El skill `agent-create` introduce research-first **al crear**, pero los agentes vivos no tienen mecanismo continuo de actualización contra literatura.

Las estadísticas de uso (% éxito) NO son señal válida de calidad — sufren sesgo de selección. La señal correcta es: **¿el agente sigue las prácticas documentadas en la fuente canónica del dominio?**

## Concepto

Cada agente declara un *curriculum*: lista de fuentes canónicas que define su dominio. Helix lee progresivamente esas fuentes (1 capítulo/mes), extrae reglas con cita por página, y las inyecta como contexto verificable cuando el agente se invoca.

## Componentes

### 1. Frontmatter del agente (extension)

```yaml
---
name: python-pro
description: ...
canon:
  - title: Fluent Python
    edition: 3rd
    author: Luciano Ramalho
    publisher: O'Reilly
    year: 2025
    isbn: 978-1-4920-7836-2
    chapters: 24
  - title: Effective Python
    edition: 3rd
    author: Brett Slatkin
    chapters: 19
  - title: PEP-8
    url: https://peps.python.org/pep-0008/
  - title: PEP-484
    url: https://peps.python.org/pep-0484/
canon_progress: { fluent_python_3rd: 0/24, effective_python_3rd: 0/19 }
---
```

### 2. Helper `canon-read.sh`

```
canon-read.sh <agent> <book_id> <chapter>
  → lee el capítulo (vía pageindex MCP si PDF; via context7 si docs web)
  → extrae 3-5 reglas con prompt estructurado
  → cada regla incluye: { rule, citation: {book, chapter, page}, applicability }
  → guarda en ~/.claude/memory/canon/<agent>/<book_id>.md
  → actualiza canon_progress en frontmatter
```

### 3. Storage `~/.claude/memory/canon/<agent>/<book_id>.md`

Una entrada por regla extraída:
```markdown
## R-fluent_python_3rd-005-142
**Regla:** Use `dataclass(slots=True)` para clases con muchas instancias — reduce huella de memoria 30-50%.
**Cita:** Fluent Python 3rd, Cap 5 §"Slots", p.142
**Aplicabilidad:** Python ≥3.10. No aplica si la clase necesita `__dict__` dinámico.
**Confianza:** alta (citado textual, ejemplo en libro).
```

### 4. Cron mensual

`~/.claude/cron/canon-monthly.sh`:
- Para cada agente con `canon_progress`: lee 1 capítulo siguiente
- Background, latency irrelevante
- Log en `~/.claude/memory/canon/_cron.log`

### 5. Inyección en runtime

Cuando un agente se invoca, el `Read` de su system prompt slim trae además su `canon/<agent>/*.md` (o un sumario si pesa >2KB). Las reglas extraídas son contexto adicional que el agente DEBE citar al recomendar.

### 6. Self-check anti-alucinación

Al cierre de la respuesta del agente, hook compara las afirmaciones técnicas contra el canon:
- Si el agente dice algo NO presente en canon → flag `[NO-CANON]` (advertencia)
- Si CONTRADICE canon → flag `[ANTI-CANON]` (rojo) + cita la regla violada

## Diferencias con sistemas existentes

| Sistema | Aprende de | Frecuencia | Trazable |
|---|---|---|---|
| ERL/Reflexion | Errores propios | Por incidente | No (heurístico) |
| `agent-create` | Fuentes externas | Una vez (creación) | Sí |
| **Helix Canon** | Fuentes externas | Mensual continuo | Sí (cita por página) |
| Decay-scores | Uso reciente | Por invocación | No |

## Riesgos

1. **Drift canon vs proyecto.** Un libro puede recomendar X pero el proyecto requiere Y por constraint específico. Mitigación: cada proyecto puede marcar reglas como `aplica`/`no-aplica` en `<project>/.claude/memory/canon-overrides.md`.

2. **Costos de lectura.** PDFs pesados → usar `pageindex` MCP (chunked) y cache hit del prompt cache (90% savings). Estimación: ~30 min/agente/mes.

3. **Falsa autoridad.** Un libro outdated puede dictar regla obsoleta. Mitigación: campo `year` en canon + flag automático si `year < currentYear - 5` para ediciones que cambian rápido (frontend, ML).

4. **Sobrecarga de contexto.** Si un agente acumula 100 reglas → no caben en system prompt. Mitigación: keep top-N por relevancia + sumario rolling.

## Plan de prototipo (Fase 1)

1. Implementar `canon-read.sh` para 1 agente piloto (`python-pro`)
2. Curriculum: PEP-8 (corto, accesible vía context7) → 5 reglas extraídas
3. Validar manualmente: ¿las citas son correctas? ¿las reglas son útiles?
4. Si pasa: agregar Fluent Python 3rd cap 1 como segunda fuente
5. Fase 2: cron + inyección automática + self-check

## Métricas de éxito

- **Cobertura:** % de respuestas del agente con al menos 1 cita canon
- **Anti-canon flags:** count/mes (debe tender a 0)
- **Útil/total:** ratio de reglas marcadas como `aplica` por proyectos

## Estado

- [x] Diseño v0.1
- [ ] Helper `canon-read.sh`
- [ ] Skill `helix-canon` con instrucciones de uso
- [ ] Piloto python-pro + PEP-8
- [ ] Cron mensual
- [ ] Inyección runtime
- [ ] Self-check anti-canon
