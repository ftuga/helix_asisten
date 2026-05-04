# Gate B4 — Budget Recurrente del Helix Council

> Council #1 synthesizer dissent residual #7. Mitigation devils-advocate CS4 (council se degrada a rubber-stamp si se invoca demasiado).

---

## El concern

Council #1 consumió ~330k tokens (≥8 LLM calls). Si se invoca para cada decisión arquitectónica:
- **Caro:** ~$X/sesión × N invocaciones/mes = costo significativo en API tokens.
- **CS4 — degradación:** si se vuelve rutinario, los roles del council convergen en mediana de gustos. Si se evita por costo, no hay revisión adversarial.

Ambos extremos son malos. Necesita budget explícito.

---

## Budget inicial (revisar mensualmente)

| Métrica | Target | Hard cap |
|---|---|---|
| Invocaciones council/mes | ≤4 | 6 |
| Tokens promedio por council | ~330k | 500k |
| Costo estimado/mes | <$10 | <$20 |
| Severity high/critical exclusivamente | sí — low/medium decide creator solo | regla dura |
| Self-modification core (constitución, council mismo) | siempre requiere council | regla dura |

---

## Triggers que SÍ ameritan council

- Cambios a la constitución del council mismo (R1-R9).
- Cambios estructurales al harness (nueva FASE, eliminación de capa, refactor de hooks core).
- Decisiones arquitectónicas con ≥3 alternativas viables y trade-offs no obvios.
- Acciones destructivas/irreversibles (R3) con consenso ≥5/7 requerido.
- Conflictos entre filosofías declaradas (D2 vs META2 — GATE C ejemplo).

## Triggers que NO ameritan council (creator decide solo)

- Bug fixes locales.
- Refactors dentro de un módulo existente.
- Adopciones tecnológicas reversibles en <1 día.
- Decisiones cosmetics/UX donde N=1 audiencia es suficiente (ej. Council #2 statusline fue marginal — hubiera podido ser creator decision).
- Updates de skills, agents, helpers individuales.

**Regla de bolsillo:** ¿qué pasa si esta decisión es mala? Si es "rollback en <1h sin pérdida" → no council. Si es "rollback caro o irreversible" → council.

---

## Logging obligatorio

Cada invocación council loguea en `~/.claude/council/log/`:
- Trigger
- Severity
- Token count total
- Costo estimado USD
- Decisión
- Decisión REVERTIDA después? (campo agregado retrospectivamente si aplica)

Helper de auditoría mensual:
```bash
bash ~/.claude/council/scripts/helix-council.sh audit-history  # TBD v1.1
# Output: tabla con councils del mes + budget consumido + decisiones que se revirtieron
```

---

## Mitigations contra CS4 degradación

### Si invocaciones <2/mes durante 3 meses
**Síntoma:** creator no usa el council → posiblemente innecesario para escala actual.
**Acción:** considerar archivar el council como "infraestructura disponible pero no en uso recurrente". Mantener funcional, no exigir uso.

### Si invocaciones >6/mes durante 2 meses
**Síntoma:** sobre-invocación, riesgo rubber-stamp.
**Acción:** revisar criterios de trigger. Endurecer regla "qué amerita council" — probablemente el creator está usando council para cosas que decide solo.

### Si decisiones se revierten >30%
**Síntoma:** council emite decisiones que después no aguantan → calidad de deliberación degradada.
**Acción:** auditar la última run completa. Posiblemente context_pack mal calibrado, o roles convergiendo a mediana.

---

## Anti-rubber-stamp checks

Cada council al finalizar agrega self-check:

```yaml
self_check:
  unique_proposals_round_1: <count>     # ¿al menos 3 perspectivas distintas?
  challenges_to_emergent: <count>       # ¿devils-advocate emitió ≥3 escenarios?
  dissent_residual_severity_high: <count>  # ¿quedaron disensos high sin resolver?
  decision_reverses_creator_intent: bool   # ¿la decisión emergente difiere de lo que el creator hubiera hecho solo?
```

Si `unique_proposals_round_1 <3` o `challenges_to_emergent <3` → council se considera **degradado**, audit log lo marca, próximo council debe corregir composición.

---

## Revisión del budget

Este documento se revisa cada **3 meses** o si CUALQUIER hard cap se viola.

Próxima revisión scheduled: **2026-08-04**.
