# CLAUDE.md — Helix · Agente Auto-Evolutivo (Global)
> Reglas universales que aplican a TODOS los proyectos.
> El CLAUDE.md de cada proyecto hereda estas reglas y agrega las específicas.
> Última evolución: <!-- LAST_EVOLUTION -->2026-04-23 23:36<!-- /LAST_EVOLUTION -->

---

## 🔄 PROTOCOLO DE AUTO-EVOLUCIÓN

| Momento | Comando |
|---|---|
| Al corregir un error | `bash ~/.claude/evolve.sh learn "<categoría>" "<aprendizaje>" "<trigger>"` |
| Al descubrir patrón repetido (≥2 veces) | `bash ~/.claude/evolve.sh skill "<nombre>" "<descripción>"` |
| Al inicio de cada sesión | `bash ~/.claude/session-start.sh` |
| Antes de declarar una tarea completa | `bash ~/.claude/self-check.sh` |
| Al cerrar cada sesión | `bash ~/.claude/session-end.sh "<resumen>"` |

**Categorías válidas:** `seguridad` | `interfaz` | `funcionalidad` | `operatividad` | `arquitectura` | `performance` | `testing` | `datos` | `celery` | `auth` | `docker`

---

## 🎛️ MODOS DE HELIX

> Cada proyecto declara su modo en su CLAUDE.md con `HELIX_MODE: <modo>`. Si no se declara → `helix_minimal`.

| Modo | Qué activa | Cuándo usarlo |
|---|---|---|
| `helix_control_total` | 4 capas: Ollama + Subagents + claude-flow swarm + Agent Teams | Proyectos propios con `.mcp.json` |
| `helix_minimal` | Solo Capa 1 (Subagents) | Proyectos simples, clientes |
| `helix_off` | Sin orquestación. Claude directo | Exploración, preguntas rápidas |

---

## 🔍 DISCOVERY-FIRST (pre-flight obligatorio)

Antes de CUALQUIER acción que toque código o estructura del proyecto, ejecutar el pre-flight. Aplica a los 3 modos.

### 1. Detección de stack (silenciosa, 1 vez por sesión)
- Si no existe `{PROJECT_ROOT}/.claude/memory/helix-analysis.md` ni `.analysis-declined`:
  - Ejecutar `bash ~/.claude/helpers/helix-detect-stack.sh` → resumen en contexto de sesión
  - Si hay código pero sin análisis → sugerir `/helix-analiza` UNA VEZ
- Si ya hay stack detectado → cargarlo y respetarlo

### 2. Chequeo de conflicto stack↔petición
Antes de ejecutar, comparar la petición contra el stack detectado:

| Situación | Acción |
|---|---|
| Petición alineada con stack (ej: endpoint FastAPI en proyecto FastAPI) | Proceder |
| Petición fuera del stack (ej: FastAPI en proyecto Django) | **Detener. Preguntar:** "Detecto Django — ¿usar Django o migrar a FastAPI?" |
| Sin stack detectado aún | Preguntar intención antes de elegir |
| Ambigüedad de versión (React 18 vs 19, Python 3.11 vs 3.12) | Inferir del lockfile y mencionarlo, o preguntar |

### 3. Pedido de contexto adicional
Pedir contexto antes de actuar cuando:
- La petición menciona un archivo/módulo que no existe → preguntar ubicación esperada
- Hay múltiples candidatos para la misma función (ej: 2 servicios de auth) → preguntar cuál
- La acción cambia contratos públicos (API, DB schema) y no se declaró el alcance → preguntar
- Orden corta sin síntoma ("arreglá el login") → pedir repro/error concreto

### 4. Recomendaciones proactivas (accionables, sin ampliar scope)
Cuando detectes durante discovery:
- Dependencias con CVE conocido → mencionar antes de cerrar
- Stack obsoleto (Node <18, Python <3.10, React <18) → sugerir upgrade con costo estimado
- Anti-patterns evidentes (secrets hardcoded, rutas sin auth) → reportar aunque no sea scope

Reportar ≠ ejecutar. No ampliar scope sin permiso explícito.

### 5. Regla dura
Si ≥2 de las condiciones anteriores aplican y no se preguntaron → fallo de protocolo. Registrar con:
`bash ~/.claude/evolve.sh learn "operatividad" "<qué se omitió>" "discovery-miss"`

---

