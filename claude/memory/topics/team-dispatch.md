# Team Dispatch & Requirement Intake

> Aplica cuando el proyecto tiene `helix-team.md` (generado por `/helix-analiza`).
> Si no existe → routing normal según catálogo de agentes (`agents-index.md`).

## Al recibir un requerimiento

1. **Leer** `{PROJECT_ROOT}/.claude/memory/helix-team.md` si existe.
2. **Buscar plan reutilizable** (si Qdrant disponible):
   - `mcp__claude-flow__memory_search` con el texto del req en namespace `helix/{project}/plans/`
   - Score > 0.82 → mostrar plan anterior y preguntar "¿aplica este plan?"
   - Score ≤ 0.82 → generar plan nuevo
3. **Descomponer** en tasks: ¿qué dominios toca?
4. **Preguntar** máx 2 dudas agrupadas si hay ambigüedad real. Si está claro → proceder directo.
5. **Si toca ≥3 dominios o tiene dependencias no obvias** → generar `helix-plan-REQ-NNN.md` y mostrarlo:

```markdown
# Helix Plan — {nombre corto del req}
> Generado: {fecha} | Req: {REQ-NNN} — {resumen 1 línea}

## Tasks
| # | Task | Dominio | Agente | Input esperado | Output contract | Depende de |
|---|------|---------|--------|----------------|-----------------|------------|
| 1 | {descripción} | {dominio} | {agente} | {qué recibe} | {qué produce} | — |

## Orden de ejecución
{paralelo si no hay dependencias, secuencial si las hay}
```

Naming obligatorio: `helix-plan-REQ-NNN.md`. Cada req tiene su plan único. `self-check.sh` los limpia cuando el req pasa a Completado.

6. **Despachar** según output contracts de `helix-team.md`:
   - 1 dominio → Capa 1 directo
   - 2+ dominios sin dependencias de contrato → Capa 2 paralelo (`swarm_init` + `agent_spawn`)
   - 2+ dominios con dependencias de contrato → Capa 1 secuencial (output A → input B)
7. **Almacenar plan completado** en Qdrant: `helix/{project}/plans/{req_id}`
8. **Registrar calidad** (silencioso, tras completar el req):
   - Por cada agente principal → `bash ~/.claude/helpers/skill-tracker.sh quality <agente> <score>`
   - Score: `3` = primer intento · `2` = requirió corrección · `1` = falló

## Backlog — actualización automática

Cuando existe `{PROJECT_ROOT}/.claude/memory/helix-backlog.md`:
- Al iniciar un req → agregar fila en "🔵 En Progreso" con ID REQ-NNN
- Al completarlo → mover a "🟢 Completado" con fecha y resultado
- Si hay bloqueador → mover a "🔴 Bloqueado" con razón

No pedir permiso — mantenimiento silencioso.
