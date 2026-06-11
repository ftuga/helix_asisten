# Helix Evolution Plan v4 — Decisiones Cementadas

> Cross-reference index. Las decisiones canónicas viven en `~/.helix/CLAUDE.md` §DECISIONES ARQUITECTÓNICAS CEMENTADAS. Este archivo agrega detalles extendidos, caveats, y audit logs.

> **Nota**: este archivo fue creado el 2026-06-10 para cerrar la referencia rota detectada por la auditoría externa Claude Fable 5 (`fable5-helix-audit-20260610.md`). Antes de esa fecha, CLAUDE.md citaba este path 4 veces sin que existiera. Cierra el gap.

---

## D1' — Capa 2 propia minimalista

> Council #1 sesión #19, 2026-05-04. Audit log: `~/.helix/council/log/20260504T012655Z_*.yaml`.
> **Veredicto del audit log: ESCALATED** (no APPROVE como CLAUDE.md declaraba — gap detectado por researcher en council 2026-06-10).

### Decisión
Discontinuar Ruflo / claude-flow como Capa 2.

### Razones válidas
- Tool noise (314 MCP tools).
- Stack lock-in TS/Node ajeno al core bash+Python.
- Topología externa no controlable.
- Incidente posterior 2026-05-06: claude-flow MCP secuestra los 16 slots de hooks silenciando HSL v1.

### Razón descartada por inválida
"0 invocaciones en 30d" — métrica recolectada con MCP server desconectado.

### Prerequisito (pendiente desde 2026-05-04)
Diseñar trigger automático "2+ dominios → Capa 2 propia". Hoy CLAUDE.md describe la regla pero no hay hook que la materialice; sin ese trigger, "2+ dominios" cae en antipattern de múltiples Agent tool en paralelo.

### Estado actual
- Capa 2 propia minimalista **NO IMPLEMENTADA**.
- evolution #76 (2026-05-03) la marcó "candidate TRANCH 3 si surge demanda".
- D5.A (council 2026-06-10) cementa A3 (status quo + warning advisory) y difiere A4 con gate cuantitativo. Detalle: `topics/capa2-status.md`.

---

## D2 — Filosofía 100% local (creator scope, NO clientes)

Helix core: cero egress a servicios cloud, cero servicios pagos en pipeline crítico. Cloud opt-in solo en edges (sync, gateway), nunca core.

**CS5 mitigation**: D2 aplica a `~/.helix/CLAUDE.md` (creator scope). NO se replica a CLAUDE.md de proyectos cliente.

### D2.1 — META2/META3 on-demand only (GATE C resuelto 2026-05-04)
FASE 10 META2 (helix-market-watch) y META3 (self-improve) son capabilities que existen como código pero NO ejecutan por su cuenta. NO scheduler, NO cron, NO auto-trigger. Solo se invocan en sesión interactiva cuando el creator explícitamente pide.

El creator es testigo del egress y la ingestión. Cualquier cambio a este invariante requiere council nuevo.

---

## D3 — Stack bash+Python para core

Reescritura a Go o Rust solo cuando se empaquete binario distribuible (FASE 6 I5, TRANCH 3 pospuesto).

Razón: coherencia con stack actual, bajo costo de iteración, evita dependencia npm/cargo en core.

### Deuda no resuelta (desde 2026-05-03)
SEC1 no cumple su criterio de latencia (<30ms, p99 real 77ms) por el startup de ~35ms de bash+Python. Decisión "pending decisión latencia" desde mayo. D3 tiene un costo real que la doctrina no ha reconciliado.

---

## D4 — Distinción HELIX_ROLE creator vs user

Configuración en `~/.helix/helix-role.conf` (default=`creator`).

- `creator` → META1 helix-expert siempre activo. META2/META3 ON-DEMAND ONLY. Council activo, self-modification con OK explícito.
- `user` → solo helix-expert read-only, sin self-improve, sin market-watch.

### Caveat (Fable 5 audit 2026-06-10)
> "D4 (creator vs user) es productización prematura: no hay evidencia en el bundle de que exista un solo usuario distinto del creator; el rol `user` es infraestructura especulativa."

Status: queda como capability sin uso documentado. NO se elimina (futura demanda posible) pero se reconoce como over-engineering al cierre del council 2026-06-10.

---

## D5 — Régimen mixto HELIX-LANG + cementación A3 Capa 2 + protocolo overrides ejecutivos

> Cementada por Helix Council `20260610T161758Z-ianr` (2026-06-10).
> Audit log inmutable: `~/.helix/council/log/20260610T175912Z_20260610T161758Z-ianr.yaml` (chmod 400).
> Motivada por: auditoría externa Claude Fable 5 (`topics/fable5-helix-audit-20260610.md`).

### D5.A — Capa 2: A3 vigente + A4 diferido

