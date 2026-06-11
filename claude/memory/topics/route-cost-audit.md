# Route Cost Audit — Helix R1 advisor (augmented)

> Auto-generado por `helix-route-cost-audit.py refresh` el 2026-06-10T14:28:53Z.
> Fuente cost: transcripts JSONL via R2 cost-rollup. Fuente routing: `routing-feedback.jsonl`.
> AGENT_TO_DOMAIN y DOMAIN_RECOS son mapeos ESTÁTICOS (anti-poisoning, paralelo a M1 CS1).

---

## 1. Cost por modelo+proyecto (R2 rollup, sin cambios)

Ver `helix-cost-rollup.sh report` para regenerar. Tabla más reciente:

### Tabla por modelo + proyecto


| Modelo | Proyecto | Sesiones | Input tok | Output tok | Cache W | Cache R | USD |
|---|---|---|---|---|---|---|---|
| claude-opus-4-7 | documentos-borrare-presupuesto-mutual-costeo-repo-mutual | 7 | 154726 | 7457755 | 30511770 | 1007611786 | $881.7220 |
| claude-opus-4-7 | documentos-borrare-herraminta-priorizacion-herramienta-priorizacion | 8 | 7821 | 4813413 | 12890407 | 1099697726 | $750.7883 |
| claude-opus-4-7 | documentos-proyectos-tecnologicos-registro-retiros-proyecto | 8 | 17796 | 2592033 | 9830000 | 1112712843 | $682.6837 |
| claude-opus-4-7 | helix-asisten | 12 | 15324 | 1995230 | 8970909 | 248794869 | $230.4230 |
| claude-opus-4-7 | documentos-proyectos-tecnologicos-pagina-web | 2 | 286 | 35695 | 555670 | 6556277 | $7.6449 |
| claude-opus-4-7 | documentos-borrare-video-to-text-pruebas | 2 | 21530 | 67377 | 363492 | 6900607 | $7.5142 |
| claude-opus-4-7 | documentos-borrare-video-to-text-pruebas-deimer | 1 | 27681 | 87668 | 272954 | 4667653 | $6.3699 |
| <synthetic> | documentos-proyectos-tecnologicos-registro-retiros-proyecto | 1 | 0 | 0 | 0 | 0 | $0.0000 |
| <synthetic> | documentos-borrare-presupuesto-mutual-costeo-repo-mutual | 2 | 0 | 0 | 0 | 0 | $0.0000 |
| <synthetic> | helix-asisten | 1 | 0 | 0 | 0 | 0 | $0.0000 |
| TOTAL | all | — | — | — | — | — | $2567.1460 |

## 2. Volumen por dominio (routing-feedback)

| Dominio | Total calls | Success | Fail | % success | Top agentes |
|---|---|---|---|---|---|
| **council** | 132 | 132 | 0 | 100% | `council-synthesizer`(30), `council-skeptic`(21), `council-innovator`(21) |
| **frontend** | 36 | 36 | 0 | 100% | `frontend-developer`(35), `typescript-pro`(1) |
| **backend** | 14 | 14 | 0 | 100% | `python-pro`(12), `backend-developer`(2) |
| **general** | 10 | 10 | 0 | 100% | `general-purpose`(10) |
| **ui** | 6 | 6 | 0 | 100% | `ui-ux-designer`(5), `ui-designer`(1) |
| **review** | 4 | 4 | 0 | 100% | `code-reviewer`(4) |
| **research** | 3 | 3 | 0 | 100% | `Explore`(2), `claude-code-guide`(1) |
| **security** | 2 | 2 | 0 | 100% | `security-auditor`(1), `api-security-audit`(1) |
| **architecture** | 2 | 2 | 0 | 100% | `architect-reviewer`(2) |
| **testing** | 2 | 2 | 0 | 100% | `test-engineer`(2) |
| **domain-specific** | 2 | 2 | 0 | 100% | `mme-domain-expert`(2) |
| **meta-helix** | 2 | 2 | 0 | 100% | `harness-optimizer`(2) |
| **uncategorized** | 2 | 2 | 0 | 100% | `linguista-computacional-tokens`(2) |
| **product** | 1 | 1 | 0 | 100% | `app-creative-genius`(1) |
| **analytics** | 1 | 1 | 0 | 100% | `data-analyst`(1) |
| **debug** | 1 | 0 | 0 | 0% | `error-detective`(1) |

