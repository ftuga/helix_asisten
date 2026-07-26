# HELIX-LANG — Régimen mixto (post-council 20260610T161758Z-ianr)

> Cementado por Helix Council 2026-06-10.
> Audit log inmutable: `~/.helix/council/log/20260610T175912Z_20260610T161758Z-ianr.yaml` (chmod 400).
> Reemplaza el "OBLIGATORIO universal" de evolution #84 (2026-05-07).
> Bench fundante: `~/.helix/memory/audit/linguista-bench-20260507.yaml`.

## Cambio de régimen

| | Régimen previo (#84) | Régimen vigente (régimen mixto, 2026-06-10) |
|---|---|---|
| Política | OBLIGATORIO universal en todo handoff inter-agente | Mixto por (idioma × forma) |
| Justificación empírica | Promesa SKILL.md ~59% compresión | Bench cl100k: EN -3.5%, ES +34.7%, ZH +44.5%, JA +59.5% |
| Council legitimación | Council 20260507T043859Z-n0n28i votó REJECTED 5v1; implementado igual bajo override D4 (NO documentado) | Council 20260610T161758Z-ianr APPROVE_WITH_PRECONDITIONS + decision_C-meta documenta override #84 retroactivamente |

## Tabla de aplicabilidad

### Por forma estructural

| Forma | Aplicabilidad | Justificación |
|---|---|---|
| Handoffs FROM→TO entre agentes | **OBLIGATORIO** cross-language | Schema estructurado reduce ambigüedad inter-agente independiente del idioma |
| Vocabularios S:hash declarados upfront | **OBLIGATORIO** cross-language | Mecánica de deduplicación por referencia |
| Estado/delta en headers de outputs council | **OBLIGATORIO** cross-language | Permite voting + tracking sin parsear prosa |
| Cuerpo analítico de prompts council | Ver tabla idioma | Aquí está el costo neto de -3.5% en EN |
| Prosa de razonamiento | Ver tabla idioma | Igual que cuerpo analítico |
| Citas textuales | NO aplica | Preserva semántica original |
| Código fuente | NO aplica | El código es su propio lenguaje |
| Respuestas user-facing | NO aplica | Mirror de idioma usuario (regla §IDIOMA Y TONO capa 1) |

### Por idioma del receptor (cuerpo analítico + prosa)

| Idioma | Régimen | Compresión real medida (cl100k_base) |
|---|---|---|
| EN | **OPT-IN INCENTIVADO** | -3.5% (cuesta MÁS que prosa EN) |
| ES | **OPT-IN INCENTIVADO** (con preferencia en estado/delta) | +34.7% en estado/delta, marginal en prosa |
| ZH | **OBLIGATORIO** | +44.5% |
| JA | **OBLIGATORIO** | +59.5% |
| Otros | **OPT-IN** | Sin medición empírica disponible |

### Cómo decidir en runtime

1. ¿La unidad es handoff estructural, S:hash o estado/delta? → OBLIGATORIO siempre. Aplica.
2. Si es prosa/cuerpo analítico: ¿qué idioma habla el agente receptor?
   - EN/ES/otros → opt-in. Adoptar si el autor lo elige.
   - ZH/JA → obligatorio.

## Threshold de adoption (refactor)

Régimen previo: 30% global (`adoption_pct` único).

Régimen vigente: desagregado por forma.

| Forma | Threshold | Si <threshold |
|---|---|---|
| Handoffs FROM→TO | ≥80% | Warning visible en finalize |
| S:hash declarations | ≥70% | Warning |
| Estado/delta headers | ≥50% | Warning |
| Prosa analítica | sin threshold | (opt-in por diseño) |

### Implementación — CERRADA (corrección de path 2026-07-01)

`helix-lang-detect.sh` existe con `adoption_by_form` en **`~/.helix/council/scripts/helix-lang-detect.sh`** (no en `~/.helix/helpers/` como decía la verificación original — drift de path, no de capability). Verification real: `test -f ~/.helix/council/scripts/helix-lang-detect.sh && grep -q 'adoption_by_form' ~/.helix/council/scripts/helix-lang-detect.sh`.

## Bench retrospectivo T+30d (2026-07-10)

Comparar tokens consumidos en councils:
- **Pre-fix** (era #84, enforcement universal): councils 2026-05-07 a 2026-06-09.
- **Post-fix** (régimen mixto): councils 2026-06-10 a 2026-07-10.

Tokenizer: `tiktoken cl100k_base`.

**Criterio de éxito**: ahorro de tokens ≥15%.

**Si NO baja ≥15%**: escalar a re-council. El régimen mixto puede no ser suficiente y B_new puede requerir refinamiento adicional (e.g., propuesta State Journal del innovator).

**EJECUTADO 2026-07-01 → PASS provisional (+52% era84→mixto, +48% pre84→mixto).** Resultado completo con caveats en `~/.helix/memory/audit/helix-lang-30d-comparison-20260710.yaml`. Caveats principales: n=1 en cohorte mixta, confounder Opción B, **S:hash adoption 0% (<70% threshold)**. No requiere re-council; sí requiere re-correr el bench en el próximo council real (que el creator debe presenciar de todos modos por la verificación pendiente de Opción B) y diagnosticar por qué S:hash no se adopta.

## Reversibility (kill switches)

```bash
# Régimen mixto (default tras council 2026-06-10)
export HELIX_LANG_ENFORCE=selective

# Revertir a #84 (obligatorio universal)
export HELIX_LANG_ENFORCE=mandatory

# Apagar HELIX-LANG completo (status quo pre-#84)
export HELIX_LANG_ENFORCE=off
```

Para revertir los cambios doctrinales completos: `git revert` del commit que aplica este régimen.

## State Journal (innovator) — DEFERRED

Propuesta: archivo único por sesión `~/.claude/sessions/<id>/hl-state.yaml` como source-of-truth del estado council/swarm. Agentes escriben append-only. Contenido NO va en prompts (elimina -3.5% EN).

**Status**: KEEP_DEFERRED. Documentado en `~/.helix/memory/topics/state-journal-deferred.md`.

**Gate de activación**: ≥3 sesiones con handoffs >5 agentes AND adoption S:hash <50% sostenida 30d.

**Razón del diferimiento**: devils-advocate identificó preocupaciones de seguridad (SC3: contaminación por prompt injection sin schema validation, conflicto de slots con HSL v1, token runaway sin TTL/max_size). Implementación requiere primero: schema YAML, sanitización, max_size, TTL, verificación de slot.

## Preconditions del council aplicadas

| # | Precondition | Owner | Deadline | Verification | Status |
|---|---|---|---|---|---|
| 1 | SKILL.md helix-lang con tabla aplicabilidad | next_session | antes próximo council | `grep -q 'régimen mixto' SKILL.md` | applying now |
| 2 | CLAUDE.md L107 + capa 4 actualizados | next_session | junto con SKILL.md | `grep -A2 'capa 4' CLAUDE.md | grep -q 'opt-in'` | applying now |
| 3 | helix-lang-detect.sh con `adoption_by_form` | creator | T+7d (2026-06-17) | `grep -q 'adoption_by_form'` | **PENDING** (helper no existe) |
| 4 | Audit log council registra adoption desagregado | automated | T+7d junto con #3 | `yq '.adoption.by_form'` en próximo audit | **PENDING** (depende #3) |
| 5 | Bench retrospectivo T+30d | creator on-demand | 2026-07-10 | archivo `helix-lang-30d-comparison-20260710.yaml` | **PENDING** |

## Deadline calendar (MOD-1 devils)

Si las preconditions 3-5 no se cumplen para sus deadlines:
- **2026-06-17**: si helix-lang-detect.sh no existe → registrar en evolve.sh como deuda de la decisión B; régimen mixto sigue vigente pero sin medición.
- **2026-07-10**: si bench retrospectivo no se ejecuta → emitir warning [HELIX-COUNCIL-PRECONDITION-EXPIRED] en próximo session-start.
