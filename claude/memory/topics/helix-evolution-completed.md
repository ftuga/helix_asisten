# Helix evolution — completed work registry

> Registro post-mortem del plan v4 ejecutado al 100%.
> Reemplaza al `helix-evolution-plan-v4-decision.md` (archivado en `_archive/`).
> Decisiones arquitectónicas cementadas viven en `~/.claude/CLAUDE.md` global §"Decisiones arquitectónicas cementadas".

---

## TRANCH 1 — DONE 2026-05-04 (sesiones #19, #20, #21)

| Item | Componente | Status |
|---|---|---|
| FASE 0.5 statusline bash | `~/.claude/helpers/helix-statusline.sh` | DONE sesión #20 |
| FASE 9 HW-aware | `helix-capa0-policy.sh` + bench-capa0 + hwprobe | DONE sesión #20 |
| FASE 0 cementing D2/D3/D4 | CLAUDE.md global §"Decisiones cementadas" | DONE sesión #20 |
| D1' trigger Capa 2 | `helix-multidomain-trigger.py` advisory | DONE sesión #21 |
| Freeze formal TRANCH 2/3 (anti drift) | (resuelto al cerrar TRANCH 2) | DONE |

**Audit logs inmutables (chmod 400):** `~/.claude/council/log/20260504T012655Z_*.yaml` (Council #1).

---

## Gates pre-TRANCH 2 — DONE

| Gate | Tema | Resolución |
|---|---|---|
| B1 | Acceptance criteria por componente | 5/5 cerrados, ACK creator. Audit log: `20260504T034500Z_b1-ack-creator.yaml` + `20260504T035500Z_b1-check-2-closed.yaml` |
| B2 | Audit humano helix-judge anti-poisoning CS1 | Documentado en M1 SKILL + `m1-bench.md` §Anti-poisoning |
| B3 | Lock-in Claude Code dissent | Aceptado consciente, exit path mínimo bash+memoria portable |
| B4 | Costo recurrente council | Target 4/mes, hard cap 6/mes |
| C  | D2 vs FASE 10 META2 | Resuelto: D2.1 ON-DEMAND-ONLY cementado en CLAUDE.md global |
| D  | Ruflo root-cause "0 invocaciones" | Concluido: config rota documentada en `topics/ruflo-rootcause-D.md` |

---

## TRANCH 2 — DONE 2026-05-04 sesión #21

7 componentes implementados + wired al harness. Cada uno con bench doc + skill + audit log:

| Componente | Implementación | Bench doc | Skill |
|---|---|---|---|
| **R2** helix-cost-tracker | `helpers/helix-cost-rollup.sh` + statusline integration | (sesión #20) | — |
| **M2** helix-passive-capture | `helpers/passive-capture-hook.py` + `passive-capture-review.sh` | `m2-bench.md` | `helix-passive-review` |
| **M3** helix-project-consolidate | `helpers/helix-project-consolidate.py` | `m3-bench.md` | `helix-project-consolidate` |
| **SEC2** helix-egress-audit | `helpers/helix-egress-audit-hook.py` + `helix-egress-report.sh` | `sec2-bench.md` | — |
| **SEC1** helix-aidefence v1.0 | `helpers/helix-aidefence-hook.py` (10/10 PII types) | `sec1-bench.md` | — |
| **M1** helix-judge | `helpers/helix-judge.py` (Ollama llama3.2:3b) | `m1-bench.md` | `helix-judge` |
| **R1** helix-route-recommend | `helpers/helix-route-cost-audit.py` + `helix-route-recommend.py` | `r1-bench.md` | `helix-route-recommend` |

**Hooks activos en cascada (PostToolUse Write|Edit|MultiEdit):** bitacora → vector-sync → passive-capture → aidefence (4).
**Hooks activos PreToolUse(Agent):** routing-check → helix-lang-trigger → multidomain-trigger (3).
**Hooks activos PostToolUse WebFetch/WebSearch/mcp__:** egress-audit (1).

**M4** helix-memory-sync: DEFERRED a FASE 1.5 (decisión Gate B1).

---

## Decisiones arquitectónicas vivas (heredadas, no se borran)

Cementadas en `CLAUDE.md` global §"Decisiones arquitectónicas cementadas (plan v4)":

- **D1'** — Capa 2 propia minimalista (Ruflo discontinued con prerequisito D1' trigger). Trigger CERRADO con `helix-multidomain-trigger.py`. Capa 2 propia orquestador queda candidate para TRANCH 3 si surge demanda.
- **D2** — Filosofía 100% local (creator scope, NO clientes). CS5 mitigation: NO se replica a CLAUDE.md de proyectos cliente.
- **D2.1** — META2/META3 on-demand only. NO scheduler, NO cron, NO auto-trigger. Cualquier cambio requiere council nuevo.
- **D3** — Stack bash+Python para core. Reescritura Go/Rust solo en TRANCH 3 (FASE 6 binario distribuible).
- **D4** — Distinción HELIX_ROLE creator vs user. Config en `~/.claude/helix-role.conf`.

---

## Pendientes naturales (post-100%)

### Métricas de observación 30d (no scope plan, son "esperar evidencia")

| Componente | Criterio PENDING | Cómo validar |
|---|---|---|
| M2 | precision ≥40%, noise ≤40% | `passive-capture-review.sh stats` |
| SEC1 | falsos positivos ≤5% en logs reales | `aidefence-redactions.jsonl` audit |
| SEC2 | volumen <50/día normal | `helix-egress-report.sh` mensual |
| M1 | precision ≥70%, noise ≤30% | `helix-judge.py audit-mark` + `stats` |
| D1' | false positive rate del advisory | `d1-multidomain-detections.jsonl` |

A los 30 días con uso real, el creator corre los `stats` correspondientes y valida.

---

## TRANCH 3 — congelado por design

Pospuesto por council, requiere evidencia 30d post-TRANCH-2 antes de re-evaluar:

| Item | Status |
|---|---|
| FASE 2 S1 auto-update | **RECHAZADO definitivamente** |
| FASE 4 W1/W2 (workers) | pending, requiere file-locking + intents predefinidos |
| FASE 5 GOAP | skill-only, defer |
| FASE 6 installer | defer 4 meses, prerequisito ≥3 máquinas reales (en re-evaluación 2026-05-04 — argumento nuevo: costo tokens) |
| FASE 7 multi-platform Telegram | nice-to-have |
| FASE 10 META2/META3 | capabilities existen on-demand (D2.1), no schedule |

### FASE 6 installer — re-evaluación abierta 2026-05-04

Argumento del creator que no estaba contabilizado en plan v4 original:

> "Actualmente cada instalación de Helix consume tokens de Claude Code (Opus). Es contraproducente: tokens caros para instalar el sistema en sí. Lo mismo aplica a desinstalación."

Council convocado para deliberar:
- ¿Reabrir FASE 6 ahora con plan de ejecución mínimo (instalador bash standalone)?
- ¿Mantener defer hasta cumplir "≥3 máquinas reales"?

Resultado del council y plan de ejecución → ver `topics/fase-6-installer-decision.md` (si council finaliza con decisión APPROVED).

---

## Métricas finales sesión #21

- 8 componentes nuevos integrados al harness
- 5 nuevas skills registradas
- 17 capturas de decisiones approved (M2 corpus inicial)
- 1 backup huérfano eliminado
- 0 archivos del proyecto modificados (todo el trabajo en `~/.claude/`)
- ~3000 líneas de código + bench docs nuevas
- Plan v4 ejecutable: 100%