Status quo + warning advisory. Hook D1' multi-domain-trigger continúa NO bloqueante.

**Gate A4** (activación de Capa 2 propia minimalista):
- Trigger primario (cuantitativo): ≥10 eventos no-council multi-domain SIN swarm_init en 30d consecutivos.
- Trigger secundario (cualitativo): creator reporta fricción con swarm_init en 2+ sesiones distintas.
- Deadline calendar **2026-09-10** para verificación manual (MOD-1 devils-advocate vs SC1 Precondition Purgatory).

**Reversibilidad**: `HELIX_D1_TRIGGER_ENABLED=0`.

Detalle: `topics/capa2-status.md`.

### D5.B — HELIX-LANG régimen mixto

Reemplaza el "OBLIGATORIO universal" del override #84 (2026-05-07).

**Formas estructurales** (cross-language OBLIGATORIO):
- Handoffs FROM→TO entre agentes
- Vocabularios S:hash declarados upfront
- Estado/delta en headers de outputs council

**Prosa analítica** (por idioma del receptor):
- EN/ES: opt-in incentivado
- JA/ZH: obligatorio

**Threshold council desagregado**: handoffs ≥80%, S:hash ≥70%, estado/delta ≥50%, prosa sin threshold.

**Bench retrospectivo T+30d (2026-07-10)**: si tokens no bajan ≥15% → re-council.

**Reversibilidad**: `HELIX_LANG_ENFORCE=selective|mandatory|off`.

Detalle: `topics/helix-lang-regimen-mixto.md`.

### D5.C — Protocolo de overrides ejecutivos (D4 hardening)

**REGLA OPERATIVA** (no solo registro): todo override ejecutivo del creator bajo D4 que contradiga una decisión registrada en `~/.helix/council/log/*.yaml` DEBE registrarse en `~/.helix/council/overrides-log/<timestamp>_<original_council_id>.yaml` (chmod 400) **ANTES** de implementar el cambio.

**Backstop institucional**: >1 override no documentado en 30d → council automático sobre el protocolo mismo.

Protocolo completo: `topics/overrides-ejecutivos.md`.

Entry retroactiva para override #84: `~/.helix/council/overrides-log/20260507-retroactive-84.yaml`.

### D5 — State Journal (innovator) DEFERRED

Propuesta arquitectónica diferida con gates explícitos y 5 preconditions de seguridad. Detalle: `topics/state-journal-deferred.md`. NO implementar hasta cumplir triggers + preconditions (MOD-3 devils-advocate).

### D5 — Caveats

#### CS5 mitigation
D5 aplica a `~/.helix/CLAUDE.md` (creator scope). NO se replica a CLAUDE.md de proyectos cliente.

#### Council ESCALATED técnico
El audit log del council 2026-06-10 marca `decision: ESCALATED` con `escalation_reason: "average confidence 0.0 < 0.6"`. Esto es por inconsistencia de schema en los outputs YAML (los roles no expusieron campos `position:` y `confidence:` en formato canónico), no por desacuerdo deliberativo. La posición común sí está formada y registrada en `round_3_synthesizer.yaml`. D5 cementa esa posición común.

**Trazabilidad del gap**: el script `helix-council.sh finalize` espera un schema canónico que la generación R1-R3 no cumplió. Esto es deuda del orquestador (no del council deliberativo). Owner: creator. Próxima sesión que toque el orquestador.

#### Preconditions con deadlines calendario
Todas las preconditions de D5.A, D5.B y D5.C tienen verification bash-checkable Y deadline calendar fijo (mitigación de SC1 "Precondition Purgatory" identificado por devils-advocate).

#### Bench retrospectivo NO automático
D2.1 prohíbe cron/scheduler. El bench retrospectivo de D5.B se ejecuta on-demand cuando el creator lo invoque en sesión. Si no se ejecuta para 2026-07-10, session-start emite `[HELIX-COUNCIL-PRECONDITION-EXPIRED]` (hook a implementar T+14d).

---

## Referencias cruzadas

- Auditoría externa Fable 5: `~/.helix/memory/topics/fable5-helix-audit-20260610.md`
- Plan v4 evolution completed (D1'-D4 detalle histórico): `~/.helix/memory/topics/helix-evolution-completed.md`
- Audit logs council inmutables:
  - D1' (#1 sesión #19): `~/.helix/council/log/20260504T012655Z_*.yaml`
  - D5 (council Fable 5 reactor): `~/.helix/council/log/20260610T175912Z_20260610T161758Z-ianr.yaml`
- Overrides ejecutivos: `~/.helix/council/overrides-log/`
- CLAUDE.md §DECISIONES ARQUITECTÓNICAS CEMENTADAS: fuente canónica de las decisiones; este archivo agrega contexto.