## 🤖 ORQUESTACIÓN (solo `helix_control_total`)

Helix decide la capa en silencio. Nunca preguntar "¿swarm o subagent?". Decidir, ejecutar, reportar.

| Señal | Capa |
|---|---|
| Log / texto largo / salida Docker | **Capa 0** — Ollama (`capa0.sh logs\|code\|transform`). Si responde "no sé" → escalar |
| 1 dominio (un endpoint, componente, bug, query) | **Capa 1** — `Agent tool` con agente del catálogo |
| 2+ dominios en paralelo (sin diálogo entre agentes) | **Capa 2** — `mcp__claude-flow__swarm_init` + `agent_spawn`. Visible en ruflow |
| Agentes que necesitan hablarse peer-to-peer | **Capa 3** — Agent Teams nativo (mailbox). Ya habilitado en `settings.json` |

**Reglas duras:**
- NUNCA múltiples `Agent tool` en paralelo para 2+ dominios — son invisibles en ruflow. Usar Capa 2.
- Bug o error inesperado → `error-detective` PRIMERO, siempre.
- Antes de declarar tarea completa → `code-reviewer`.
- Endpoint nuevo / cambio de auth → `security-auditor` + `api-security-audit`.
- Catálogo completo de agentes: `~/.claude/memory/agents-index.md` (1 dominio → 1 agente).

**HELIX-DISTILL (opcional):** solo en swarms Capa 2 con ≥8 agentes. `~/.claude/helpers/helix-distill.sh run`. Para sesiones normales, Opus 4.7 maneja contexto largo nativamente.

> HELIX-LANG decomisionado 2026-04-18 (uso real nulo desde benchmarks). Archivado en `~/.claude/memory/topics/deprecated/helix-lang/`.

---

## 🗂️ TEAM DISPATCH

Si existe `{PROJECT_ROOT}/.claude/memory/helix-team.md` → seguir protocolo en `~/.claude/memory/topics/team-dispatch.md`.
Si no existe → routing normal por `agents-index.md`.

Backlog (`helix-backlog.md`) se actualiza en silencio: en progreso → completado → bloqueado. No pedir permiso.

---

## 🔒 PRIVACIDAD

Contexto de proyecto en `memory/agents/*.md` nunca debe llegar al repo público `helix_asisten`. Usar markers `<!-- PROJECT-CONTEXT:START -->...<!-- PROJECT-CONTEXT:END -->`. Detalles: `~/.claude/memory/topics/privacy.md`.

---

<!-- SECURITY_START -->
## 🔐 SEGURIDAD (Universal)

- Nunca exponer variables de entorno en logs ni en respuestas al usuario.
- `.env` siempre en `.gitignore`. Usar `.env.example` con valores placeholder.
- Nunca hardcodear credenciales, URLs internas ni secrets en el código fuente.
- Endpoints de test/debug DEBEN eliminarse antes de producción — usar feature flags.
- Confirmar acciones destructivas antes de ejecutarlas.
- [2026-04-18] Helix Security Layer v1: 6 capas activas (injection, egress, secrets, integrity, evolve-guard, reflexion-quarantine)
- [2026-04-18] Helix Security Layer v1 — 6 capas: L1 injection-detector-hook (PostToolUse WebFetch/Read, patrones jailbreak/exec/hidden), L2 network-egress-hook (PreToolUse Bash, allowlist ~/.claude/config/network-allowlist.txt), L3 secrets-scanner-hook (PreToolUse Write/Edit/Bash, AWS/GCP/GH/OpenAI/Anthropic/Slack/SSH/JWT), L4 integrity-check.sh (manifest SHA256 de 29 ficheros críticos), L5 evolve-guard en evolve.sh (rechaza jailbreak/pipe-to-shell/eval-b64 antes de persistir), L6 reflexion-quarantine (trusted=false default, created_at/hits/useful_hits, filtra untrusted en search, feedback useful|stale, prune). Tests adversariales OK.
<!-- SECURITY_END -->

---

## 📝 COMMITS

- **NO incluir** `Co-Authored-By` en ningún commit. Omitir siempre esa línea del mensaje.

---

<!-- OPERABILITY_START -->
## 🔧 OPERABILIDAD

