# Capa 2 — Status oficial post-council 20260610T161758Z-ianr

> Cementado por Helix Council 2026-06-10.
> Audit log inmutable: `~/.helix/council/log/20260610T175912Z_20260610T161758Z-ianr.yaml` (chmod 400).
> Reporte que motivó el council: `~/.helix/memory/topics/fable5-helix-audit-20260610.md`.

## Regla vigente — A3 (status quo + warning advisory)

CLAUDE.md §ORQUESTACIÓN mantiene su tabla actual. Para 2+ dominios en paralelo:
- **Capa 2 oficial declarada**: `mcp__claude-flow__swarm_init` (descontinuado por D1' pero sigue siendo la regla escrita).
- **Capa 2 real operativa**: ninguna. claude-flow secuestra HSL hooks; Capa 2 propia minimalista no implementada.
- **Comportamiento de facto**: fallback a Capa 1 secuencial.

### Hook advisory (no bloqueante)

`helix-multidomain-trigger.py` (D1', evolution #76) continúa activo como advisory. Detecta intent multi-dominio y registra en `~/.helix/memory/d1-multidomain-detections.jsonl`. NO bloquea ejecución.

**Reversibilidad inmediata:** `HELIX_D1_TRIGGER_ENABLED=0` en environment apaga el hook sin tocar config.

## Gate A4 — Activación de Capa 2 propia (deferred)

Construcción de Capa 2 propia minimalista (snapshot handoff secuencial) queda **DIFERIDA** hasta que se cumpla cualquiera de los triggers:

### Trigger primario (cuantitativo)
≥10 eventos no-council de multi-domain detection SIN `swarm_init` posterior en ventana de 30d consecutivos, medidos por `~/.helix/memory/audit/capa2-bypass-counter.jsonl`.

**Estado actual** (2026-06-10): `d1-multidomain-detections.jsonl` tiene 4 líneas en 37 días, TODAS del propio council deliberativo. CERO operador real.

### Trigger secundario (cualitativo)
Creator reporta explícitamente fricción con la ausencia de orquestador en 2+ sesiones distintas.

### Deadline calendario (MOD-1 devils-advocate)
Si ninguno de los triggers se cumple para **2026-09-10 (T+90d)**, el creator debe revisar manualmente:
- `cat ~/.helix/memory/d1-multidomain-detections.jsonl | wc -l` para verificar que el hook está produciendo señal (defensa anti-BUG-G2).
- Si el archivo sigue con 0 líneas no-council: validar que el hook no está silenciado.
- Si tiene actividad pero <10: mantener A3.
- Si tiene >10: re-council con datos.

Sin esta verificación calendárica, el gate puede quedar en "Precondition Purgatory" indefinidamente (SC1 de devils-advocate).

## Preconditions del council aplicadas

| # | Precondition | Owner | Deadline | Verification |
|---|---|---|---|---|
| 1 | Este documento existe | creator | 2026-06-10 | `test -f ~/.helix/memory/topics/capa2-status.md` |
| 2 | Hook D1' advisory verificado | automated | ya implementado | `test -f ~/.helix/helpers/helix-multidomain-trigger.py` ✓ |
| 3 | Contador automático `capa2-bypass-counter.jsonl` | automated | T+14d | `test -f ~/.helix/memory/audit/capa2-bypass-counter.jsonl` |
| 4 | Revisión calendárica del gate | creator | 2026-09-10 | `grep -q 'reviewed:2026-09' ~/.helix/memory/topics/capa2-status.md` |

## Por qué A3 y no A1/A2/A4

Tres roles del council + 2 expert summons convergieron:

- **Architect-reviewer** (datos contundentes): 4/4 detecciones multi-dominio en 37 días son del propio council. CERO demanda operativa real. Construir A1/A4 viola M3 cheap-test.
- **Conservative R2**: status quo SÍ está siendo respetado en operación real. Cambiar arquitectura para algo que no ocurre = invertir causalidad. Confidence 0.81.
- **Innovator R2**: A4 evolves a migration path explícito, no decisión urgente.

## Innovador propuso radical (DEFERRED)

A4 (helix-snapshot como backbone de handoffs secuenciales) queda como migration path documentado:
- 3 pasos al activarse: (a) snapshot pre-Agent, (b) inyectar YAML en prompt, (c) post-Agent update snapshot.
- No requiere Capa 2 ni swarm.
- helix-snapshot ya soporta capture/show en disco (`~/.helix/snapshots/<project>/<ts>.yaml`).
- Plug-and-play 60% según architect (cross-session sí, inter-agente requiere extensión menor del schema).

Si el gate A4 se cumple, este path es la implementación recomendada.

## Devils-advocate identificó preocupaciones

- **SC1 (Precondition Purgatory)**: parcialmente mitigado con deadline calendario y verifications bash-checkables.
- **Telemetría no verificada**: BUG-G2 análogo (evolution #83). Si `d1-multidomain-detections.jsonl` tiene 0 líneas no-council con sesiones activas, el hook puede estar silenciado. Verificación obligatoria en 2026-09-10.

## Reversibilidad

- A3 ya es status quo, sin cambio de código.
- Si advisory warning resulta ruidoso: `HELIX_D1_TRIGGER_ENABLED=0`.
- Si se decide revertir A3 completo: `git revert` del commit de cementación + restaurar L107 de CLAUDE.md desde backup.
