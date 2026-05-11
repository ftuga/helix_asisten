# Pilot Readiness — HELIX-LANG v3

> **Etiqueta logica del piloto:** `feature/helix-lang-v3-pilot`
> **Generado:** 2026-05-07 (post-Sprint 6)
> **Estado:** PENDIENTE DE INPUT DEL CREATOR (rubrica M3 + invocacion del piloto)
> **Council authority:** `20260507T215307Z-109qf` (GO_WITH_PRECONDITIONS)

---

## Estado actual de las 7 preconditions del council

| # | Precondition | Estado | Detalle |
|---|---|---|---|
| **P1** | Rubrica M3 pre-registrada | ⏳ PENDIENTE CREATOR | Template en `~/.helix/skills/helix-lang/m3-rubric.md`. Necesita >=3 PASS + >=3 FAIL llenados. Auto-validacion via awk pattern. |
| **P2** | Toggle finalizado (env var) | ✅ DONE | `HELIX_LANG_VERSION=2.1\|3.0` resuelto en `cmd_prepare`. Default 2.1. Inyecta `PROTOCOL_VERSION` per-prompt (DA3). |
| **P3** | M1 threshold ≥15% full-text | ✅ DONE | Documentado en `SKILL-v3-DRAFT.md` §11.4. Medicion via `usage.input_tokens + usage.output_tokens`. |
| **P4** | M5 politica por idioma | ✅ DONE | Heuristica de deteccion en `cmd_prepare`. Por ahora advisory (default 2.1 durante piloto). Activacion automatica post-rollout (DRAFT §4). |
| **P5** | Backward compat con v2.1 | ✅ DONE | `helix-lang-detect.sh` extendido. Smoke test en sesion `20260507T215307Z-109qf` pasa al 91% adoption sin regresion. |
| **P6** | N=2 con A→B gating | 📋 LISTO | Topics confirmados: A meta-circular (backup SKILL.md) + B tecnico externo (retencion logs HSL). Ambos en ES. |
| **P7** | S:hash add-on metric | 📋 LISTO | Documentado en DRAFT §2.4. Sin implementacion separada — sale gratis del piloto. |

---

## Estado actual de las 4 mitigaciones criticas del devil's advocate

| # | Mitigacion | Estado | Detalle |
|---|---|---|---|
| **DA1** | Segundo piloto en dominio tecnico | ✅ INCORPORADO | Es el Council B del N=2. A→B gating en P6. |
| **DA3** | Toggle per-prompt injection | ✅ DONE | `PROTOCOL_VERSION: HELIX_LANG_VERSION=...` inyectado en cada prompt en cada round. No depende de env inheritance. |
| **DA5** | Atomic rollout | ✅ DONE | Resuelto por arquitectura: prompts dinamicos per-session. Rollout final = 1 mv (DRAFT→SKILL.md) ejecutado por `rollout-v3.sh --confirm`. |
| **DA6** | M3 blocking gate | ✅ DONE | `helix-council.sh finalize` honra `HELIX_M3_GATE=1`. Espera input tipeado PASS/FAIL. Sin auto-finalize. |

---

## Archivos creados/modificados en este proceso

| Archivo | Status | Funcion |
|---|---|---|
| `~/.helix/skills/helix-lang/SKILL.md` | INTACTO (v2.1 activo) | Spec actual de produccion |
| `~/.helix/skills/helix-lang/SKILL-v3-DRAFT.md` | NUEVO | Spec v3 propuesto (~600 lineas, 13 secciones) |
| `~/.helix/skills/helix-lang/m3-rubric.md` | NUEVO TEMPLATE | Rubrica M3 — esperando input creator |
| `~/.helix/skills/helix-lang/rollout-v3.sh` | NUEVO STUB | Promotion script v2.1→v3.0 con preconditions hardcodeadas |
| `~/.helix/skills/helix-lang/backups/SKILL.md.v2.1.bak-pre-pilot-*` | BACKUP | Snapshot pre-piloto |
| `~/.helix/council/scripts/helix-council.sh` | MODIFICADO | DA6 gate + toggle resolution + version-aware prompt generation |
| `~/.helix/council/scripts/helix-lang-detect.sh` | MODIFICADO | Patrones v3 + version-aware adoption + backward compat warning |

---

## Lo que necesita input del creator para arrancar el piloto

### Bloqueante 1 — Rubrica M3 (P1)

Editar `~/.helix/skills/helix-lang/m3-rubric.md` y completar:

1. PASS-1, PASS-2, PASS-3 con ejemplos de summaries que considera claros (cada uno con `Por qué pasa: <texto real, no placeholder>`)
2. FAIL-1, FAIL-2, FAIL-3 con ejemplos de summaries que considera ambiguos/oscuros (cada uno con `Por qué falla: <texto real>`)
3. Al menos 2 ejemplos en EN (ej: PASS-3 y FAIL-3) y 2 en ES

**Validar:** ejecutar `bash ~/.helix/skills/helix-lang/rollout-v3.sh --check` y verificar que P1 pase.

### Bloqueante 2 — Invocacion del piloto

Una vez P1 OK, invocar:

```bash
# Council A (meta-circular, ES)
HELIX_LANG_VERSION=3.0 HELIX_M3_GATE=1 \
  ~/.helix/council/scripts/helix-council.sh prepare \
  "Politica de backup automatico de SKILL.md antes de rollout de cualquier v3" \
  medium ~/.helix
```

Despues seguir el flujo normal (invocar arbiter_pre, los 5 roles, collect, etc.). El gate M3 dispara en `finalize`.

### Bloqueante 3 — Council B (solo si A pasa todas las metricas)

```bash
HELIX_LANG_VERSION=3.0 HELIX_M3_GATE=1 \
  ~/.helix/council/scripts/helix-council.sh prepare \
  "Politica de retencion de logs de audit Helix HSL v1" \
  medium ~/.helix
```

---

## Plan de exit hacia rollout

1. Council A pasa M1+M2+M3+M4+M5
2. Council B pasa M1+M2+M3+M4+M5
3. `bash ~/.helix/skills/helix-lang/rollout-v3.sh --check` retorna OK
4. Creator revisa `--rollout` (dry-run) y ejecuta `--confirm`
5. SKILL.md activo es v3.0. v2.1 queda en backups.
6. Registrar evolution en `~/.helix/CLAUDE.md` (manual, decision del creator)

## Plan de rollback si el piloto falla

1. NO ejecutar `rollout-v3.sh --confirm`
2. Mantener SKILL.md activo en v2.1 (intacto)
3. Conservar SKILL-v3-DRAFT.md con nota de fallo + datos del piloto
4. Retro: cual M fallo, en que agentes, con que ejemplos
5. Si recuperable: ajustes sobre el DRAFT, repetir piloto
6. Si no recuperable: archivar v3 como diseño aprobado pero no implementado

---

## Costo estimado del piloto

| Fase | Tiempo creator |
|---|---|
| P1 — escribir rubrica M3 | ~15-20 min |
| Council A | ~25-30 min (prep + ejecucion + analisis M1-M5) |
| Council B (si A pasa) | ~25-30 min |
| **Total** | **~65-80 min** |

Si Council A falla M1, M2 o M3: el piloto aborta antes de B. Tiempo gastado ~30 min.
Rollback completo: < 3 min (`rollout-v3.sh --rollback`).