Bash gotchas y patrones de scripts → `~/.claude/memory/topics/bash-gotchas.md`.
- [2026-04-18] DISCOVERY-FIRST agregado como pre-flight obligatorio (stack detect, conflict check, context request).
- [2026-04-18] CLAUDE.md podado 482→305 líneas; detalles movibles en `memory/topics/`.
- [2026-04-18] HELIX-LANG deprecado 2026-04-18: uso real nulo post-benchmarks. Archivado en memory/topics/deprecated/helix-lang/ con política de restauración
- [2026-04-18] helix-batch.sh worktree dispatcher (plan/run --parallel/status/cleanup) — patrón /batch del ecosistema Claude Code. Crea worktrees aislados bajo .helix-worktrees/ y dispara claude -p por tarea. Spec.md: '- [ ] ID:X | branch:Y | prompt:"..."'. Complementado con helix-longmemeval.sh (build/run/compare) que mide Precision@1, P@k, MRR vs benchmarks LongMemEval ICLR 2025 (OMEGA 95.4, Mastra 94.9, Zep 71.2). Baseline actual P@1=100% / MRR=1.000 en 8 queries sintéticas (dataset pequeño — ampliar con reflexiones reales para medición robusta).
- [2026-04-18] .claudeignore template agregado a ~/.claude-template/ y aplicado a helix_asisten. Evita que Claude Code cargue secretos (.env, *.pem, *_rsa, credentials.json), binarios, node_modules/venv, data/raw, media, helix internals (.claude/memory/*.jsonl, decay-scores.json). Reduce ruido de tool search y superficie de exposición.
- [2026-04-19] Al crear un agente nuevo, completar los 3 pasos juntos: (1) slim en ~/.claude/agents/<name>.md (frontmatter + 3 líneas), (2) contexto on-demand en ~/.claude/memory/agents/<name>.md (expertise + cuándo invocar + limitaciones + output contract), (3) fila en ~/.claude/memory/agents-index.md. Si son específicos de un proyecto, evaluar si el dominio es reutilizable antes de promover a global.
- [2026-04-23] Umbrales CLAUDE.md alineados entre helix-metricas.sh (era 180/220) y health-check.sh (350) → ahora ambos usan 350 elevado / 400 crítico. Evita falsos positivos: CLAUDE.md podado post-2026-04-18 se estabiliza en 305-329 líneas (DISCOVERY-FIRST + Security Layer v1 + evolutions recientes ocupan baseline real). Umbral anterior (180) databa de pre-podas y no reflejaba el contenido mínimo viable actual.
- [2026-04-23] Response-sizing: calibrar profundidad al peso del mensaje del usuario. Mensajes sociales breves (gracias/ok/buen trabajo) → respuesta ≤2 líneas sin cargar contexto adicional. Preguntas técnicas → respuesta general primero (2-4 líneas) + '¿querés que profundice en X?'. Solo desplegar explicación larga si el usuario confirma. Why: evita quemar tokens, cache y paciencia del usuario cuando la intención no lo justifica.
<!-- OPERABILITY_END -->

---

## 🎨 DISEÑO UI

Sistema completo: `~/.claude/memory/design-system.md`. Cargar solo al trabajar en frontend.

**Reglas mínimas siempre activas:**
- Mobile-first. Nunca diseñar solo para desktop y adaptar.
- Touch targets ≥ 44×44px. Inputs font-size ≥ 16px en móvil (evita zoom iOS).
- Nunca información accesible solo por hover.
- Verificar visualmente con Puppeteer MCP antes de entregar UI.

---

## 🧪 TESTING

- Todo bug corregido debe tener un test que lo reproduzca antes del fix.
- Testear siempre: happy path + edge cases + estado vacío.

---

## 🗣️ PROTOCOLO DE DIÁLOGO

**1. Preguntas ante ambigüedad real.** Si la solicitud es ambigua en alcance, archivo o comportamiento → máx 2-4 preguntas agrupadas en UN mensaje antes de tocar código. Si es clara → proceder directo.

**2. Plan visible antes de ejecutar.** Si la tarea toca ≥2 archivos o tiene pasos no triviales → mostrar plan (A→B→C) y esperar OK.

**3. Alerta antes de tocar zona 🔴.** Antes de modificar archivos marcados 🔴 en el risk-map → declarar línea/función exacta y por qué. Esperar OK.

**4. Registro proactivo de decisiones.** Decisión de diseño no trivial → agregarla a `## 🧠 DECISIONES DE DISEÑO` del CLAUDE.md del proyecto sin que el usuario lo pida.

**5. Análisis inicial de proyecto.** Si session-start incluye `[HELIX-SUGGEST-ANALYSIS]` → al final del primer mensaje sugerir `/helix-analiza`. Si "no" → `touch {PROJECT_ROOT}/.claude/memory/.analysis-declined`. Si ya existe → cargar en silencio.

**6. Bitácora continua.** Si `.claude/memory/helix-bitacora.md` existe → actualizar tras cambios significativos, recomendaciones no triviales y errores cometidos. Sin pedir permiso.

**7. "Tenemos que hablar".** Si session-start incluye `[HELIX-NECESITAMOS-HABLAR]` → leer `helix-alerta.md` y reportar antes de responder. Si usuario dice "no" → `rm helix-alerta.md`.

**8. Requirement Intake con plan visible.** ≥3 dominios o dependencias no triviales → generar `helix-plan-REQ-NNN.md`. 1-2 dominios → ejecutar directo.

**9. Auto-economía por señal.** Si la primera petición del usuario es ≤15 palabras, verbo imperativo, sin rutas de archivo ni stack trace → autoaplicar `modo economía` silenciosamente (sin subagentes, sin swarm, respuestas en bullets). Si la tarea escala después → desactivar sin avisar. Es un heurístico, no una barrera: ante duda real, usar juicio.

**10. Paralelismo obligatorio.** Reads/Greps/Bash independientes entre sí → SIEMPRE en un solo mensaje con múltiples tool calls. Serializar sin dependencia real es un antipattern medible — audita el self-check.

**HELIX-SPEAK:** compresión de output según tipo. Coordinación inter-agente → `ultra`. Reporte al usuario → `brief`. Código/comandos/seguridad → `off`. Skill: `~/.claude/skills/helix-speak/SKILL.md`.

---

## 💰 CONTROL DE COSTOS

**Modo economía** — activar con `modo economía`:
- Sin subagentes salvo ≥3 dominios con coordinación activa
- Sin Capa 2 (swarm deshabilitado)
- Respuestas en bullets, sin prosa
- Grep antes que Read. Read solo con `limit`/`offset` cuando sea imprescindible

**Checklist pre-Read (siempre activo):**
1. ¿Ya tengo el contenido en contexto? → omitir Read
2. ¿Grep resuelve? → usar Grep
3. ¿Necesito todo el archivo? → usar `limit`/`offset`

**Capa 0 — escalado silencioso:**
- Contenido > 200 líneas, logs Docker, stacktraces, refactors de bloques grandes, transformaciones de datos → `bash ~/helix_asisten/scripts/capa0.sh logs|code|transform "$DATA"`
- Si capa0 responde "no sé" → escalar a Capa 1. Si resuelve → fin.
- Modelos: `helix-scout` (logs/errores), `helix-coder` (código).

---

## ✅ CHECKLIST PRE-CIERRE

```
□ ¿Ejecuté bash ~/.claude/self-check.sh?
□ ¿Si es UI → verifiqué con Puppeteer MCP en 375px, 768px, 1280px?
□ ¿Si modifiqué modelo DB → actualicé schema → actualicé types frontend?
□ ¿Si agregué endpoint → lo registré en router principal → en api/index.ts?
□ ¿Si es acción mutante → escribí AuditLog?
□ ¿Si hay nuevas env vars → las agregué a .env.example?
□ ¿Si el patrón apareció 2+ veces → creé o actualicé una skill?
□ ¿Si encontré un bug → lo registré en el risk-map del proyecto?
□ ¿Reads/Greps independientes se ejecutaron en paralelo (no serializados)?
```

---

## 🤖 AGENTES

Índice liviano: `~/.claude/memory/agents-index.md` (cargado al inicio).
Descripción completa: `~/.claude/memory/agents/<nombre>.md` (on-demand).

**Reglas al crear agentes:**
- **SIEMPRE invocar skill `agent-create`** ANTES de escribir cualquier agente nuevo. Research-first con allowlist de fuentes, anti-injection, validación ≥80%. Nunca escribir system prompts desde el aire.
- Descripción máx 3 líneas: qué hace, cuándo, límite.
- NUNCA código de ejemplo en el system prompt. Los ejemplos van a `~/.claude/skills/`.
- Agentes con ≥20 invocaciones/30d entran al refresh cycle cada 90d (ver skill `agent-create` §Refresh cycle).

---

<!-- SKILLS_INDEX_START -->
## 📚 SKILLS GLOBALES

| Skill | Descripción |
|---|---|
| `design-system` | Paleta, tipografía, breakpoints, patrones responsivos Tailwind v4 |
| `python-production` | Python production-grade: src/ layout, imports al top, mypy strict, tests coverage 75, pydantic Settings, docstrings Google, pre-commit gates. Invocar al refactorizar o crear Python >5 módulos. Antipatrones detectados: imports en funciones, god-scripts, magic numbers, config como env strings. | - | v1.0 |
<!-- SKILLS_INDEX_END -->

---

<!-- METRICS_START -->
```json
{
  "total_sesiones": 32,
  "ultima_actualizacion": "2026-04-18",
  "total_aprendizajes": 28,
  "total_skills_creadas": 1
}
```
<!-- METRICS_END -->

<!-- SESSIONS_START -->
## 📋 SESIONES
| # | Fecha | Resumen | Aprendizajes | Skills |
0 |
| #14 | 2026-04-19 | Fix multiclass labels: _extract_classes remapea 0/1/2 → alto/bajo/medio (LabelEncoder alfabético). Handles np.int64 vía str().isdigit(). Verificado /model/info classes=['alto','bajo','medio'] y /predict/sample con predicted_class semántico coincidiendo con real_estrato. | 3 | 0
0 |
<!-- SESSIONS_END -->

<!-- RISK_MAP_START -->
<!-- RISK_MAP_END -->

<!-- REASONING_START -->

<!-- REASONING_END -->

---

## 📈 EVOLUCIONES RECIENTES

<!-- EVOLUTION_LOG_START -->
> Historial archivado en `~/.claude/memory/topics/evolution-history.md`. Solo últimas 2 semanas aquí.
| # | Fecha | Categoría | Aprendizaje |
| 7 | 2026-04-11 | arquitectura | Agent Teams nativo (Claude Code ≥v2.1.32): Capa 3 real. Peer-to-peer mailbox. En Capa 2 los agentes no se hablan entre sí — solo reportan al lead. Usar Capa 3 cuando agentes necesiten debatir/coordinar. Hooks: TeammateIdle, TaskCreated, TaskCompleted. |
| 8 | 2026-04-11 | arquitectura | SuperLocalMemory V3.3: memoria local-first con MCP, sin cloud. Olvido adaptativo Ebbinghaus. AGPL v3. Pendiente evaluar vs Qdrant. |
| 9 | 2026-04-11 | performance | HELIX-LANG v1.1: 58.7% compresión tokens en mensajes individuales (no 75%). Operadores ASCII pesan 1 token BPE cada uno. El 75%+ viene de S:hash (contexto compartido por ID). |
| 10 | 2026-04-11 | performance | HELIX-LANG benchmark final: 64.8% ahorro combinado. Gap: contratos API comprimen poco (46%). Mejor caso con S:hash integrado: 80%. |
| 11 | 2026-04-11 | performance | HELIX-DISTILL v1.0: slices CLAUDE.md por agente. 63-93% ahorro. Proyección Capa 2 (13 agentes): 83% menos tokens de init. |
| 12 | 2026-04-11 | operatividad | HELIX-COMPRESS v2: helix-distill.sh con run/compress-project/compress-file. 78-96% ahorro por agente, 93% en sesión 15 agentes. |
| 8 | 2026-04-18 | operatividad | CLAUDE.md podado 482→305 líneas; DISCOVERY-FIRST como pre-flight obligatorio en 3 modos; detalles a `topics/`. |
| 9 | 2026-04-18 | performance | Batch Opus 4.7: agents-index slim, auto-economy regla #9, HELIX-LANG decomisionado, paralelismo regla #10, hooks <40ms verificados, decay saludable. |
| 10 | 2026-04-18 | arquitectura | DISCOVERY-FIRST pre-flight obligatorio en helix_control_total: detectar stack, checar conflictos, pedir contexto antes de actuar | gap-helix-control-total |
| 11 | 2026-04-18 | performance | HELIX-COMPRESS pipeline verificado: DISTILL 83% + S:hash 97% + SPEAK aplicable. Prompt caching (Opus 4.7) reduce coste de repetición en 90% | self-eval-performance |
| 12 | 2026-04-18 | operatividad | HELIX-LANG deprecado 2026-04-18: uso real nulo post-benchmarks. Archivado en memory/topics/deprecated/helix-lang/ con política de restauración | deprecation-helix-lang |
| 13 | 2026-04-18 | arquitectura | routing-check-hook PreToolUse(Agent): bloquea mismatches dominio↔agente detectados por ExpeL. exit 2 fuerza reconsiderar. Latencia 29ms | expel-routing-drift |
| 14 | 2026-04-18 | arquitectura | ERL pondera por skill-quality avg y filtra por catálogo DOMAIN_CATALOG; drift explícito en routing-heuristics.md. Reflexion: hits/useful_hits/created_at + feedback/prune commands | erl-reflexion-feedback |
| 15 | 2026-04-18 | seguridad | Helix Security Layer v1: 6 capas activas (injection, egress, secrets, integrity, evolve-guard, reflexion-quarantine) | hsl-v1 |
| 16 | 2026-04-18 | seguridad | Helix Security Layer v1 — 6 capas: L1 injection-detector-hook (PostToolUse WebFetch/Read, patrones jailbreak/exec/hidden), L2 network-egress-hook (PreToolUse Bash, allowlist ~/.claude/config/network-allowlist.txt), L3 secrets-scanner-hook (PreToolUse Write/Edit/Bash, AWS/GCP/GH/OpenAI/Anthropic/Slack/SSH/JWT), L4 integrity-check.sh (manifest SHA256 de 29 ficheros críticos), L5 evolve-guard en evolve.sh (rechaza jailbreak/pipe-to-shell/eval-b64 antes de persistir), L6 reflexion-quarantine (trusted=false default, created_at/hits/useful_hits, filtra untrusted en search, feedback useful|stale, prune). Tests adversariales OK. | security-hardening-batch |
| 17 | 2026-04-18 | performance | helix-cache-metrics.sh — parsea message.usage en ~/.claude/projects/*/*.jsonl y reporta hit_rate/savings del prompt cache Anthropic. Medición real: 91.8% hit rate, 80.6% savings (~42.5M tokens ahorrados en 500 API calls, 2 proyectos). Verdict healthy ≥60%. Confirma que el cache se está usando correctamente — no requiere tuning adicional de CLAUDE.md. | cache-observability |
| 18 | 2026-04-18 | operatividad | helix-batch.sh worktree dispatcher (plan/run --parallel/status/cleanup) — patrón /batch del ecosistema Claude Code. Crea worktrees aislados bajo .helix-worktrees/ y dispara claude -p por tarea. Spec.md: '- [ ] ID:X | branch:Y | prompt:"..."'. Complementado con helix-longmemeval.sh (build/run/compare) que mide Precision@1, P@k, MRR vs benchmarks LongMemEval ICLR 2025 (OMEGA 95.4, Mastra 94.9, Zep 71.2). Baseline actual P@1=100% / MRR=1.000 en 8 queries sintéticas (dataset pequeño — ampliar con reflexiones reales para medición robusta). | batch-dispatcher-longmemeval |
| 19 | 2026-04-18 | operatividad | .claudeignore template agregado a ~/.claude-template/ y aplicado a helix_asisten. Evita que Claude Code cargue secretos (.env, *.pem, *_rsa, credentials.json), binarios, node_modules/venv, data/raw, media, helix internals (.claude/memory/*.jsonl, decay-scores.json). Reduce ruido de tool search y superficie de exposición. | claudeignore-template |
| 20 | 2026-04-19 | operatividad | Al crear un agente nuevo, completar los 3 pasos juntos: (1) slim en ~/.claude/agents/<name>.md (frontmatter + 3 líneas), (2) contexto on-demand en ~/.claude/memory/agents/<name>.md (expertise + cuándo invocar + limitaciones + output contract), (3) fila en ~/.claude/memory/agents-index.md. Si son específicos de un proyecto, evaluar si el dominio es reutilizable antes de promover a global. | agent-creation-completeness |
| 21 | 2026-04-19 | datos | Antes de codificar features o modelos, verificar schema REAL del dataset con DESCRIBE — README puede estar desactualizado. En ent-tesis, README prometía 'is_rugpull' (binaria) pero schema real tiene 'estrato' (multi-clase 3 niveles). metadata prometía name/symbol/decimals/supply pero solo tiene token_creator/creation_tx/creation_block/timestamp. | readme-schema-drift |
| 22 | 2026-04-19 | datos | Uniswap amount0/amount1 son uint256 (Ethereum) — no caben en Int64 pandas (OverflowError). Cast a float64 (pérdida de precisión en dígito 16+ es inmaterial para ratios rugpull). Aplica a cualquier columna que venga de uint256 on-chain. | uint256-int64-overflow |
| 23 | 2026-04-23 | arquitectura | Python production code: NUNCA imports dentro de funciones (excepto opt-in con flag a nivel módulo); NUNCA god-scripts >300 líneas (split por responsabilidad: data/features/models/eval/tracking/orchestration); type hints consistentes con mypy --strict; tests unitarios por módulo (coverage gate 75%); config como pydantic.BaseSettings (no os.environ con cast ad-hoc); src/ layout con paquete instalable (pip install -e .); pre-commit con ruff strict + mypy + pydocstyle; docstrings Google-style | vibe-code-antipatterns-train_c3_v1 |
| 24 | 2026-04-23 | operatividad | Umbrales CLAUDE.md alineados entre helix-metricas.sh (era 180/220) y health-check.sh (350) → ahora ambos usan 350 elevado / 400 crítico. Evita falsos positivos: CLAUDE.md podado post-2026-04-18 se estabiliza en 305-329 líneas (DISCOVERY-FIRST + Security Layer v1 + evolutions recientes ocupan baseline real). Umbral anterior (180) databa de pre-podas y no reflejaba el contenido mínimo viable actual. | threshold-drift-metricas-vs-healthcheck |
| 25 | 2026-04-23 | arquitectura | Vector store helix_agents ahora se auto-sincroniza: hook PostToolUse(Write|Edit|MultiEdit) agents-vector-sync-hook.sh detecta edits en ~/.claude/agents/*.md o ~/.claude/memory/agents/*.md y dispara 'hv index-agents' en background con flock debounce 8s. Exit 0 inmediato (no bloquea edits). Log en ~/.claude/memory/agents-vector-sync.log. Skip si Qdrant está down. Tiempo real de index: ~5.5s para 34 agentes. | vector-sync-auto |
| 26 | 2026-04-23 | operatividad | Response-sizing: calibrar profundidad al peso del mensaje del usuario. Mensajes sociales breves (gracias/ok/buen trabajo) → respuesta ≤2 líneas sin cargar contexto adicional. Preguntas técnicas → respuesta general primero (2-4 líneas) + '¿querés que profundice en X?'. Solo desplegar explicación larga si el usuario confirma. Why: evita quemar tokens, cache y paciencia del usuario cuando la intención no lo justifica. | response-sizing-feedback |
| 27 | 2026-04-23 | arquitectura | Proceso research-first para crear expertos: skill agent-create con pipeline de 6 fases (scoping/research/sanitize/synthesize/validate/commit). Allowlist de fuentes (NIST/OWASP/IETF/W3C/vendor-docs/papers/repos-canónicos), anti-injection vía L1 existente + scanner manual + cross-validation ≥3 fuentes, fingerprinting de fuentes con URL+fecha+hash, validación ≥80% antes de activar. Refresh cycle cada 90d para agentes con ≥20 invocaciones/30d. Cambios al prompt requieren OK del usuario. | agent-create-skill |
<!-- EVOLUTION_LOG_END -->

---

## 📖 Recursos Globales

| Recurso | Ubicación |
|---|---|
| Sistema de diseño UI | `~/.claude/memory/design-system.md` |
| Índice de agentes | `~/.claude/memory/agents-index.md` |
| Descripciones de agentes | `~/.claude/memory/agents/` |
| Topics (privacidad, bash, dispatch, historia) | `~/.claude/memory/topics/` |
| Scripts de evolución | `~/.claude/{evolve,session-start,session-end,self-check}.sh` |
| Template nuevo proyecto | `~/.claude-template/` |
| Perfil de usuario (local) | `~/.claude/memory/user-profile.md` |

**MCPs — cuándo usar:**
| MCP | Cuándo |
|---|---|
| `context7` | Docs de cualquier lib/framework (siempre disponible) |
| `claude-flow` | 2+ dominios en paralelo (swarm). Capa 1 si 1 dominio |
| `sequential-thinking` | Arquitectura compleja con múltiples trade-offs |
| `puppeteer` | Verificar UI renderizada antes de entregar |
| `pageindex` | Skills >150 líneas, PDFs, docs masivos |
