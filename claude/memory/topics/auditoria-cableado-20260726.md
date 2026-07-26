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

- ~~Privacidad del sync~~ → **CERRADO**, ver §Privacidad abajo.
- **L3/L4 de contexto:** clasificador de intención por request y progressive
  disclosure del `CLAUDE.md` (~13k tokens fijos, con `DECISIONES CEMENTADAS`,
  `SESIONES` y `EVOLUCIONES` como candidatos a archivo).
- **L1/L2 + brief/evaluador:** a council. Ver §Brief en `CLAUDE.md`.
- **580 capturas pasivas** sin revisar desde mayo: cortar con fecha declarada y
  calibrar el threshold con las próximas 20.

---

## Privacidad — reincidencia del leak de cliente (commit `c0a3c5b`)

El sync volvió a copiar al `claude/CLAUDE.md` filas que nombran clientes, con
número de contrato incluido. Además había fuga **ya commiteada** en 4 archivos
(entre ellos una credencial de test). El `filter-repo` del 2026-07-08 limpió el
dato de julio pero no esto.

### Tres fallas independientes que se veían como una

1. **El pre-commit guard no cubría `claude/CLAUDE.md`.** Su filtro de
   `STAGED_FILES` sólo miraba `memory/agents`, `memory/topics`, `active-rules` y
   `skills/`. El archivo que efectivamente filtró en julio **nunca se revisó**.
2. **`private-patterns.txt` tenía sólo los placeholders del diseño original** —
   ningún cliente real del año. Por eso el del incidente de julio pasó: el patrón que lo habría
   atajado nunca se agregó. La lista se pobló con word-boundary y el matcher pasó
   a `grep -liE`: sin `\b`, el nombre corto de una entidad matchea **dentro** de
   palabras comunes (una de 4 letras cae dentro de "clausura" y "asegurar"), y el
   guard se vuelve inusable por falsos positivos.
   Se documenta **no** agregar sistemas públicos (MIPRES, minsalud, SUIN):
   bloquearlos genera ruido y entrena a saltarse el guard.
3. **El guard vivía sólo en `.git/hooks/`**, que no se versiona. Un clone fresco
   —incluido el derivado institucional— quedaba **sin guard**. Ahora está en
   `scripts/hooks/` y `update.sh` activa `core.hooksPath`.

### Dos mecanismos, porque no todo se arregla igual

- **Exclusión por archivo** para documentos cuyo propósito *es* el contexto de
  cliente: sanearlos línea por línea los dejaría en nada. `sessions-history.md`
  entra acá porque es el archivo del bloque SESIONES — misma categoría, misma
  regla. También al `.gitignore`.
- **Sanitización por patrón línea a línea** (`scripts/sanitize-private.sh`) para
  los de valor mixto. El sanitizador anterior sólo borraba secciones con marker,
  así que las **filas de tabla** con nombres de cliente sobrevivían en
  `active-rules`, `evolution-history` y `sessions.md`.

Dos acciones por patrón: `drop` descarta la línea (clientes) y `redact` reemplaza
el identificador conservando la línea — un aprendizaje técnico que sólo menciona
de paso un repo privado no debe perderse del repo público.

**En archivos de código se fuerza `redact` y nunca `drop`:** descartar una línea
puede romper un heredoc o dejar sintaxis inválida. Verificado con un caso real.

### Dos lecciones de método

- **Orden:** la sanitización corre DESPUÉS de todas las copias. En la primera
  versión quedó antes de los `rsync` de helpers y skills, que la sobreescribían
  — el leak habría vuelto **en cada sync**, silenciosamente.
- **Verificación independiente del checker:** el pre-commit devolvía `exit 0` en
  silencio, y eso podía significar "limpio" o "no vio ningún archivo". Hubo que
  contar cuántos archivos matcheó su propio filtro (32) y después grepear el
  contenido staged por los 11 términos **aparte del guard**. Resultado: 0
  ocurrencias en todo lo que entra al repo; los únicos matches restantes viven en
  `session-log.txt` y `evolution-log.txt`, ambos gitignored — y si alguien los
  forzara, el guard ahora los ve.

### Pendiente, decisión del creator

El **historial git** conserva las ocurrencias ya publicadas hasta un rewrite con
`filter-repo` + force-push (precedente: 2026-07-08, `af06265`→`ee4c33c`). Los
objetos viejos pueden seguir cacheados en GitHub por SHA hasta el GC. Eso no se
hace sin OK explícito.

### Rewrite del historial — ejecutado con OK explícito del creator

Segunda vez en el año (precedente 2026-07-08). **El alcance real sólo se ve
escaneando todas las refs, no HEAD**: en HEAD quedaban 4 archivos; en el
historial había 217 blobs con la entidad institucional, 155 con una credencial
de test y 45 con el nombre del cliente EPS.

Procedimiento que funcionó:

1. Respaldo doble — `git bundle create --all` + mirror clone — y anotar los SHAs
   previos de cada ref para poder volver.
2. Inventario por término sobre `git rev-list --all`.
3. `filter-repo` con **`--replace-text` Y `--replace-message`**: el primero no
   toca los mensajes de commit, y 4 cuerpos nombraban clientes. Más
   `--path … --invert-paths` para el archivo cuyo propósito *es* contexto de
   cliente.
4. Verificar sobre el repo reescrito: 0 ocurrencias, 136 commits preservados,
   `fsck` limpio.
5. **Comparar el remoto contra el respaldo ANTES de forzar**, para confirmar que
   nadie más empujó mientras tanto.
6. `push --force` a **todas** las refs (`main`, `develop` y el tag): dejar una
   sola con el historial viejo mantiene el dato alcanzable y anula el ejercicio.
7. Verificación final desde un **clone fresco del remoto**, no del repo local.

Dos fricciones de la herramienta: `filter-repo` pide confirmación interactiva si
ya corrió antes (`.git/filter-repo/already_ran`) y **elimina el remote `origin`**
al terminar — hay que volver a agregarlo.

Caveat que no depende de nosotros: GitHub puede conservar los objetos viejos
accesibles por SHA hasta su GC, y forks o PRs abiertos los retienen.
