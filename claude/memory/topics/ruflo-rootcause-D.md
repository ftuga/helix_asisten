# GATE D — Root-Cause Analysis: Ruflo "0 invocaciones swarm en 30d"

> Investigación obligatoria antes de cementar D1 (discontinuar Ruflo) en CLAUDE.md global.
> Trigger: skeptic round 1 challenge top — la decisión de discontinuar se basaba en métrica sin verificar si el cero refleja ausencia de valor o trigger config rota.
> Fecha: 2026-05-04. Status: CONCLUIDO.

---

## Hipótesis 1: ausencia de valor real (lo que asumía D1)

Refutada parcialmente. Ver dispositivo.

## Hipótesis 2: trigger config rota (lo que cuestionaba el skeptic)

**CONFIRMADA** — el cero NO es evidencia de ausencia de valor.

### Evidencia dispositiva

| Hallazgo | Implicación |
|---|---|
| `claude mcp list` no muestra `claude-flow` conectado | tools `mcp__claude-flow__swarm_init` y `mcp__claude-flow__agent_spawn` NO existen en runtime |
| `~/.mcp.json` no existe; `~/.claude/.mcp.json` no existe | sin config global de claude-flow MCP |
| `~/helix_asisten/.mcp.json` no existe | sin config a nivel proyecto root |
| `~/helix_asisten/helix-engine/.mcp.json` SÍ existe con `claude-flow` | config solo aplica si Claude Code abre desde ese subdirectorio |
| ese mismo `.mcp.json` tiene `"autoStart": false` | aunque se cargara, el server NO arranca solo |
| `~/helix_asisten/.claude-flow/sessions/` tiene 4 sesiones de marzo 2026 | la herramienta SÍ se usó cuando estaba activa |
| Última sesión claude-flow registrada: epoch 1774368252 ≈ 2026-03-25 | actividad cesó coincidiendo con apertura desde root del repo |
| `routing-check-hook.sh` solo valida dominio↔agente para Capa 1 | NO existe hook que rute "2+ dominios" → claude-flow swarm |
| Evolution-history #43 (2026-04-27): "0 invocaciones swarm/team en 30d" | métrica recolectada con server desconectado — métrica inválida |

### Conclusión sobre el cero

La decisión "no usar swarm" en los últimos 30 días no fue una decisión activa de Helix evaluando valor — fue **imposibilidad técnica silenciosa**. Cuando Helix evaluaba "¿escalo a Capa 2?", las tools no existían en su catálogo runtime. Una tarea que clasificaba como multi-dominio terminaba ejecutada con "múltiples Agent tool en paralelo" (antipattern conocido — ver evolution #58) o fragmentada en Capa 1 secuencial.

---

## Concerns ortogonales al config (siguen válidos)

Aunque la métrica fue inválida, los argumentos NO-métrica para discontinuar Ruflo siguen en pie:

1. **Tool noise:** claude-flow expone ~314 MCP tools cuando se conecta. Cada tool consume tokens en el catálogo runtime. Si solo se usan 4-6 tools (`swarm_init`, `agent_spawn`, etc.), el ratio costo/beneficio es malo.
2. **Stack lock-in TypeScript/Node:** claude-flow vive en npm/Node. Helix core es bash+Python. Mantener claude-flow significa mantener una toolchain ajena.
3. **Topología externa:** la arquitectura `hierarchical-mesh` y `MAX_AGENTS=15` está embedded en el server, no es controlable desde Helix. Cualquier cambio requiere fork.
4. **Capa 2 propia minimalista (D1 original):** sigue siendo una opción razonable, pero **NO porque Ruflo no funcione** — porque Helix gana control reduciendo dependencias.

---

## Dispositivo de la gate D

### NO se acepta D1 tal cual estaba escrito en plan v4

El texto original de D1 decía:
> "0 invocaciones de swarm/team en 30 días, 314 MCP tools que inflan contexto, stack TypeScript/Node ajeno al stack bash+Python de Helix, lock-in npm."

**Reemplazar por D1' (versión rectificada):**

> **D1'. Discontinuar Ruflo / claude-flow como Capa 2.**
> **Razón válida:** tool noise (314 MCP tools), stack lock-in TS/Node ajeno al core bash+Python de Helix, topología externa no controlable desde Helix.
> **Razón descartada por inválida:** "0 invocaciones en 30d" — métrica recolectada con MCP server desconectado (`autoStart: false` + `.mcp.json` no en root). El cero no refleja decisión activa de no usar; refleja config rota silenciosa.
> **Acción:** marcar Capa 2 como "propia minimalista TBD". NO borrar `~/helix_asisten/.claude-flow/` (artefactos de uso real, valor histórico). Robar 4 ideas: GOAP A* planner, background workers, AIDefence PII pipeline, cost tracker.
> **Lo que se conserva:** los conceptos. NO la dependencia.
> **Pendiente para Capa 2 propia:** diseñar trigger automático "2+ dominios → Capa 2" que HOY no existe (CLAUDE.md lo describe pero no hay hook que lo materialice).

### D1 puede cementarse en CLAUDE.md global con texto D1'

Pero solo después de que TRANCH 1 incluya **diseño explícito del trigger Capa 2 propio** — porque sin ese trigger, "2+ dominios" caerá en el mismo antipattern que evolution #58 ya documenta (múltiples Agent tool en paralelo invisibles en orquestación).

---

## Evidencia que se generaría a 30 días si la métrica fuera válida

Para registro: si el config estuviera bien (autoStart=true, .mcp.json en root), métricas válidas requerirían:
- Log de invocaciones swarm con timestamp
- Cases identificadas como "multi-dominio" según routing-check
- Comparación: cuántas terminaron en Capa 2 vs Capa 1 fragmentada vs múltiples Agent tool

Hoy ninguna de estas métricas existe. Recolectarlas sería trabajo de ~1h pero **innecesario** dado que los concerns ortogonales (tool noise + lock-in) ya justifican D1' independientemente.

---

## Acción inmediata para esta sesión

1. Esta investigación **concluye gate D**.
2. D1' (versión rectificada) está LIBRE para cementar en CLAUDE.md global cuando se ejecute A3.
3. Diseño del trigger Capa 2 propio queda como **prerequisito de cementing D1'** — no se cementa hasta que exista el reemplazo.
4. Evolución a registrar: la métrica "0 invocaciones" fue inválida; la decisión es correcta por otras razones; documentar para evitar reincidir en métrica-driven decisions sin verificar root-cause.

## Lecciones meta

- **Antes de discontinuar por métrica, verificar que el sistema medido estaba operativo.** El skeptic tenía razón. Sin esta gate D, habríamos cementado una decisión correcta por las razones equivocadas — y eso erosiona la confianza del council como instrumento.
- **`autoStart: false` en .mcp.json es un footgun silencioso.** No hay alarma cuando un MCP configurado no arranca. Plan v4 FASE 9 (HW-aware) podría sumar HW-aware MCP también: detectar MCP servers configurados pero no conectados y avisar.
