# Auditoría de cableado — 2026-07-26

> Sesión de evolución. Detalle completo de los hallazgos que en `CLAUDE.md`
> quedan como punteros de una línea (capa 2: doctrina narrativa en español).
> Commit: `bcc78af`.

## Contexto: por qué no se vio antes

`health-check.sh` reportaba **"✅ Ecosistema Helix en perfecto estado"** con las
tres fallas activas. Dos causas:

1. Los heredocs de python corrían en subshell y sus advertencias **no llegaban a
   los contadores de bash** — imprimía `⚠️` y cerraba con `Advertencias: 0`.
2. No existía ningún chequeo de "capability declarada vs cableada". Todo lo que
   verificaba era **existencia de archivos**, nunca si algo los escribía o leía.

## Hallazgo 1 — Split-brain de telemetría (~3 meses)

Seis sinks escribían con `~/.claude` hardcodeado mientras todo lo que los LEE
resuelve `$CLAUDE_CONFIG_DIR` (= `~/.helix` desde la migración):

| Sink | Archivo afectado |
|---|---|
| `agent-routing-hook.sh:85,97` | `skill-usage.jsonl`, `skill-quality.jsonl` |
| `helix-route.sh:273` | `routing-feedback.jsonl` |
| `helix-stack.sh:647` | `routing-feedback.jsonl` |
| `session-exit-hook.sh:57` | `session-end.sh` (**inexistente** en ese árbol) |
| `helix-cache-metrics.sh:32` | `~/.claude/projects` (transcripts) |
| `passive-capture-review.sh:42,51` | display de rutas |

**Evidencia dura:** `skill-quality.jsonl` tenía **320 líneas frescas** (escritas
ese mismo día) en el árbol muerto contra **76 congeladas el 2026-05-04** en el
vivo. El loop de anti-bias/routing (`helix-route`, `helix-erl`, `helix-stack`)
decidió ~3 meses con datos de mayo. `helix-cache-metrics` calculaba ratios sobre
316 transcripts congelados mientras el árbol vivo acumulaba 167 nuevos.

`session-exit-hook` apuntaba a un `session-end.sh` que no existe ahí → el cierre
automático (regla #11) fallaba **en silencio**.

**Recuperación:** los 3 meses de señal se mergearon al árbol vivo con dedup por
contenido y orden por `ts` (353 y 431 registros resultantes). El árbol huérfano
quedó archivado en `~/.claude/memory/_MIGRADO-A-HELIX-20260726/` con README.

## Hallazgo 2 — Prompts a subagentes sin escanear

Hasta esta fecha **nada** revisaba el prompt de un subagente buscando secretos.
En abril `agent-spawn.jsonl` registraba `injection_hits` + `secret_hits` por
spawn; ese writer desapareció del código (el `.jsonl` quedó huérfano con 6
entradas de abril) y `secrets-scanner-hook.sh` cubría sólo
`Write|Edit|MultiEdit|Bash`. Un secreto leído antes en la sesión podía viajar
en el brief de un subagente sin control alguno.

**Fix:** `Agent` entra al matcher y el hook **bloquea** (exit 2) en vez de sólo
registrar. Bloquear > loggear. Verificado con caso que debe bloquear y caso
limpio. Los dos `.jsonl` huérfanos se borraron declarándolo en
`memory/_DEPRECADOS.md` — dos telemetrías del mismo evento es deuda.

## Hallazgo 3 — Doctrina citando artefactos inexistentes

`risk-map` aparecía en la **regla #3** y en el **checklist pre-cierre**, y no
existía en ningún proyecto ni tenía productor en el código. Yo llevaba meses
citando esa regla como si el artefacto existiera.

La bitácora tenía **dos compuertas mudas** en `helix-bitacora-hook.sh`:

- `:56` → `[[ ! -f "$BITACORA" ]] && exit 0`, y **nada creaba el archivo**.
- `:78` → sólo insertaba si encontraba el header exacto de la tabla; si faltaba,
  no hacía nada, con `|| true` tapando el resultado.

**Números reales:** 1 bitácora en 8 proyectos (la de `pagina_web`, congelada el
2026-04-23) y 0 risk-maps, con el hook corriendo en cada Write/Edit desde abril.

La plantilla existía sólo como instrucción dentro de `/helix-analiza`, un doc de
465 líneas donde el paso 7 está al final. **Una plantilla en un doc de
instrucciones no es un productor.** Ahora lo es `helix-artifacts-init.sh`:
ejecutable, idempotente, greppable, invocado desde el comando.

## Guard anti-recurrencia — `helix-wiring-audit.sh`

Tres chequeos que **fallan**, no advierten:

1. Telemetría clasificada como *continua* con writer pero sin escribir >14d.
   (Las *por evento* — judge, r1, nav-audit, injection-alerts — están exentas de
   frescura por diseño y declaradas en el script; se les chequea que tengan
   writer.)
2. Writer construyendo un path global a `~/.claude` sin `CLAUDE_CONFIG_DIR`,
   más detección de reaparición de `.jsonl` en el árbol huérfano.
3. Doctrina que cita un artefacto sin productor **y** que no existe en disco.

Probado con 4 casos que **deben** fallar (staleness forzada, writer mal
apuntado, árbol huérfano reaparecido, artefacto sin productor). Dos bugs propios
salieron en esa prueba: el regex capturaba substrings
(`fable5-helix-audit-…` → `helix-audit-…`) y el guard **se auto-declaraba
productor** porque su código nombra los artefactos que busca.

## Statusline scoped por sesión

`routing-feedback.jsonl` es global y el panel `👥 agents` filtraba sólo por
ventana de 60 minutos → mostraba los agentes de **otras ventanas abiertas**.
El writer no registraba `session_id`, así que hubo que arreglar ambos lados:
el hook ahora lo persiste y el statusline filtra por él. Entradas sin `session`
son previas al fix y no cuentan como de la sesión actual.

## Pendientes que esta sesión dejó abiertos

- **Privacidad del sync (bloqueante para push):** hay dos capas y ninguna cubre
  el caso que falló en julio.
  1. `update.sh` sanitiza `memory/agents`, `memory/topics` y `skills` por
     markers, pero **no toca `claude/CLAUDE.md`** — el archivo exacto que filtró
     datos de cliente el 2026-07-01 vía el bloque SESIONES.
  2. El **pre-commit guard sí bloquea** por patrones (verificado en vivo: bloqueó
     este mismo commit), pero `scripts/private-patterns.txt` sólo contiene los
     placeholders de ejemplo del diseño original — **ningún nombre de cliente
     real de los que acumuló el año**. Por eso el leak de julio pasó: el patrón
     que lo habría atajado nunca se agregó.

  El commit de hoy excluyó a mano `CLAUDE.md`, `memory/` y 4 copias con contexto
  de cliente. Acción pendiente: poblar la lista de patrones con los clientes
  reales y extender la sanitización a `CLAUDE.md` (bloques SESIONES/METRICS y
  filas de EVOLUCIONES que nombren clientes).
- **L3/L4 de contexto:** clasificador de intención por request y progressive
  disclosure del `CLAUDE.md` (~13k tokens fijos, con `DECISIONES CEMENTADAS`,
  `SESIONES` y `EVOLUCIONES` como candidatos a archivo).
- **L1/L2 + brief/evaluador:** a council. Ver §Brief en `CLAUDE.md`.
- **580 capturas pasivas** sin revisar desde mayo: cortar con fecha declarada y
  calibrar el threshold con las próximas 20.
