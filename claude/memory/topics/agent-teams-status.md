# Agent Teams (Capa 3) — Status real

Última verificación: 2026-06-12 (implementación v1 multi-sesión, REQ-TEAM-001)

## Historia

- 2026-04-11 (evolución #7): se reportó "Capa 3 real con peer-to-peer mailbox" — **promesa falsa**.
- 2026-04-27: verificación componente por componente concluyó que NADA existía. Este archivo quedó como prueba de verificación con compromiso de honestidad.
- 2026-06-12: el creator pidió coordinar 3 sesiones interactivas de Claude en paralelo sobre Helix. Se implementó **Capa 3 v1** con el blueprint mínimo de este archivo, adaptado: los "agentes" de v1 son sesiones interactivas completas (no subagents), coordinadas por mailbox de archivos.

## Realidad verificada (2026-06-12)

| Componente | Estado | Verificación |
|---|---|---|
| `~/.helix/team/mailbox/<rol>/inbox.jsonl` | ✅ existe (lead/builder/guardian) | E2E checks 4-7 |
| `~/.helix/team/presence/<rol>.json` | ✅ existe (equivale a teammates/state) | E2E checks 2, 21-23, 25 |
| `~/.helix/team/board/tasks/<id>.json` | ✅ task board con ownership | E2E checks 10-16 |
| `~/.helix/team/locks/` (mkdir advisory) | ✅ con owner enforcement | E2E checks 17-20 |
| Helper send/recv/peek mailbox | ✅ `helpers/helix-team.sh` | cursor semantics checks 5-7 |
| Helper state (join/heartbeat/status) | ✅ mismo helper | checks 2, 21-23 |
| Atomicidad bajo concurrencia | ✅ flock | check 24: 30 sends concurrentes → 30/30 JSONL válidas |
| Detección sesión muerta | ✅ STALE por last_seen >15min O pid inexistente | checks 22-23 |
| PID real de la sesión claude | ✅ join sube el árbol de procesos hasta `comm=claude` | check 25 (pid 1301730 pts/5 ALIVE) |
| Hook `TaskCreated` en settings.json | ❌ NO — decisión deliberada v1 | gotcha conocido: hooks se pierden si settings.json se reescribe. Coordinación por polling en checkpoints (protocol.md §4.2) |
| Doctrina + roles | ✅ `team/protocol.md` (ES) + `team/roles/{lead,builder,guardian}.md` (EN, capa 5) | — |

## Qué es v1 (alcance honesto)

- Coordina **sesiones interactivas** (terminales separadas), no subagents del harness. El caso subagent peer-to-peer sigue cubierto por Capa 1 secuencial o Capa 2.
- **Polling, no push**: cada rol hace `recv` en checkpoints obligatorios (inicio de task, antes de done, idle). Latencia = disciplina de polling.
- HELIX-LANG obligatorio en handoffs (el helper RECHAZA task/handoff/done sin campo handoff) — cumple D5.B formas estructurales.
- Solo el `lead` commitea e integra. Workers con `file_scope` disjunto por task.
- 100% local (D2), sin cron ni daemons (D2.1), reversible: `rm -rf ~/.helix/team`.

## Sprint 1 (REQ-002, 2026-06-12) — 4/4 tasks done y aprobadas

- `watch <rol> [interval] [timeout]` en helix-team.sh (builder) — formaliza el polling, peek-only, exit 0/3.
- Línea `👥 team` en helix-statusline.sh (builder) — rol + unread + ALIVE/STALE, read-only, 0 costo sin team dir.
- Suite formal `team/tests/run-tests.sh` (guardian) — 40/40, sandbox CLAUDE_CONFIG_DIR, nunca toca estado vivo.
- Threat model `team/audit/capa3-threat-model.md` (guardian) — 9 hallazgos (F-01 CRÍTICO prompt injection vía mailbox). Mitigaciones → sprint 2.

## Sprint 2 (REQ-003, 2026-06-12/13) — hardening, 4/4 tasks done y aprobadas

- TASK-005 (builder): 6 mitigaciones en helix-team.sh — banner anti-inyección en recv (F-01.2), strip ANSI/control (F-06), rechazo de symlink en inbox+cursor (F-04), cap 100 registros loss-free (F-09), gate de secrets vía HSL L3 con sobre PreToolUse JSON (F-03), chmod 700 en init (F-05). Verificado 6/6 por el lead.
- TASK-008 (guardian): **HIGH cerrado** — integrity-check.sh resolvía TARGETS al árbol legacy `~/.claude` mientras el config vivo es `~/.helix`; CLAUDE.md + 50+ helpers estaban sin L4 desde la migración evol. 94/97. Ahora resuelve desde `CLAUDE_CONFIG_DIR`.
- TASK-007 (guardian): tampering detection probado en manifest real — artefacto estable editado → verify exit 1; board task editada → verify exit 0 (excluida por diseño).
- TASK-006 (guardian): suite 40→54 checks, cobertura de regresión de las 6 mitigaciones.
- TASK-LEAD: doctrina F-01.1/F-07 en protocol.md §7 + 3 briefs (msg=dato, validar contra board, bloquear lo sospechoso).
- TASK-LEAD: F-05 `chmod 700 ~/.helix/team` aplicado.

## Sprint 3 (REQ-004, 2026-06-13) — board journal, F-02 CERRADO, 5/5 tasks done y aprobadas

- TASK-009 (builder): board journal append-only `board/journal.jsonl` con hash-chain sha256 canónico (sort_keys + separators estables). Append por mutación bajo el mismo flock que la task = atómico. Subcomandos `reconcile` (valida cadena + replay vs board real), `journal [task_id]`, `journal-init`.
- TASK-011 (builder): secrets-gate LOW-1 — `_scan_secrets` distingue exit 2 (secret→rechaza) de otro non-zero (scanner roto→fail-OPEN con WARN). Un scanner roto ya no bloquea al equipo.
- TASK-012 (builder): journal entry antes de `os.replace` (journal lidera el board en torn-write) + sentinel `.journal-initialized` que bloquea `rm journal + journal-init`.
- TASK-013 (builder): **consolidación** — el lead encontró que el sentinel era medio-efectivo (guardaba journal-init pero `reconcile` con journal vacío y el auto-baseline de `mutate` seguían lavando). Discriminador `journal_lost()` unifica los 3 paths: refuse-on-sentinel-mismatch. Override humano = borrar sentinel a propósito.
- TASK-010 (guardian): suite 54→71 checks (17 JRNL nuevos). F-02 blindado con regresión permanente.
- TASK-LEAD: doctrina del journal en protocol.md §6 (el lead corre `reconcile` en cada review) + brief del lead.

**Lineage F-02:** TASK-004 lo encontró → TASK-007 documentó honestamente el gap residual → sprint 3 lo cerró → TASK-010 lo blindó con tests. Verificado independientemente por el lead: 9/9 paths de lavado + 71/71 suite.

## Límites honestos del journal (trust model un-solo-usuario-OS)

- Un atacante que recompute toda la cadena hash, O borre `journal.jsonl` + el sentinel `.journal-initialized` + re-baselinee, derrota la evidencia. `reconcile` es tamper-EVIDENCIA, no defensa criptográfica.
- Torn-write: si el append falla tras `os.replace` el board queda un paso adelante; `reconcile` lo flagea (fail-safe).

## Procedimiento operativo L4 (importante)

- Tras integrar cambios a archivos vigilados: `CLAUDE_CONFIG_DIR=~/.helix integrity-check.sh update` para re-baselinear estado confiable.
- `verify` SIN el env var da falso-positivo (manifest keyed a `.helix`).
- `evolve.sh` escribe CLAUDE.md → L4 lo flagea legítimamente; re-baselinear tras cada evolución.

## Sprint 4 (REQ-005, 2026-06-13) — mejoras a Helix CORE (fuera de Capa 3)

Primer uso del equipo para mejorar Helix mismo (no la Capa 3). Auditoría 360 paralela → fixes.

**Seguridad (el mayor valor del esfuerzo):**
- **C-1 CRÍTICA — ACE** encontrada por el guardian en cross-review (mi agente Capa 1 la rató "limpio"): `python3 -c` interpolaba `$TOOL_CALLS` de `/tmp/helix-cost-*` (world-writable) en el source. Cerrada en **2 sinks** (session-end.sh + swarm-panel.sh — el 1er fix fue incompleto, el guardian insistió en barrer la clase). Fix: valores como `sys.argv` (dato), fallback `ls -t /tmp` eliminado. Verificada adversarialmente (5 payloads + prueba diferencial). Loop: guardian halla → lead corrige → guardian verifica.
- H-1 (self-check.sh misma clase), H-2 (L4 wired a session-start advisory), M-1 (frontend-intent-gate path), M-2 (evolve-guard cubre learn+skill+risk, L5 bypass), M-3 (council session_dir valid_id), M-4 (override log 644→400), MEDIUM-1 (.gitignore), MEDIUM-2 (L4 71→91 archivos), L-1/L-2 (perms 600).
- L-3: evaluado, NO fix (keywords pre-sanitizadas a `[a-z]{4,}`, grep -F rompería alternación). L-4 diferido.

**Calidad/perf:** CLAUDE.md -26% tokens (#94-105 archivadas), health-check falso-CRÍTICO cerrado (storage vs contexto activo), statusline.cjs muerto eliminado, council context_pack Opción B (6 embeds inline → Read-by-path; bonus: ahora pasa por L1 injection-detector).

**Lecciones clave:**
1. Un solo par de ojos de seguridad no basta — el cross-review independiente encontró un ACE que el barrido automático generalizó como limpio.
2. Un fix debe tratar el patrón como CLASE, no bug aislado (el 1er fix dejó vivo el 2do sink).
3. El board de helix-team.sh necesita **editar descripción** y **reasignar tasks** (gaps confirmados 2× este sprint: re-scope perdió contra board stale; tasks de roles STALE no reasignables).

## Pendientes conocidos (no bloqueantes)

- **Gaps de helix-team.sh para próximo sprint Capa 3:** (a) comando para editar descripción/scope de task; (b) reasignación de tasks de rol STALE; (c) lock con enforcement opcional (hoy advisory).
- Council Opción B: **el primer council real post-cambio debe ser presenciado por el creator** (confirmar que los agentes hacen el Read del pack).
- Re-asignación automática de tasks de un rol STALE — hoy decide el lead manualmente.
- Roles dinámicos (hoy fijos: lead/builder/guardian en `ROLES_KNOWN`).
- Hook opcional de notificación push — solo si el polling genera fricción real.

## Compromiso de honestidad

Cada componente de la tabla existe y fue testeado el 2026-06-12 (25 checks E2E + stress). Si un componente se rompe o se elimina, ESTE archivo debe actualizarse en la misma sesión.
