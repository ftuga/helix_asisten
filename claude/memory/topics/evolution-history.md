
## Archivado 2026-03-08 20:58 — Historial evoluciones
| 0 | INIT | sistema | Ecosistema de auto-evolución inicializado | Configuración inicial |
| 1 | 2026-03-08 | operatividad | sed falla con caracteres especiales : , # | — usar python3 con env vars para manipulación de texto en bash | bug en evolve.sh sesión #1 |
| 2 | 2026-03-08 | operatividad | test desde fuera de proyecto | prueba auto-detección |

## Archivado 2026-03-08 20:58 — Historial evoluciones
| 0 | INIT | sistema | Ecosistema de auto-evolución inicializado | Configuración inicial |
| 1 | 2026-03-08 | operatividad | Skills globales disponibles: fastapi-async, celery-redis, react-query-patterns, docker-compose, frontend-design | configuración inicial ecosistema |
| 2 | 2026-03-08 | operatividad | sed falla con caracteres especiales como : , # | en strings — siempre usar python3 para manipulación de texto en scripts bash | bug en evolve.sh sesión #1 |

## Archivado 2026-03-08 21:08 — Historial evoluciones
| 3 | 2026-03-08 | operatividad | test desde raíz del proyecto | prueba dual-write |
| 4 | 2026-03-08 | operatividad | test desde fuera de proyecto | prueba auto-detección |

## Archivado 2026-03-08 21:08 — Historial evoluciones
| 1 | 2026-03-08 | operatividad | sed falla con caracteres especiales : , # | — usar python3 con env vars para manipulación de texto en bash | bug en evolve.sh sesión #1 |
| 3 | 2026-03-08 | operatividad | test desde raíz del proyecto | prueba dual-write |

## Archivado 2026-03-08 21:37 — Historial evoluciones
| 5 | 2026-03-08 | docker | test dual-write desde proyecto | prueba dual-write |
| 6 | 2026-03-08 | operatividad | set -euo pipefail: [[ -n '' ]] && cmd devuelve exit 1 cuando condición es falsa — usar if/fi en lugar de && para comandos condicionales | bug en evolve.sh dual-write |
| 7 | 2026-03-08 | operatividad | Los marcadores de sección en CLAUDE.md usan nombres en inglés (OPERABILITY, SECURITY, etc.) pero las categorías de evolve.sh son en español — siempre mapear con case/esac antes de construir el marcador | bug categorías español/inglés en evolve.sh |

## Archivado 2026-03-08 21:37 — Historial evoluciones
| 5 | 2026-03-08 | docker | test dual-write desde proyecto | prueba dual-write |
| 6 | 2026-03-08 | operatividad | set -euo pipefail: [[ -n '' ]] && cmd devuelve exit 1 cuando condición es falsa — usar if/fi en lugar de && para comandos condicionales | bug en evolve.sh dual-write |
| 7 | 2026-03-08 | operatividad | Los marcadores de sección en CLAUDE.md usan nombres en inglés (OPERABILITY, SECURITY, etc.) pero las categorías de evolve.sh son en español — siempre mapear con case/esac antes de construir el marcador | bug categorías español/inglés en evolve.sh |

## Archivado 2026-03-20 11:52 — Historial evoluciones
| 1 | 2026-03-08 | operatividad | `VAR=$((VAR + 1))` — `((VAR++))` falla con set -euo pipefail cuando VAR=0 |
| 2 | 2026-03-08 | operatividad | `wc -l` devuelve espacios — siempre limpiar con `tr -d '[:space:]'` |
| 3 | 2026-03-08 | operatividad | `git diff HEAD` sin filtro captura CLAUDE.md — filtrar con `-- '*.ts' '*.tsx'` |

