# Route Cost Audit — Helix R1 advisor (augmented)

> Auto-generado por `helix-route-cost-audit.py refresh` el 2026-05-04T04:34:40Z.
> Fuente cost: transcripts JSONL via R2 cost-rollup. Fuente routing: `routing-feedback.jsonl`.
> AGENT_TO_DOMAIN y DOMAIN_RECOS son mapeos ESTÁTICOS (anti-poisoning, paralelo a M1 CS1).

---

## 1. Cost por modelo+proyecto (R2 rollup, sin cambios)

Ver `helix-cost-rollup.sh report` para regenerar. Tabla más reciente:

### Tabla por modelo + proyecto


| Modelo | Proyecto | Sesiones | Input tok | Output tok | Cache W | Cache R | USD |
|---|---|---|---|---|---|---|---|
| claude-opus-4-7 | documentos-proyectos-tecnologicos-tesis-gabriel-ent-tesis | 8 | 96616 | 7042373 | 25216737 | 1512495691 | $3271.1846 |
| claude-opus-4-7 | documentos-proyectos-tecnologicos-pagina-web | 3 | 23790 | 2466991 | 6074758 | 669286654 | $1303.2129 |
| claude-opus-4-7 | documentos-proyectos-tecnologicos-tesis-gabriel-Vigilancia-Obst-trica-Municipal | 8 | 5595 | 2170162 | 8359351 | 509177083 | $1083.3495 |
| claude-opus-4-7 | helix-asisten | 11 | 60266 | 3704896 | 10701386 | 390070257 | $1064.5276 |
| claude-sonnet-4-6 | documentos-proyectos-tecnologicos-comite-compras-proyecto-proceso-comite-compras | 2 | 4846 | 420549 | 2832551 | 162253691 | $65.6209 |
| claude-sonnet-4-6 | documentos-proyectos-tecnologicos-maquinas-lab-turbaco-maquinas-lab-turbaco | 2 | 1692 | 925241 | 3828755 | 120726721 | $64.4595 |
| claude-sonnet-4-6 | helix-asisten | 11 | 18494 | 793007 | 3270380 | 111732042 | $57.7341 |
| claude-sonnet-4-6 | documentos-borrare-herraminta-priorizacion-herramienta-priorizacion | 5 | 43371 | 1086073 | 3624929 | 90831830 | $57.2642 |
| claude-sonnet-4-6 | documentos-borrare-presupuesto-mutual-costeo-repo-mutual | 3 | 4630 | 415966 | 1274713 | 25805114 | $18.7751 |
| claude-sonnet-4-6 | documentos-proyectos-tecnologicos-plantilla-front-standar-plantilla-front-proy-‹entidad› | 1 | 3689 | 250050 | 519854 | 16881858 | $10.7758 |
| claude-opus-4-7 | documentos-proyectos-tecnologicos-comite-compras-proyecto-proceso-comite-compras | 1 | 46 | 8694 | 181902 | 1625447 | $6.5016 |
| claude-sonnet-4-6 | documentos-proyectos-tecnologicos-registro-retiros-proyecto | 2 | 123 | 29757 | 471585 | 5755435 | $3.9418 |
| <synthetic> | documentos-borrare-presupuesto-mutual-costeo-repo-mutual | 1 | 0 | 0 | 0 | 0 | $0.0000 |
| <synthetic> | documentos-borrare-herraminta-priorizacion-herramienta-priorizacion | 2 | 0 | 0 | 0 | 0 | $0.0000 |
| TOTAL | all | — | — | — | — | — | $7007.3477 |

## 2. Volumen por dominio (routing-feedback)

