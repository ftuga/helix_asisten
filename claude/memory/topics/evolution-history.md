
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
| 8 | 2026-03-20 | interfaz | Alerta antes de zona 🔴: declarar qué línea/función se va a cambiar y esperar confirmación | usuario-solicitud-mejora |

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