## Archivado 2026-03-20 12:08 — Historial evoluciones
| 4 | 2026-03-08 | operatividad | Pasar strings a Python desde bash: usar variables de entorno, no escaping |
| 5 | 2026-03-14 | arquitectura | CLAUDE.md global = reglas universales. CLAUDE.md proyecto = reglas específicas. No mezclar. |
| 5 | 2026-03-20 | interfaz | Preguntar antes de actuar: máx 2-4 preguntas agrupadas cuando solicitud es ambigua en alcance/archivo/comportamiento | usuario-solicitud-mejora |
| 6 | 2026-03-20 | interfaz | Plan visible antes de ejecutar: mostrar A→B→C y esperar OK cuando tarea toca ≥2 archivos | usuario-solicitud-mejora |
| 7 | 2026-03-20 | interfaz | Umbral de confianza: 'autonomía alta' ejecuta sin preguntar, 'autonomía baja' confirma cada paso | usuario-solicitud-mejora |
| 8 | 2026-03-20 | interfaz | Alerta antes de zona : declarar qué línea/función se va a cambiar y esperar confirmación | usuario-solicitud-mejora |

## Archivado 2026-04-01 00:12 — Historial evoluciones
| 9 | 2026-03-20 | interfaz | Exploración antes de implementación: proponer ≤3 opciones en features nuevas, implementar directo en bugs/tasks concretas | usuario-solicitud-mejora |

## Archivado 2026-04-05 — Pre-v3.11 (sesiones 2026-03-20 y 2026-03-27)
| 10 | 2026-03-20 | interfaz | Registro proactivo de decisiones de diseño no triviales en DECISIONES DE DISEÑO del CLAUDE.md del proyecto | usuario-solicitud-mejora |
| 11 | 2026-03-20 | interfaz | Análisis inicial de proyecto: si [HELIX-SUGGEST-ANALYSIS] en session-start → preguntar una vez, ejecutar /helix-analiza si acepta, crear .analysis-declined si rechaza | usuario-solicitud |
| 12 | 2026-03-20 | interfaz | Bitácora de proyecto: mantener helix-bitacora.md con cambios/recomendaciones/errores — actualización silenciosa sin pedir permiso | usuario-solicitud |
| 10b | 2026-03-20 | performance | Modo economía: sin subagentes, sin swarm, Grep antes que Read — activar con 'modo economía' o /economia | usuario-solicitud |
| 11b | 2026-03-20 | performance | Checklist pre-Read: verificar si ya está en contexto, usar Grep primero, usar limit/offset — siempre activo | usuario-solicitud |
| 12b | 2026-03-20 | performance | Umbral subagentes: 1 dominio → yo solo. 2 dominios → 1 subagente. 3+ dominios con coordinación → Capa 2 | usuario-solicitud |
| 13 | 2026-03-20 | performance | helix-metricas.sh: 3 dimensiones observables (contexto/calidad/overhead) para auto-evaluar salud de Helix — score <60 dispara alerta | usuario-solicitud |
| 14 | 2026-03-20 | operatividad | Pipeline salud: session-end evalúa métricas → escribe helix-alerta.md → session-start emite [HELIX-NECESITAMOS-HABLAR] → Helix reporta antes de cualquier tarea | usuario-solicitud |
| 15 | 2026-03-20 | arquitectura | Memoria híbrida para análisis de proyecto: resumen ≤150 palabras en archivo + detalles en vector memory (MCP) o helix-analysis-full.md (fallback file) | usuario-solicitud |
| 16 | 2026-03-27 | arquitectura | 2+ dominios en paralelo → Capa 2 (swarm_init + agent_spawn), NO Agent tool en paralelo. Agent tool = invisible en ruflow. Swarm = visible en dashboard ruflow (contador N/15) | usuario-solicitud |

## Archivado 2026-04-05 — v3.10.x (auto-evolución 2026-04-02)
| 17 | 2026-04-02 | arquitectura | ERL: helix-erl.sh analiza routing-feedback.jsonl → routing-heuristics.md. Semanal en retrospectiva |
| 18 | 2026-04-02 | arquitectura | Reflexion store: helix-reflexion.sh → Qdrant helix_reflexions. Search semántico antes de error-detective, threshold 0.76 |
| 19 | 2026-04-02 | performance | ACON compress: importance scoring 0-1, anchor sections (SECURITY, OPERABILITY, SKILLS_INDEX) nunca comprimir |
| 20 | 2026-04-02 | operatividad | skill-tracker.sh log/report/prune → skill-usage.jsonl |
| 21 | 2026-04-02 | operatividad | helix-retrospectiva.sh v2: ERL semanal + gap analysis + Reflexion store sugerido |
| 22 | 2026-04-02 | operatividad | skill-tracker-hook + agent-routing-hook auto-registran uso en skill-usage.jsonl |
| 23 | 2026-04-02 | arquitectura | ExpeL: helix-expel.sh detecta dominancia, routing incorrecto, agentes fuera de catálogo |
| 24 | 2026-04-02 | arquitectura | helix-routing-fix.sh: aplica correcciones ExpeL+ERL a agents-index |
| 25 | 2026-04-02 | operatividad | helix-decay.sh: confidence decay evolution-log. Score = recencia×0.4 + importancia×0.6. PERENNIAL nunca decae |
| 26 | 2026-04-02 | arquitectura | helix-knowledge-map.sh: mapa learnings×heurísticas×reflexiones×decay. Gaps críticos = cobertura <30% |
| 27 | 2026-04-02 | operatividad | session-start recupera Qdrant helix_reflexions con stack del proyecto como query |

