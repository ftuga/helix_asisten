# Gate B2 — Audit Humano sobre helix-judge (anti-poisoning CS1)

> Council #1 mitigation: CS1 devils-advocate identificó que helix-judge puede envenenar su propio corpus de calibración generando ceguera sistemática.
> Sin este protocolo activo, M1 helix-judge NO se habilita en TRANCH 2.

---

## El problema (CS1)

Si helix-judge:
1. Detecta un "conflicto" en MEMORY.md
2. Genera reporte → creator descarta como falso positivo
3. Falso positivo se loguea como "decisión validada" en su corpus
4. Próximo entrenamiento del judge incluye este FP como ejemplo
5. **Judge se vuelve ciego a clases enteras de conflictos reales que se parecen al FP**

El feedback loop de 2do orden es invisible: no hay error visible, solo decay silencioso de calidad.

---

## Mitigations obligatorias (hard rules)

### 1. Threshold confianza ≥0.85
Judge NO emite verdict con confidence <0.85. Si entre 0.5 y 0.85 → emite "incierto, requiere humano".

### 2. Log estructurado de TODA decisión
Schema obligatorio (no opcional):
```yaml
schema: helix-judge-decision/v1
timestamp: <ISO 8601>
claim_a: "<texto del claim 1>"
claim_a_source: "<file:line>"
claim_b: "<texto del claim 2>"
claim_b_source: "<file:line>"
verdict: CONFLICT | NO_CONFLICT | UNCERTAIN
confidence: 0.0-1.0
reasoning: "<explicación del modelo>"
human_review: pending | confirmed | rejected
human_review_at: <ISO 8601 | null>
human_review_note: "<si aplica>"
```

Path: `~/.claude/judge/decisions/<YYYY-MM>/<timestamp>.yaml`. chmod 400 después de write.

### 3. Audit semanal humano (primer mes)
Cada semana, creator hace review de muestra aleatoria 20% de decisiones del judge:

```bash
# Pseudo-comando para revisión
bash ~/.claude/helpers/helix-judge-audit.sh weekly
# Muestra 20% aleatorio de decisiones de la semana
# Por cada una pregunta: confirmed | rejected | needs_reframing
# Marca el campo human_review en el YAML
```

Después del primer mes: review **mensual** mientras precision >80%. Si precision baja a <80% → vuelve a semanal.

### 4. Corpus de calibración SOLO con humans
El corpus de ejemplos que entrena/calibra al judge se actualiza ÚNICAMENTE con decisiones donde `human_review: confirmed`. Las marcadas `pending` o `rejected` NO se incluyen.

Hard rule en código:
```python
# pseudocode
def update_calibration_corpus(decisions):
    confirmed = [d for d in decisions if d.human_review == "confirmed"]
    if len(confirmed) < len(decisions) * 0.5:
        raise CalibrationError("Insufficient human-validated samples")
    write_corpus(confirmed)
```

### 5. Sin feedback loop con S1 (auto-update skills)
M1 helix-judge **NO puede** triggerar S1 helix-skill-evolve sin OK humano explícito. Aunque S1 esté en TRANCH 3 pospuesto, esta regla queda registrada para cuando se reintroduzca.

### 6. Disable switch
Env var `HELIX_JUDGE_DISABLED=1` deshabilita el judge sin eliminar logs ni corpus. Permite rollback rápido si se observa decay.

---

## Métricas de salud del judge

Dashboard que el creator revisa semanalmente (primer mes), después mensualmente:

| Métrica | Cálculo | Umbral verde | Umbral rojo |
|---|---|---|---|
| Precision | confirmed / (confirmed + rejected) | ≥80% | <70% |
| Recall (manual) | conflicts reales detectados / conflicts reales totales | ≥70% | <50% |
| Confidence distribution | histograma de confidence en 1k decisiones | mediana ≥0.85 | mediana <0.7 |
| Review backlog | decisiones con human_review=pending | ≤7d viejas | >14d viejas |
| Corpus growth | confirmed samples agregados/mes | crecimiento estable | descenso 2 meses seguidos |

Si CUALQUIER métrica entra en rojo → M1 se deshabilita automáticamente vía `HELIX_JUDGE_DISABLED=1`.

---

## Implementación obligatoria antes de M1 roll-out

```
□ helix-judge-audit.sh script existe y testeado
□ Schema de log YAML implementado
□ Anti-poisoning rule: corpus solo confirmed humans
□ Threshold 0.85 hard-coded
□ Disable switch funciona
□ Dashboard métricas existe
□ Primer mes: review semanal scheduled
```

Sin los 7 checks: M1 NO entra a TRANCH 2.
