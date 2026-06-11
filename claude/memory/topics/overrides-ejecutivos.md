# Protocolo de Overrides Ejecutivos (D4)

> Creado por Helix Council 2026-06-10 (decision_C-meta).
> Audit log inmutable: `~/.helix/council/log/20260610T175912Z_20260610T161758Z-ianr.yaml` (chmod 400).
> Motivado por: skeptic R2 elevó severity a CRITICAL al detectar que evolution #84 implementó enforcement de HELIX-LANG contra council REJECTED-5v1 bajo D4 sin documentar el override.

## El problema

Sin protocolo formal, los overrides ejecutivos bajo D4 (HELIX_ROLE=creator) corren el riesgo de:

1. **Silenciar al council**: si decisiones council pueden ser overridden sin proceso, el council es consultivo, no deliberativo. Su valor agregado tiende a cero.
2. **Drift no detectable**: doctrina puede divergir de decisiones council sin que ningún mecanismo lo detecte. Hoy ese gap es invisible.
3. **Groupthink por anticipación**: agentes futuros calibran outputs sabiendo que la decisión final no es del council. Homogenización hacia lo que el creator probablemente quiera.

## Definiciones

**Override ejecutivo**: cambio doctrinal (CLAUDE.md, topics/, settings.json) implementado por el creator bajo `HELIX_ROLE=creator` (D4) que contradice o reemplaza una decisión registrada en `~/.helix/council/log/*.yaml`.

**Decisión council registrada**: cualquier veredicto APPROVE / APPROVE_WITH_PRECONDITIONS / REJECT / ESCALATED en un audit log inmutable del council.

## Requisitos formales (REGLA OPERATIVA)

Todo override ejecutivo DEBE registrarse **ANTES** de implementar el cambio, con:

### (a) Audit log inmutable

Archivo en `~/.helix/council/overrides-log/<timestamp>_<original_council_id>.yaml` con permisos `chmod 400`.

Schema mínimo:
```yaml
override_id: <timestamp>_<original_council_id>
timestamp: <ISO 8601 UTC>
overridden_council_id: <council_id original>
overridden_decision: <decision A/B/C-meta etc>
overridden_verdict: <APPROVE | APPROVE_WITH_PRECONDITIONS | REJECT | ESCALATED>
override_justification: |
  <razón del override en prosa>
new_doctrine_after_override: <archivo + sección que cambia>
reversibility_path: <comando o pasos exactos para revertir>
re_council_window_days: 90  # default; puede ser menor con justificación
creator_signature: <git config user.email>
```

### (b) Referencia explícita al council overridden

El override DEBE citar:
- `council_id` (e.g., `20260507T043859Z-n0n28i`)
- `decision` específica (A, B, C, etc.)
- `verdict` original (APPROVE, REJECT, etc.)
- Path al audit log original (`~/.helix/council/log/*.yaml`)

### (c) Justificación documentada

Prosa que responde:
- ¿Qué evidencia nueva no estuvo disponible al council?
- ¿Qué cambió en el contexto operativo?
- ¿Por qué no se puede esperar a un nuevo council?

Si la respuesta es "ninguna evidencia nueva, solo discrepancia de juicio del creator": override es **legítimo bajo D4** pero requiere admitirlo explícitamente. Esto no es vergüenza; es trazabilidad.

### (d) Reversibility statement

Comando o pasos exactos para revertir el override. Sin esto, el override es de facto irreversible.

Ejemplo:
```yaml
reversibility_path: |
  1. git revert <commit_hash>
  2. export HELIX_LANG_ENFORCE=mandatory
  3. confirmar restauración con: grep -q 'OBLIGATORIO' ~/.helix/CLAUDE.md
```

### (e) Ventana de re-council automática

Default: **90 días**. Si el override persiste >90d sin justificación explícita en `topics/`, debe convocarse un nuevo council para ratificar o revocar.

Excepciones:
- Overrides puntuales no doctrinales (hotfix, edits puntuales sin impacto en agentes): exentos.
- Overrides con confidence promedio >0.7 en el council original: ventana se acorta a 30d.

## Hook automático (a implementar)

Hook `session-start.sh` que emite `[HELIX-OVERRIDE-UNDOCUMENTED]` si:
- Existe una `evolution-history.md` entry que contradice un veredicto `REJECTED` en `council/log/*.yaml`, Y
- No existe entry correspondiente en `council/overrides-log/`.

**Status**: hook NO IMPLEMENTADO al cierre de este council. Implementación pendiente. Mientras tanto, el creator es testigo manual durante sesiones interactivas.

Owner: creator. Deadline: T+14d (2026-06-24). Verification: smoke test con caso documentado.

## Backstop institucional

**Si >1 override ejecutivo no documentado se detecta en una ventana de 30d**, debe convocarse un council automático sobre **el propio protocolo** de overrides — i.e., el creator perdió calibración del protocolo y necesita re-deliberación.

Trigger: contador en `~/.helix/council/overrides-log/violations.jsonl`. Append-only.

## Entry retroactiva: Override #84

### Registro

```yaml
override_id: 20260507-retroactive-84
timestamp: 2026-06-10T18:00:00Z  # registro retroactivo, NO timestamp del override original
recorded_by: council_20260610T161758Z-ianr decision_C-meta
overridden_council_id: 20260507T043859Z-n0n28i
overridden_decision: "Enforcement de HELIX-LANG"
overridden_verdict: REJECTED  # votos: approve=1, reject=5, abstain=1, conditional_approve=1
override_justification: |
  Evidence at time of override (creator-reconstructed retroactively):
  - Creator interpretó el REJECTED como "rechazo del enforcement agresivo específico
    propuesto", no como "rechazo del concepto HELIX-LANG".
  - Creator decidió que un enforcement moderado (warning si adoption<30%) era
    consistente con la intención del council.
  - No se registró este razonamiento en su momento.

  Esta interpretación NO fue documentada como override en 2026-05-07. Eso es el
  gap de trazabilidad que motivó decision_C-meta en council 2026-06-10.
new_doctrine_after_override: |
  ~/.helix/CLAUDE.md §ORQUESTACIÓN L107 (vigente desde 2026-05-07 hasta 2026-06-10):
  "todo handoff entre agentes Helix DEBE incluir un bloque HELIX-LANG con las 5 formas"
reversibility_path: |
  El override fue CORREGIDO POR decision_B de council 20260610T161758Z-ianr.
  Régimen mixto vigente desde 2026-06-10. Ver topics/helix-lang-regimen-mixto.md.
re_council_window_days: 0  # corregido retroactivamente, ventana N/A
creator_signature: luisfrontuso@gmail.com
```

Este audit log retroactivo se crea en `~/.helix/council/overrides-log/20260507-retroactive-84.yaml`.

## Implicación para councils futuros

Cualquier council, incluido este, puede ser overridden por el creator bajo D4. Pero a partir de 2026-06-10:

1. El override DEBE seguir este protocolo.
2. Sin entry en `overrides-log/`, el override es **no documentado** y dispara `[HELIX-OVERRIDE-UNDOCUMENTED]`.
3. Backstop institucional fuerza re-deliberación si el patrón se vuelve recurrente.

Esto preserva D4 (creator scope, autoridad ejecutiva) sin sacrificar la legitimidad del council como mecanismo deliberativo.