## Archivado 2026-04-11 01:51 — Historial evoluciones
|---|---|---|---|

## Archivado 2026-04-18 — pre-v3.11 (2026-04-05)
| # | Fecha | Categoría | Aprendizaje |
|---|---|---|---|
| 28 | 2026-04-05 | arquitectura | Project Team Protocol v3.11: helix-analiza genera helix-team.md (roster+output contracts+DoD+dispatch), helix-backlog.md y helix-roadmap.md. Team Dispatch descompone reqs por dominio y despacha en paralelo. |
| 29 | 2026-04-05 | arquitectura | helix-roadmap.md: documento persistente del equipo técnico — milestones de 1-4 semanas, arquitectura de alto nivel, decisiones arquitectónicas acumulativas. NUNCA se borra automáticamente. |
| 30 | 2026-04-05 | operatividad | skill-tracker.sh: quality/quality-report — scores 1-3 por skill/agente → skill-quality.jsonl. report integrado con uso (30d/7d). prune --execute archiva con confirmación interactiva. |
| 31 | 2026-04-05 | operatividad | mcp-tracker-hook.sh: PostToolUse(mcp__.*) extrae servicio de tool_name y registra tipo=mcp en skill-usage.jsonl. |
| 32 | 2026-04-05 | operatividad | self-check.sh stack-aware: HAS_DOCKER/FASTAPI/CELERY/FRONTEND/TS/PYTHON detectados desde pyproject.toml, package.json, etc. PLANES COMPLETADOS solo elimina helix-plan-REQ-*.md. |

## Archivado 2026-04-18 20:40 — Historial evoluciones
|---|---|---|---|

## Archivado 2026-04-27 — Evoluciones 2026-04-11 (movidas desde CLAUDE.md por poda)
| 7 | 2026-04-11 | arquitectura | Agent Teams nativo (Claude Code ≥v2.1.32): Capa 3 real. Peer-to-peer mailbox. En Capa 2 los agentes no se hablan entre sí — solo reportan al lead. Usar Capa 3 cuando agentes necesiten debatir/coordinar. Hooks: TeammateIdle, TaskCreated, TaskCompleted. |
| 8 | 2026-04-11 | arquitectura | SuperLocalMemory V3.3: memoria local-first con MCP, sin cloud. Olvido adaptativo Ebbinghaus. AGPL v3. Pendiente evaluar vs Qdrant. |
| 9 | 2026-04-11 | performance | HELIX-LANG v1.1: 58.7% compresión tokens en mensajes individuales (no 75%). Operadores ASCII pesan 1 token BPE cada uno. El 75%+ viene de S:hash (contexto compartido por ID). |
| 10 | 2026-04-11 | performance | HELIX-LANG benchmark final: 64.8% ahorro combinado. Gap: contratos API comprimen poco (46%). Mejor caso con S:hash integrado: 80%. |
| 11 | 2026-04-11 | performance | HELIX-DISTILL v1.0: slices CLAUDE.md por agente. 63-93% ahorro. Proyección Capa 2 (13 agentes): 83% menos tokens de init. |
| 12 | 2026-04-11 | operatividad | HELIX-COMPRESS v2: helix-distill.sh con run/compress-project/compress-file. 78-96% ahorro por agente, 93% en sesión 15 agentes. |

