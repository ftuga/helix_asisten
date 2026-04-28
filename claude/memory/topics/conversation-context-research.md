# Research — Manejo de Conversación y Contexto

> Documentación preparatoria para la decisión de diseño sobre persistencia conversacional, recuperación tras crash y compactación inteligente. Compilado 2026-04-27. Para discusión a fondo en próxima sesión.

---

## Parte 1 — Helix interno (lo que ya existe)

### Scripts de sesión activos

| Archivo | Función |
|---|---|
| `~/.claude/session-start.sh` | Carga contexto al inicio, inyecta flags `[HELIX-SUGGEST-*]` |
| `~/.claude/session-end.sh` | Cierre con resumen, archiva evoluciones viejas |
| `~/.claude/helpers/session-exit-hook.sh` | Hook UserPromptSubmit detecta exit/salir/bye |
| `~/.claude/helpers/helix-retrospectiva.sh` | Reflexión post-tarea (no medido uso real) |
| `~/.claude/helpers/helix-cache-metrics.sh` | Mide hit rate del prompt cache (91.8% medido en evolución #17) |
| `~/.claude/helpers/helix-claude-md-prune.sh` | Auto-archive evoluciones >14d |

### Skills relevantes

- **`strategic-compact`**: hook PreToolUse que sugiere `/compact` al alcanzar 50 tool calls y cada 25 después. **Solo sugiere**, no preserva nada. No interviene en el contenido del compact.
- **`context-budget`**: audita tokens de componentes (agentes, skills, reglas, MCP) — no toca conversación.

### Bitácoras / persistencia de proyecto (NO de conversación)

| Archivo | Captura |
|---|---|
| `helix-bitacora.md` | Decisiones de diseño, errores, recomendaciones |
| `helix-backlog.md` | Tareas en progreso/completadas/bloqueadas |
| `helix-analysis.md` | Análisis inicial del proyecto |
| `helix-plan-REQ-NNN.md` | Planes de requirement intake |
| `helix-team.md` | Definición de equipo si aplica |

**Importante**: las bitácoras capturan **el qué** del proyecto, no **el hilo conversacional**. Son ortogonales.

### Transcripts crudos disponibles

- Ubicación: `~/.claude/projects/<project>/<session-uuid>.jsonl`
- En proyecto actual `helix_asisten`: 22 transcripts almacenados
- Cada línea es un evento JSON: tool calls (input + output completo), thinking blocks, subagent spawns, token usage, model, cwd, git state
- **No hay parser propio** — los datos están pero ningún helper los usa hoy
- Existe `sessions-index.json` con metadata + auto-summary que Claude Code genera

### Lo que NO existe en Helix

- Parser de transcripts jsonl
- Snapshot capture al cierre/intermedio
- Resume helper más allá del fragmento que muestra session-start
- Observation masking de tool results viejos
- Pinning de exchanges críticos
- Detección de "esto es de hace N sesiones, posiblemente stale"
- Integración con frameworks de memoria externa (Mem0, Zep, Letta)

---

## Parte 2 — Estado del arte externo

### Claude Code: formato y manejo nativo

Los transcripts ya están estructurados y son explotables:

- `~/.claude/projects/<project>/<uuid>.jsonl` + `sessions-index.json`
- Auto-compactación cuando se acerca al límite del contexto: genera summary y reemplaza mensajes viejos
- Anthropic SDK provee compactación nativa: summary estructurado de 7-12k chars con secciones (analysis, files, pending tasks, current state)
- Existen utilidades third-party como `claude-code-transcripts` (Simon Willison) que convierten jsonl a HTML navegable

**Implicación**: el harness ya hace compaction. Lo que se puede mejorar es **complementarlo con persistencia paralela** (snapshot estructurado fuera del transcript).

### LongMemEval (ICLR 2025)

Benchmark canónico para memoria de largo plazo en chat assistants. **5 habilidades evaluadas:**

1. Information extraction (sacar datos de turnos viejos)
2. Multi-session reasoning (razonar sobre N sesiones)
3. Temporal reasoning (orden cronológico, antes/después)
4. Knowledge updates (cuándo info vieja fue reemplazada)
5. Abstention (saber cuándo decir "no recuerdo")

**Hallazgo crítico**: chat assistants comerciales y LLMs long-context tienen **30% drop de accuracy** sobre interacciones sostenidas. 500 preguntas curadas, dataset escalable.

**Framework propuesto**: 3 etapas — indexing (session decomposition + fact-augmented keys), retrieval (time-aware query expansion), reading (focused).

Aplicable al diseño Helix: las habilidades #4 (knowledge updates) y #5 (abstention) son las que cubrirían el caso "esto es de hace N días, puede estar stale".

### Mem0 (paper arXiv 2504.19413)

Memory infrastructure layer para agentes. **Resultados:**

- 91% reducción p95 latency
- 90% reducción de token cost
- Graph-based memory representations (relaciones entre conversaciones)
- 21 frameworks integrados (Python + TypeScript)
- 19 vector stores soportados
- 3 modelos de hosting: managed cloud, self-hosted, local MCP

**Arquitectura conceptual**: capa entre agente y storage, gestiona ciclo de vida (extract → consolidate → retrieve). Drop-in con minimal cambio en pipeline.

**Tradeoff para Helix**: integrar Mem0 da memoria persistente cross-session de forma probada, pero **agrega dependencia externa** y un servicio. Helix ya tiene Qdrant local + `hv` CLI — capacidad similar pero sin la capa de gestión inteligente.

### Estrategias de compactación SOTA

Resumen de la literatura 2025:

| Estrategia | Cómo funciona | Pros | Contras |
|---|---|---|---|
| **Observation masking** | Reemplaza outputs viejos con placeholders, conserva tool calls | Bajo cómputo, match LLM summary en SWE-bench | Contexto crece sin tope si turnos crecen sin tope |
| **LLM summarization** | Otro modelo genera summaries de chunks viejos | Escala infinito en teoría | Hallucinaciones, paraphrase de detalles técnicos |
| **Structured summarization** | Summary con secciones obligatorias (analysis/files/tasks/state) | Anthropic-style, más fiel | Más expensive, requiere schema bien definido |
| **ACON** | Optimización paired-trajectory + failure-driven guidelines | 26-54% reducción memoria, gradient-free, mantiene 95% accuracy | Research framework, no off-the-shelf |
| **Provider-native** | OpenAI `/responses/compact` (99.3% compression, opaco), Anthropic SDK (interpretable) | Probado en producción | Vendor lock-in, opacidad en algunos |

**Hallazgo de Factory.ai (2026)**: en sesiones largas reales (debugging, code review, feature implementation), **structured summarization retiene más información útil** que las alternativas de OpenAI o Anthropic.

**Hallazgo de la industria**: ~65% de fallos enterprise de AI agents en 2025 atribuidos a **context drift o memory loss** durante multi-step reasoning. No es opcional.

### Anthropic prompt caching (2026)

Datos relevantes para la propuesta Helix:

- **Workspace-level isolation** desde 2026-02-05 (antes era org-level)
- **Multi-turn automático**: el SDK mueve el effective prefix boundary forward conforme crece la conversación
- **70-90% cost reduction** medido, **85% latency reduction** en prompts largos
- **Hard requirement**: para que cache funcione, el contenido flagged como cacheable debe ser **idéntico** entre requests (un char distinto rompe el hit)
- **Thinking blocks** se cachean como parte del request content cuando se pasan en subsequent calls

**Implicación para Helix**: el prompt cache ya da 90% savings en input. Lo que NO cubre es el **output** (siempre full price) ni el **estado de la conversación** entre sesiones. HELIX-LANG ataca el primero. Snapshot persistente atacaría el segundo.

---

## Parte 3 — Análisis de gaps Helix vs SOTA

| Capacidad SOTA | Helix tiene? | Gap |
|---|---|---|
| Compactación al llegar al límite | Sí (nativo Claude Code) | Ninguno — usa el del harness |
| Sugerir compact en momento estratégico | Sí (`strategic-compact`) | Solo sugiere, no preserva |
| Métricas de cache hit | Sí (`helix-cache-metrics`) | OK |
| Snapshot conversacional persistente | **No** | Gap clave |
| Resume opt-in al inicio | **No** | Gap clave |
| Observation masking de tool results viejos | **No** | Gap |
| Structured summary tipo Anthropic SDK | Parcial (bitácora cubre proyecto, no conversación) | Gap |
| Detección de staleness en memoria conversacional | **No** | Gap (existe para git/files) |
| Memory benchmarking estilo LongMemEval | Sí (`helix-longmemeval.sh` existe pero dataset pequeño) | Necesita dataset real |
| Pinning explícito de exchanges | **No** | Gap |
| Integración con Mem0 / Zep | **No** | Decisión de diseño abierta |

---

## Parte 4 — Decisiones de diseño abiertas

A discutir en próxima sesión a fondo:

### D1: Build vs integrate

- **Build propio**: snapshot YAML estructurado en `~/.claude/snapshots/<project>/<session>.yaml`. Simple, sin deps, alineado al stack actual de Helix.
- **Integrar Mem0**: drop-in, probado, 90% token cost saving, pero agrega servicio + complejidad.

Recomendación inicial: empezar build propio (3-4 helpers + 1 hook), medir, escalar a Mem0 solo si insuficiente.

### D2: Estrategia de compactación

- **Observation masking** (estilo OpenHands): conservar tool calls, masking outputs viejos. Bajo cómputo, alineado con regla actual de "tool result >500 chars que no se referenció en 5 turnos → collapse".
- **Structured summary** (estilo Anthropic SDK + Factory.ai): summary con secciones obligatorias.
- **Mixed**: masking durante la sesión, structured summary al cierre.

Recomendación inicial: mixed. Masking en runtime es barato; summary al cierre se hace una vez.

### D3: Triggers de capture

| Opción | Cuándo |
|---|---|
| Hook `Stop` | Al cerrar sesión normalmente |
| Cron cada N minutos | Anti-crash (WSL2 muere sin warning) |
| Cada N tool calls | Híbrido: cron pero adaptativo |
| Manual `helix-snapshot capture` | Bajo demanda |

Recomendación inicial: Hook Stop + cron cada 30 min como red de seguridad.

### D4: Estrategia de resume

- **Opt-in explícito** (preferido del usuario, ya conversado): flag `[HELIX-SUGGEST-RESUME]` en session-start, pregunta al final del primer mensaje.
- **Carga slim**: solo summary ejecutivo (5-10 líneas, ~500 tokens). Detalles on-demand.
- **Marcado de staleness**: timestamp + warning si >24h o commits posteriores.

### D5: Schema del snapshot

Borrador inicial:

```yaml
session_id: <uuid>
project: <name>
started: <iso>
last_update: <iso>
status: in_progress | completed | crashed
summary: <2-3 líneas, esto es lo que carga al resume>
current_task: <1 línea>
completed_today: [hitos]
pending: [...]
critical_decisions: [acuerdos con el usuario]
open_questions: [...]
files_modified: count + lista
evolutions_registered: count + lista
tool_calls: count
estimated_tokens_used: <int>
```

### D6: Cuándo invalidar snapshot

- Por edad: >7 días → mover a archive
- Por staleness: >N commits posteriores → flag
- Por superseding: nueva sesión completada del mismo proyecto reemplaza la anterior

### D7: Privacidad

Snapshots pueden contener info del proyecto. Aplican mismas reglas que `memory/agents/*.md`:
- Nunca commitear al repo público
- Markers ``
- Excluir credentials, paths internos, IPs

---

## Parte 5 — Sources externas consultadas

- [Claude Code session format — Yi Huang, Medium 2026-02](https://databunny.medium.com/inside-claude-code-the-session-file-format-and-how-to-inspect-it-b9998e66d56b)
- [Work with sessions — Claude Code Docs](https://code.claude.com/docs/en/agent-sdk/sessions)
- [LongMemEval ICLR 2025 paper](https://arxiv.org/abs/2410.10813)
- [LongMemEval GitHub](https://github.com/xiaowu0162/LongMemEval)
- [Mem0 paper arXiv 2504.19413](https://arxiv.org/abs/2504.19413)
- [Mem0 framework](https://mem0.ai/)
- [State of AI Agent Memory 2026 — Mem0 blog](https://mem0.ai/blog/state-of-ai-agent-memory-2026)
- [Compaction — Microsoft Agent Framework docs](https://learn.microsoft.com/en-us/agent-framework/agents/conversations/compaction)
- [Smarter Context Management — JetBrains Research](https://blog.jetbrains.com/research/2025/12/efficient-context-management/)
- [Evaluating Context Compression — Factory.ai](https://factory.ai/news/evaluating-compression)
- [ACON paper — arXiv 2510.00615](https://arxiv.org/html/2510.00615v1)
- [Compaction vs Summarization — Morph](https://www.morphllm.com/compaction-vs-summarization)
- [Anthropic prompt caching 2026 — AICheckerHub](https://aicheckerhub.com/anthropic-prompt-caching-2026-cost-latency-guide)
- [Prompt caching — Claude API Docs](https://platform.claude.com/docs/en/build-with-claude/prompt-caching)

---

## Parte 6 — Mi posición tentativa (a confirmar)

Para discusión a fondo, mi posición inicial:

1. **Build propio**, no integrar Mem0 todavía. Stack interno (yaml + helpers + hooks) cubre 80% del valor con 20% de la complejidad. Mem0 solo si después se mide insuficiencia clara.

2. **Mixed compaction**: observation masking en runtime (collapse de tool results >500 chars no referenciados en 5 turnos), structured summary al cierre vía `helix-snapshot capture`.

3. **Opt-in al resume**, no auto-load. Flag `[HELIX-SUGGEST-RESUME]` + regla de diálogo nueva.

4. **Triggers múltiples**: hook Stop + cron 30 min + manual.

5. **Schema YAML estructurado**, no vector. Vector solo si se mide que retrieval semántico de snapshots viejos da valor real.

6. **Staleness automático**: cada snapshot lleva timestamp; si >24h o commits posteriores, warning automático al usar.

Tiempo estimado de implementación end-to-end: ~4-6 horas (1 sesión dedicada).

---

## Estado del documento

- [x] Inventario interno
- [x] Research externo (5 dimensiones)
- [x] Análisis de gaps
- [x] Decisiones abiertas listadas
- [x] Sources documentadas
- [ ] Decisión final del usuario
- [ ] Plan de implementación priorizado
- [ ] Tests y métricas de validación