## 3. Modelo recomendado por dominio (heurístico)

Mapping estático en código. Updates requieren edición manual + code review.

| Dominio | Modelo recomendado | Razón |
|---|---|---|
| analytics | `claude-sonnet-4-6` | Análisis de reportes y métricas (evidencia: 1 calls) |
| architecture | `claude-fable-5` | Decisiones de diseño, trade-offs no triviales (evidencia: 2 calls) |
| backend | `claude-sonnet-4-6` | Endpoint, refactor, async patterns (evidencia: 14 calls) |
| brand | `claude-fable-5` | Naming, copy, estrategia creativa |
| council | `claude-fable-5` | Deliberación multi-agente, alto razonamiento, low frequency (evidencia: 132 calls) |
| db | `claude-sonnet-4-6` | Queries, schemas, optimización |
| debug | `claude-fable-5` | error-detective primero — root cause análisis profundo (evidencia: 1 calls) |
| defi | `claude-fable-5` | Dominio especializado, multi-step on-chain analysis |
| domain-specific | `claude-sonnet-4-6` | Conocimiento específico no creativo (evidencia: 2 calls) |
| finance | `claude-fable-5` | Modelado complejo, multi-asset reasoning |
| frontend | `claude-sonnet-4-6` | Componente React/TS estándar (evidencia: 36 calls) |
| fullstack | `claude-sonnet-4-6` | Span DB→API→UI |
| general | `claude-sonnet-4-6` | Sin dominio específico — default seguro (evidencia: 10 calls) |
| infra | `claude-sonnet-4-6` | Docker, CI/CD, deploys |
| meta-helix | `claude-sonnet-4-6` | Auditar harness, optimizaciones reversibles (evidencia: 2 calls) |
| mlops | `claude-sonnet-4-6` | MLflow/Airflow tracking + DAGs |
| observability | `claude-haiku-4-5` | Pattern match en logs/alertas, alta frecuencia |
| product | `claude-fable-5` | Creative reasoning, vision (evidencia: 1 calls) |
| research | `claude-sonnet-4-6` | Búsqueda en codebase / web research (evidencia: 3 calls) |
| review | `claude-sonnet-4-6` | Code review estándar (evidencia: 4 calls) |
| security | `claude-fable-5` | Análisis de superficie de ataque, OWASP, cripto (evidencia: 2 calls) |
| testing | `claude-sonnet-4-6` | Test cases, fixtures, coverage (evidencia: 2 calls) |
| ui | `claude-sonnet-4-6` | Visual design + interaction patterns (evidencia: 6 calls) |
| uncategorized | `claude-sonnet-4-6` | Agente no mapeado — default conservador (evidencia: 2 calls) |
| unknown | `claude-sonnet-4-6` | Sin agente declarado — default |

## 4. Caveats / honestidad de los datos

1. **routing-feedback NO captura modelo por call.** El cross-join completo (dominio × modelo) no es posible con la data actual; recomendaciones son heurísticas no observadas.
2. **success rate ~100% en feedback** sugiere que la métrica está sub-calibrada (Helix marca éxito por default si no hay error explícito). Tomar con cautela.
3. **Mapping AGENT_TO_DOMAIN incompleto** para agentes nuevos. Cada agente nuevo requiere actualizar la tabla en `helix-route-cost-audit.py` (+code review).
4. **Recomendaciones son advisor, NO router automático.** Claude Code es single-model en runtime; el creator decide manualmente o setea `model` en settings.json. R1 informa la decisión.
5. **DOMAIN_RECOS subjetivo.** Validar con benchmarks reales antes de cambiar el setting global. v2.0 podría agregar A/B test framework.

## 5. Gate B1 #2 — Pre-audit cost

Este reporte cierra el criterio R1 "pre-audit costo poblado antes de roll out":
- Sección 1: cost por modelo×proyecto (R2, ya disponible).
- Sección 2: volumen por dominio (cross-join routing-feedback × static AGENT_TO_DOMAIN).
- Sección 3: recomendaciones por dominio (heurísticas, documentadas).
- Sección 4: caveats explícitos sobre limitaciones de la data.

Audit log de cierre Gate B1 #2: `~/.claude/council/log/20260504T035500Z_b1-check-2-closed.yaml`.
