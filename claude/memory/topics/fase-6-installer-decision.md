# FASE 6 installer — Council #4 ESCALATED to creator

> Council session `20260504T045809Z-lk1` ejecutado 2026-05-04 sesión #21.
> Audit log inmutable: `~/.claude/council/log/20260504T045809Z_lk1.yaml` (chmod 400).
> Outputs detallados: `~/.claude/council/context-pack/20260504T045809Z-lk1/outputs/`.

---

## Trigger

Creator argumentó que el plan v4 original (defer FASE 6 4 meses, prereq ≥3 máquinas) no contabilizaba el costo presente: cada ciclo install/uninstall manual de Helix consume tokens de Claude Code (Opus). Argumento: tokens caros para instalar el sistema en sí es contraproducente.

## Verdict

**ESCALATED al creator.** El council no alcanzó consenso APPROVE/REJECT. Posiciones Round 1: 0 APPROVE, 2 REJECT (skeptic 0.78, conservative 0.75), 3 ABSTAIN (innovator, synthesizer R1, researcher 0.73).

Razones de la escalada:
1. **Hipótesis no medida:** todos los roles coinciden en que "instalar consume tokens significativos" carece de medición cuantitativa, aunque R2 cost-tracker existe (evolution #68).
2. **MEASURE_FIRST insuficiente:** synthesizer Round 2 propuso medir antes de decidir; devils-advocate (attack 0.82) demostró que R2 v0.1 mide por sesión, no por ciclo — granularidad insuficiente, falsa precisión.
3. **Alternativa radical no evaluada:** innovator propuso eliminar el concepto installer (Helix = dotfiles git + bootstrap.sh sin LLM, GNU Stow) — cambia la naturaleza del problema, requiere evaluación formal.
4. **Defer 4 meses tiene riesgo CRITICAL:** sin owner ni hard-stop, se vuelve zombie indefinido.

---

## 4 opciones estructuradas para el creator

### OPCIÓN A — MEASURE_FIRST con mitigations
- Instrumentar R2 cost-tracker con granularidad **por-ciclo-installer** (no por-sesión)
- Asignar owner explícito (creator) + hard-stop T+2 semanas
- Budget cap del experimento: **$20 USD** (si supera → abort, decidir con data parcial)
- Medir 2 ciclos install+uninstall reales con R2 tageado
- Decisión binaria al cierre: si cost/ciclo justifica vs ROI installer → reabrir; si no → archivar
- **Costo:** ~1 día instrumentación + 2 ciclos medición

### OPCIÓN B — RADICAL: eliminar el concepto installer
- Spike técnico: convertir Helix en repositorio git de dotfiles + `bootstrap.sh` shell idempotente
- GNU Stow para gestión de symlinks (proven idempotent, decades de uso real)
- Deploy = `git clone helix && ./bootstrap.sh` — **cero tokens de Claude Code**
- HW5 detection (hwprobe ya existe FASE 9) se mantiene como pasos determinísticos del bootstrap
- Si viable, **defer del installer LLM-based es PERMANENTE**, no temporal
- **Costo:** 2-3 días de spike técnico + validación 1 máquina

### OPCIÓN C — DEFER explícito 4 meses con condición binaria
- Mantener defer del plan v4 original
- Pero con trigger explícito: "≥3 máquinas reales reportan fricción documentada → reabrir; sino → archivar permanente"
- Owner: creator. Reminder mecánico (cron-personal o file-based, no auto-ejecuta nada por D2.1)
- **Costo:** 0 ahora, riesgo zombie mitigado por condición binaria

### OPCIÓN D — FAST-TRACK 1 máquina (rompe criterio plan v4)
- Proceder con installer mínimo en 1 máquina como prueba
- Sin esperar 3 máquinas (rompe criterio plan v4 explícitamente)
- T+2 semanas para MVP funcional
- **Costo:** 2 semanas de trabajo, riesgo edge cases descubiertos en máquina 2/3

### OPCIÓN META — proponer opción E
Si ninguna encaja, el creator puede proponer alternativa que el council no contempló.

---

## 5 mitigations obligatorias (cualquier camino que se elija)

| ID | Mitigation | Severity addressed |
|---|---|---|
| **M1** | R2 cost-tracker debe instrumentar granularidad **por-ciclo-installer** antes de medir | HIGH |
| **M2** | Defer NO open-ended. Owner explícito + hard-stop + criterio binario | CRITICAL |
| **M3** | Budget cap experimento medición: **$20 USD**. Supera → abort | HIGH |
| **M4** | Thresholds $2/$0.50 deben justificarse contra ROI installer vs dotfiles+Stow | MEDIUM |
| **M5** | Antes de cementar defer, evaluar formalmente alternativa RADICAL (dotfiles + Stow) | HIGH |

Estas mitigaciones derivan del Round 3 devils-advocate (attack_strength 0.82, 4 escenarios catastróficos identificados).

---

## Recomendación práctica del council (no vinculante — creator decide)

Si el creator quiere **decisión rápida con bajo riesgo:** OPCIÓN B (eliminar concepto installer). Es la única que:
- Cumple D2 (100% local, no LLM en core path)
- Cumple D3 (bash+Python, no requiere TRANCH 3 binario Go/Rust)
- Resuelve el dolor del creator (tokens de install) de forma estructural, no incremental
- El spike de 2-3 días puede validarse en 1 máquina (la del creator) y confirmarse en 2 más cuando aparezcan
- Si funciona, **plan v4 original FASE 6 puede archivarse permanente** (no defer)

Si el creator quiere **rigor data-driven:** OPCIÓN A con M1-M3 aplicadas.

Si el creator quiere **mantener disciplina del plan:** OPCIÓN C (defer explícito con trigger binario).

---

## Próximos pasos

**Esta sesión:** terminar. El council emitió verdict ESCALATED. La decisión es del creator y se toma fuera del council.

**Próxima sesión cuando el creator decida:**
1. Creator selecciona opción A/B/C/D/E
2. Si A o B o D: nueva sesión de implementación con el camino elegido
3. Si C: cementar trigger binario en `topics/` y archivar este doc

**Constraint duro:** cualquier camino seleccionado requiere aplicar mitigations M1-M5 antes de ejecutar.

---

## Estadísticas council

- Rondas ejecutadas: 3 (fast-track)
- Roles invocados: 7 (1 arbiter pre + 5 Round 1 + 1 synthesizer R2 + 1 devils R3 + 1 arbiter final = 9 LLM calls)
- Wall clock: ~5 minutos
- PII redactions: 0
- Constitution violations: 0
- Audit log inmutable: `~/.claude/council/log/20260504T045809Z_lk1.yaml`

Council #4 dentro de R5 time-box constitutional (rounds≤3, calls≤25, wall-clock<600s).