## Archivado 2026-04-27 — Evoluciones 2026-04-18 (movidas desde CLAUDE.md por poda)
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
| 18 | 2026-04-18 | operatividad | helix-batch.sh worktree dispatcher (plan/run --parallel/status/cleanup) — patrón /batch del ecosistema Claude Code. | batch-dispatcher-longmemeval |
| 19 | 2026-04-18 | operatividad | .claudeignore template agregado a ~/.claude-template/ y aplicado a helix_asisten. Evita carga de secretos y binarios. | claudeignore-template |

## Archivado 2026-04-27 20:48 — Auto-prune (CLAUDE.md > 340 líneas)
| 7-12 | 2026-04-11 | varias | HELIX-LANG/DISTILL/COMPRESS, Agent Teams, SuperLocalMemory → archivadas en `topics/evolution-history.md`. |

## Archivado 2026-05-06 17:19 — Historial evoluciones
| 67 | 2026-05-03 | arquitectura | Gate B1 cerrado 4/5. ACK explícito creator (ftuga) sobre tranch2-acceptance-criteria.md sesión #20. Audit inmutable: ~/.claude/council/log/20260504T034500Z_b1-ack-creator.yaml chmod 400. SEC1 promovido de RECHAZADO a APROBADO v1.0 con scope acotado (logs internos only, no archivos usuario). M4 deferido FASE 1.5. S1 auto-update rechazado TRANCH 3. Único B1 pendiente: #2 R1 cost pre-audit (requiere R2 instrumentado + 1 semana runtime). TRANCH 2 puede iniciar parcial con M2/M3/SEC1/SEC2 (no dependen cost data); M1+R1 bloqueados hasta cerrar B1#2. | b1-ack-tranch2-unblocked-partial |
| 68 | 2026-05-03 | performance | R2 helix-cost-tracker v0.1 implementado. Procesa transcripts JSONL en ~/.claude/projects/ con precios Anthropic Nov 2025 (Opus 4.7 $15/$75, Sonnet 4.6 $3/$15, Haiku 4.5 $1/$5, cache write 1.25x, cache read 0.10x). Modos: current (sesión actual con cache 30s, 15-50ms), session <id>, all (rollup), report (genera topics/route-cost-audit.md). Wire al statusline slot 💰 muestra USD real ($55.1 medido en sesión #20) en lugar de placeholder Xc. Total render statusline 79ms, dentro de budget <200ms p99. Bug detectado y fixeado: Claude Code convierte _ a - en flat path de projects/. Métrica histórica recolectada: $6890 USD total acumulado en transcripts existentes, helix_asisten = $1005 (10 ses opus + 11 ses sonnet). | r2-cost-tracker-v0.1-done |

## Archivado 2026-05-06 23:36 — Historial evoluciones
| 70 | 2026-05-03 | arquitectura | M2 helix-passive-capture v1.0 implementado. Hook PostToolUse(Write|Edit|MultiEdit) python directo, p99 48.7ms POS / 34.4ms NEG. Matchers grupos A (path Helix) + B (8 keyword decisión) + C (tool), threshold ≥2. Storage 3 JSONL pending/approved/rejected. Review tool con approve/reject/stats. Skill helix-passive-review. Bench documentado topics/m2-bench.md. Acceptance criteria 3/5 PASS, 2 PENDING (precision/noise requieren 30d uso real). TRANCH 2 #1/6 done. | m2-passive-capture-implementado |
| 71 | 2026-05-03 | arquitectura | M3 helix-project-consolidate v1.0 implementado. Detector difflib SequenceMatcher con strip rules helix-/helix_/claude-/-hook/-helper. Threshold env var HELIX_M3_FUZZY_THRESHOLD default 0.75. Modos scan/report/list/unify. Unify interactive requiere [1/2/s/q] + confirm [y/N]. git rm si en repo, backup en ~/.claude/backups/m3/ si no. Smoke test reversibilidad PASS. Scan real ~/.claude/ encontró 19 pares, precision 50% (acceptable bajo creator review). 2/6 TRANCH 2 done. | m3-consolidate-implementado |
| 72 | 2026-05-03 | seguridad | SEC2 helix-egress-audit v1.0 implementado. Hook PostToolUse(WebFetch|WebSearch|mcp__.*) Python directo. Schema log {ts,tool,domain,path_short,source,query_sanitized,new_domain}. Sanitization regex (api_key|token|password|secret|auth|bearer|session|sid|jwt)=val. Threshold alert solo en first-seen domain o spike >=20/5min. Reporter mensual on-demand (D2.1 NO cron). Smoke test 6/6 PASS (known/new/redact/websearch/mcp/skip). 3/6 TRANCH 2 done. | sec2-egress-audit-implementado |
| 73 | 2026-05-03 | seguridad | SEC1 helix-aidefence v1.0 implementado. Hook PostToolUse Write/Edit/MultiEdit con scope acotado a logs internos Helix. 10/10 PII types redactados (EMAIL, PHONE_E164, PHONE_NA, SSN_US, IBAN, IPV4/6_PUBLIC, CREDIT_CARD-Luhn, PATH_USERNAME, URL_USERINFO). Redact-no-block hard rule. Audit log aidefence-redactions.jsonl. LATENCIA NO CUMPLE criterio <30ms (p99 77ms POS) por floor bash+python startup ~35ms + I/O. Decision creator: aceptar v1.0, re-spec a <80ms, o bloquear hasta rewrite nativo TRANCH 3. 4/6 TRANCH 2 done con SEC1 status pending decisión latencia. | sec1-aidefence-implementado-latency-pending |

## Archivado 2026-05-06 23:36 — Historial evoluciones
> Historial completo en `.claude/evolution-log.txt`

## Archivado 2026-05-08 00:02 — Historial evoluciones
| 74 | 2026-05-03 | arquitectura | M1 helix-judge v1.0 implementado. LLM-as-judge para conflictos semánticos backend Ollama llama3.2:3b por default (override HELIX_JUDGE_MODEL). Few-shot prompt estático en código (anti-poisoning CS1 hard rule). Modes judge/scan/audit-list/audit-mark/stats. Confidence threshold >=0.85 hard rule. Audit log judge-decisions.jsonl 100% calls. Audit feedback aislado en judge-audit-feedback.jsonl (única fuente para calibración futura). Code review PASS para anti-poisoning + sin feedback loop M1<->S1. Smoke 4/4 acuerdan con expectativa. Latencia 2-4s post-warmup. 5/6 TRANCH 2 done. | m1-judge-implementado |
| 77 | 2026-05-06 | operatividad | M3 cheap-test antes de implementar precondiciones invalida propuestas complejas a costo cero. En el council session 20260506T204031Z-72444r la decisión APPROVE_WITH_PRECONDITIONS proponía F+D con 4 mitigaciones M1-M4 (~30 min trabajo). Ejecutar M3 primero (expert summons frontend-developer, ~10 min) reveló que la solución correcta era un script one-shot mucho más simple: F+M1+M2+M4 quedaron descartados. Lección: cuando council emite APPROVE_WITH_PRECONDITIONS, ejecutar la precondición más cheap+informativa primero — puede invalidar todo el resto. | council-precond-cheap-first |
| 79 | 2026-05-06 | interfaz | frontend-intent-gate v1.0 implementado. PreToolUse(Write|Edit|MultiEdit) hook Python directo, latencia 22-28ms cold (dentro de budget <80ms SEC1). Detecta extensiones UI (.tsx/.jsx/.css/.scss/.sass/.vue/.svelte/.html/.astro). Solo emite la primera vez por sesión (flag en ~/.claude/session-env/<sid>/frontend-gate-asked). Mensaje a stderr con flag [HELIX-FRONTEND-INTENT] que Claude traduce a 2 preguntas: (1) usar experto frontend-developer, (2) aplicar brief de referencia (lista los .md disponibles en ~/.helix/memory/frontend-briefs/). Reversibilidad HELIX_FRONTEND_GATE_ENABLED=0. Wired settings.json PreToolUse 10mo hook. Cumple las 2 partes de la idea original del creator (script generador de brief + skill gate). | frontend-intent-gate-v1-done |
| 80 | 2026-05-06 | seguridad | claude-flow MCP toma over los 16 slots de hooks de Helix (PreToolUse, PostToolUse, SessionStart, etc) silenciando HSL v1 sin warning visible. Síntoma: 0 entries de un proyecto en passive-captures/aidefence/egress-audit logs. Detección: grep cwd_proyecto en logs HSL — si vacío y otros proyectos sí registran, hay bypass. | <proyecto-privado> tenía 16 hooks claude-flow ocupando todos los slots, HSL silenciado |

## Archivado 2026-05-11 14:23 — Historial evoluciones
| 81 | 2026-05-06 | operatividad | HSL hooks pueden desaparecer silenciosamente cuando un proceso reescribe settings.json sin preservar entradas previas. Validar post-edición: jq que confirme presence de helix-aidefence-hook, passive-capture-hook, helix-egress-audit-hook en PostToolUse. | settings.json regenerado entre 2026-05-04 y 2026-05-06 perdió los 3 hooks HSL sin trace |

## Archivado 2026-05-26 01:33 — Historial evoluciones
| 82 | 2026-05-06 | arquitectura | Scripts Helix DEBEN respetar CLAUDE_CONFIG_DIR. Patrón: CONFIG_DIR = Path(os.environ.get('CLAUDE_CONFIG_DIR', str(HOME / '.claude'))). Hardcoding ~/.claude/memory/ rompe cuando el creator usa ~/.helix como config dir — escribe en path equivocado, los logs parecen vacíos pero existen en otro lado. | BUG-G1 confirmado en helix-aidefence-hook.py, passive-capture-hook.py, helix-egress-audit-hook.py |

## Archivado 2026-06-11 09:10 — Historial evoluciones
| 84 | 2026-05-07 | arquitectura | HELIX-LANG enforcement v1: prompt council reescrito de 'if useful' a OBLIGATORIO + gramatica 5-formas + vocabulario universal + vocab del council inline. Warning visible en finalize si adoption_pct<30. CLAUDE.md L107 actualizado: handoffs inter-agente requieren HELIX-LANG. Reversibilidad via HELIX_LANG_ENFORCE=0. Council 20260507T043859Z-n0n28i diagnostico 2.2 vs 59 promesa; usuario rechazo diferimiento del consejo y autorizo correccion directa. | council-validacion-helix-lang |

## Archivado 2026-06-11 14:42 — Historial evoluciones (bloque #58-93)
| 58 | 2026-05-02 | operatividad | Cuando el usuario pide expertos por nombre, NO hacer pre-validacion yo mismo. Verificar 1 vez (grep al agents-index). Si faltan, preguntar. Si estan, invocar Capa 2 o Capa 1 y dejar que ellos validen. | user-pidio-expertos-yo-prevalide |
| 60 | 2026-05-03 | arquitectura | Helix Council v1.0 implementado: 7 agents council-* (skeptic/innovator/conservative/synthesizer/researcher/devils-advocate/arbiter) con frontmatter + context on-demand + entries en agents-index. Constitución 9 reglas (R1-R9). Orquestador bash modo prepare/collect/finalize/abort. Context pack builder con niveles L0-L3 + filtros keywords + anti-injection scan. Plan v4 + diseño council persistidos en topics/. Routing-check bypass para council-*. Limitación operativa: agents nuevos requieren sesión nueva para ser invocables (Agent tool carga lista al inicio). Resume script bootstraps próxima sesión. | council-v1-implementado-pending-run-fresh-session |
| 62 | 2026-05-03 | operatividad | FASE 9 HW-aware implementada (A2 TRANCH 1 plan v4): hwprobe → hw-profile.json + capa0-policy ON|OPT_IN|OFF + models-suggest tabla compatible + bench-capa0 empírico (override heurística council dissent #3). capa0.sh wired con timeout 30s + policy gate. HW5 installer-prompt deferido a FASE 6 con interfaz documentada en topics/helix-hw-aware-fase9.md. | fase9-hw-aware-done |
| 69 | 2026-05-03 | arquitectura | Gate B1 cerrado 5/5. B1#2 (R1 cost pre-audit) APROBADO con data histórica (transcripts JSONL cubren meses, no solo 1 semana). Audit inmutable: ~/.claude/council/log/20260504T035500Z_b1-check-2-closed.yaml chmod 400. TRANCH 2 DESBLOQUEADO completo. Componentes habilitados: M1 helix-judge, M2 passive-capture, M3 consolidate, R1 multi-modelo (necesita cross-join routing-feedback para dominio semántico), R2 cost-tracker (DONE v0.1), SEC1 aidefence v1.0 (scope acotado), SEC2 egress-audit. M4 deferido FASE 1.5. Cualquier reversa requiere council nuevo. | b1-fully-closed-tranch2-unblocked |
| 75 | 2026-05-03 | arquitectura | R1 helix-route-recommend v1.0 implementado. Advisor read-only NUNCA modifica settings.json. helix-route-cost-audit.py regenera route-cost-audit.md con 5 secciones (cost-by-project R2, volumen-por-dominio cross-join routing-feedback x AGENT_TO_DOMAIN, recos-heuristicas DOMAIN_RECOS, caveats explicitos, gate B1#2 closure). helix-route-recommend.py modes recommend/by-agent/list/current/compare. Override HELIX_FORCE_MODEL. Kill switch HELIX_R1_ENABLED=0 fallback Sonnet sin estado. Audit log r1-recommend-log.jsonl 100%. AGENT_TO_DOMAIN y DOMAIN_RECOS estaticos (anti-poisoning paralelo M1 CS1). 10/10 smoke tests PASS. TRANCH 2 6/6 DONE. | r1-route-recommend-implementado |
| 76 | 2026-05-03 | arquitectura | D1' multi-domain trigger v1.0 implementado. PreToolUse(Agent) hook detecta intent multi-dominio (11 keyword groups: backend/frontend/db/security/infra/testing/debug/ui/performance/data/mlops) threshold >=2 advisory only no block. Reversibility HELIX_D1_TRIGGER_ENABLED=0 sin estado. Audit log d1-multidomain-detections.jsonl. Anti-poisoning DOMAIN_KEYWORDS estatico paralelo M1 CS1. Smoke 4/4 PASS. p99 58-67ms acceptable para Agent path. Wired settings.json PreToolUse Agent 3rd hook. **CIERRA el caveat D1' del plan v4 — TRANCH 1 100%**. Construccion Capa 2 propia orquestador queda candidate TRANCH 3 si surge demanda. Plan ejecutable inmediato 100%. | d1-multidomain-trigger-cierra-tranch1 |
| 78 | 2026-05-06 | arquitectura | Bypass meta-agentes en routing-check-hook.sh: agregado set META_AGENTS={code-reviewer, architect-reviewer, error-detective, security-auditor, qa-expert} junto con startswith('council-'). Estos son agentes de proceso/calidad, no de dominio — reciben triggers con keywords técnicos por diseño. Sin bypass, el hook bloquea con exit 2 cualquier review/audit cuyo prompt mencione tsx/react/tailwind/sql/etc. Cierra gap pendiente de evolución #60 + extiende a code-reviewer (caso real detectado durante council session 20260506T204031Z-72444r). Reversibilidad: 5 líneas, git restore. | routing-check-hook-meta-bypass |
| 83 | 2026-05-06 | arquitectura | Capabilities vectoriales (helix-route.sh pick) existen como código pero NO se usan hasta wire automático en hooks. Diseñar capability != activar capability. routing-check-hook.sh debe llamar helix-route.sh pick --shadow para que el vector search registre en routing-shadow.jsonl y emita warnings comparativos. | BUG-G2: r1-recommend-log.jsonl tenía 0 líneas en TODOS los proyectos del creator hasta el fix |
| 85 | 2026-05-07 | arquitectura | Agente linguista-computacional-tokens creado con pipeline research-first (skill agent-create). 7 fuentes: Petrov 2023 NeurIPS arXiv:2305.15425 (cross-lingual unfairness 15x), Sennrich 2016 BPE arXiv:1508.07909, Kudo 2018 SentencePiece arXiv:1808.06226, OpenAI tiktoken, Anthropic glossary tokens 3.5chars EN, HF tokenizer summary, Google sentencepiece repo. 15 principios operables: medicion en tokens no chars, cross-lingual minimo 4 idiomas, ASCII puro tokeniza eficiente, vocab declarado upfront S:hash, round-trip lossless mandatory, no comprimir lenguajes formales, distinguir interna vs externa. Trigger: validar promesas de compresion como HELIX-LANG 59%, audit cross-lingual, decisiones de USD vs ahorro. Validacion 8 preguntas pending primera invocacion. Limitacion conocida: Agent tool carga lista al inicio (evolution #60) - invocable solo en proxima sesion. | agent-create-linguista-tokens |
| 86 | 2026-05-07 | interfaz | Regla raíz de IDIOMA Y TONO debe ser MIRROR del idioma del usuario (no español fijo). Detección sobre último mensaje. Cambio mid-chat sin preguntar. Fallback español neutro colombiano solo si idioma ambiguo. Override user-profile.md prevalece. Aplicado en CLAUDE.md L188-194, inter-agent-language.md L7-8 y L44+L54, helix-council.sh L158. | user-correction-mirror-idioma |
| 87 | 2026-05-07 | arquitectura | Linguista-computacional-tokens activado (7.5/8) primera invocación. Bench tiktoken local sobre council 20260507T051108Z-xgyps: compresión real cl100k 23.6%, o200k 15.4%, vs promesa SKILL.md ~59% (gap 35.4 pp). Cross-lingual: HELIX-LANG cuesta MÁS que prosa en EN (-3.5%), comprime fuerte solo en JA (+59.5%). 1 caso lossy real (ask + <- sin regla precedencia). Decisión adjust con 4 ADJ. Audit log: ~/.helix/memory/audit/linguista-bench-20260507.yaml | linguista-bench-helix-lang |
| 88 | 2026-05-07 | interfaz | Taxonomía idioma Helix por capa codificada en CLAUDE.md §IDIOMA Y TONO: capa 1 user-facing mirror, capa 2 doctrina ES, capa 3 artefactos formales EN ASCII, capa 4 inter-agente HELIX-LANG, capa 5 prompts LLM EN, capa 6 código fuente EN. Justificación empírica linguista-bench-20260507 (EN ~37% más barato que ES en cl100k). L115 reformulada: cuerpo analítico de prompt sigue capa 5 (EN si system prompt en EN), no español fijo. Reversible git restore. | idioma-helix-taxonomia-capas |
| 89 | 2026-05-07 | arquitectura | SKILL.md helix-lang actualizado a v2.1: ADJ-1 tabla rendimiento reemplazada (compresión real por idioma+tokenizer cl100k EN -3.5% ES +34.7% ZH +44.5% JA +59.5%), ADJ-2 regla precedencia operador-verbo (-> consulta activa, <- recepción pasiva), ADJ-3 separación Fuente 1 (compresión por bloque) vs Fuente 2 (S:hash sin bench empírico aún), ADJ-4 requisito metodológico tokenizer+idioma+N en toda cifra. Frontmatter description + version 2.0->2.1. | skill-helix-lang-adj-1234 |
| 90 | 2026-05-08 | arquitectura | v3 lenguaje archivado por evidencia: bench post-implementacion revelo corpus council near-optimo entropicamente. Cross-round overlap <1%, prosa YAML densa incompresible, citations no se repiten. Ahorro real 0.30% lexical, 7.55% caveman bilingue, 0.11% dedup. v3 stays archived pending semantic compression capability O corpus Capa 2 swarm real. Infra reversible deployed (toggle, gate, detector, rollout). Council audit 20260507T215307Z-109qf cementa diseno aprobado pero no implementado. | v3-archive-empirical-evidence |
| 91 | 2026-05-11 | interfaz | Reglas globales a 'button' deben excluir role='switch'/tab/radio. min-height: 32-44px global aplasta toggle switches con dimensiones fijas (20-24px). Patron: button:not([disabled]):not([role='switch']) { min-height: ... } | responsive-system-aplasto-toggles |
| 92 | 2026-05-20 | datos | Postgres index predicate con CURRENT_DATE/NOW()/CURRENT_TIMESTAMP falla: 'functions in index predicate must be marked IMMUTABLE'. Esas funciones son STABLE, no IMMUTABLE. Solución: índice compuesto sobre la columna (sin WHERE) y dejar que el optimizer filtre | schema-postgres-current-date-en-where |
| 93 | 2026-05-21 | operatividad | rfd 0.14 cambió backend default a xdg-portal (ashpd/DBus). En WSL sin systemd-user (sin /run/user/UID/bus) pick_file/pick_folder/save_file retornan None instantáneo, sin abrir ventana, sin logs incluso con G_MESSAGES_DEBUG=all. Fix: en Cargo.toml forzar rfd = { version = '0.14', default-features = false, features = ['gtk3'] }. gtk3 habla directo con libgtk-3-0 sobre X11/Wayland sin DBus. | rfd-default-xdg-portal-wsl |