| Dominio | Total calls | Success | Fail | % success | Top agentes |
|---|---|---|---|---|---|
| **council** | 41 | 41 | 0 | 100% | `council-synthesizer`(8), `council-skeptic`(7), `council-innovator`(7) |
| **frontend** | 26 | 26 | 0 | 100% | `frontend-developer`(26) |
| **backend** | 12 | 12 | 0 | 100% | `python-pro`(12) |
| **general** | 10 | 10 | 0 | 100% | `general-purpose`(10) |
| **ui** | 5 | 5 | 0 | 100% | `ui-ux-designer`(4), `ui-designer`(1) |
| **security** | 2 | 2 | 0 | 100% | `security-auditor`(1), `api-security-audit`(1) |
| **architecture** | 2 | 2 | 0 | 100% | `architect-reviewer`(2) |
| **testing** | 2 | 2 | 0 | 100% | `test-engineer`(2) |
| **research** | 2 | 2 | 0 | 100% | `Explore`(1), `claude-code-guide`(1) |
| **domain-specific** | 2 | 2 | 0 | 100% | `mme-domain-expert`(2) |
| **meta-helix** | 2 | 2 | 0 | 100% | `harness-optimizer`(2) |
| **product** | 1 | 1 | 0 | 100% | `app-creative-genius`(1) |
| **analytics** | 1 | 1 | 0 | 100% | `data-analyst`(1) |
| **debug** | 1 | 0 | 0 | 0% | `error-detective`(1) |
| **review** | 1 | 1 | 0 | 100% | `code-reviewer`(1) |

## 3. Modelo recomendado por dominio (heurístico)

Mapping estático en código. Updates requieren edición manual + code review.

| Dominio | Modelo recomendado | Razón |
|---|---|---|
| analytics | `claude-sonnet-4-6` | Análisis de reportes y métricas (evidencia: 1 calls) |
| architecture | `claude-opus-4-7` | Decisiones de diseño, trade-offs no triviales (evidencia: 2 calls) |
| backend | `claude-sonnet-4-6` | Endpoint, refactor, async patterns (evidencia: 12 calls) |
| brand | `claude-opus-4-7` | Naming, copy, estrategia creativa |
| council | `claude-opus-4-7` | Deliberación multi-agente, alto razonamiento, low frequency (evidencia: 41 calls) |
| db | `claude-sonnet-4-6` | Queries, schemas, optimización |
| debug | `claude-opus-4-7` | error-detective primero — root cause análisis profundo (evidencia: 1 calls) |
| defi | `claude-opus-4-7` | Dominio especializado, multi-step on-chain analysis |
| domain-specific | `claude-sonnet-4-6` | Conocimiento específico no creativo (evidencia: 2 calls) |
| finance | `claude-opus-4-7` | Modelado complejo, multi-asset reasoning |
| frontend | `claude-sonnet-4-6` | Componente React/TS estándar (evidencia: 26 calls) |
| fullstack | `claude-sonnet-4-6` | Span DB→API→UI |
| general | `claude-sonnet-4-6` | Sin dominio específico — default seguro (evidencia: 10 calls) |
| infra | `claude-sonnet-4-6` | Docker, CI/CD, deploys |
| meta-helix | `claude-sonnet-4-6` | Auditar harness, optimizaciones reversibles (evidencia: 2 calls) |
| mlops | `claude-sonnet-4-6` | MLflow/Airflow tracking + DAGs |
| observability | `claude-haiku-4-5` | Pattern match en logs/alertas, alta frecuencia |
| product | `claude-opus-4-7` | Creative reasoning, vision (evidencia: 1 calls) |
| research | `claude-sonnet-4-6` | Búsqueda en codebase / web research (evidencia: 2 calls) |
| review | `claude-sonnet-4-6` | Code review estándar (evidencia: 1 calls) |
| security | `claude-opus-4-7` | Análisis de superficie de ataque, OWASP, cripto (evidencia: 2 calls) |
| testing | `claude-sonnet-4-6` | Test cases, fixtures, coverage (evidencia: 2 calls) |
| ui | `claude-sonnet-4-6` | Visual design + interaction patterns (evidencia: 5 calls) |
| uncategorized | `claude-sonnet-4-6` | Agente no mapeado — default conservador |
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
