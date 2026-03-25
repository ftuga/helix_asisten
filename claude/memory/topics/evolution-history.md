
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
