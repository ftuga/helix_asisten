
## Archivado 2026-03-08 20:53 — Operatividad
- [2026-03-08] test desde raíz del proyecto

## Archivado 2026-03-08 20:53 — Operatividad
- [2026-03-08] test desde raíz del proyecto

## Archivado 2026-03-08 20:58 — Operatividad
- [2026-03-08] set -euo pipefail: [[ -n '' ]] && cmd devuelve exit 1 cuando condición es falsa — usar if/fi en lugar de && para comandos condicionales
- [2026-03-08] Los marcadores de sección en CLAUDE.md usan nombres en inglés (OPERABILITY, SECURITY, etc.) pero las categorías de evolve.sh son en español — siempre mapear con case/esac antes de construir el marcador
- [2026-03-08] Para pasar strings con caracteres especiales a python3 desde bash: usar variables de entorno (PYVAR=valor python3 - archivo <<'PYEOF') — evita todo problema de escaping

## Archivado 2026-03-08 20:58 — Operatividad
- [2026-03-08] set -euo pipefail: [[ -n '' ]] && cmd devuelve exit 1 cuando condición es falsa — usar if/fi en lugar de && para comandos condicionales
- [2026-03-08] Los marcadores de sección en CLAUDE.md usan nombres en inglés (OPERABILITY, SECURITY, etc.) pero las categorías de evolve.sh son en español — siempre mapear con case/esac antes de construir el marcador
- [2026-03-08] Para pasar strings con caracteres especiales a python3 desde bash: usar variables de entorno (PYVAR=valor python3 - archivo <<'PYEOF') — evita todo problema de escaping

## Archivado 2026-06-11 14:44 desde CLAUDE.md — Bloque seguridad+operatividad 2026-05-03/06/21

### Seguridad (Tranch 2 closures)
- [2026-05-03] HSL v1 audit completo: cubre 4/14 PII types directos + 2 parciales (32%). Gap real en PII clásica de personas (email, phone, SSN, credit card, etc.). SEC1 NO redundante — entra TRANCH 2 con scope acotado a logs/audit/snapshot internos de Helix (NO archivos del proyecto del usuario). v1.0 solo regex + redact (no block, no LLM judge). Acceptance criteria definidos. Fix lateral aplicado: secrets-scanner-hook safe-targets ahora incluye /memory/topics/ y /council/ (gap detectado durante el propio audit, scanner se autobloqueaba).
- [2026-05-03] SEC2 helix-egress-audit v1.0 implementado. Hook PostToolUse(WebFetch|WebSearch|mcp__.*) Python directo. Schema log {ts,tool,domain,path_short,source,query_sanitized,new_domain}. Sanitization regex (api_key|token|password|secret|auth|bearer|session|sid|jwt)=val. Threshold alert solo en first-seen domain o spike >=20/5min. Reporter mensual on-demand (D2.1 NO cron). Smoke test 6/6 PASS (known/new/redact/websearch/mcp/skip). 3/6 TRANCH 2 done.
- [2026-05-03] SEC1 helix-aidefence v1.0 implementado. Hook PostToolUse Write/Edit/MultiEdit con scope acotado a logs internos Helix. 10/10 PII types redactados (EMAIL, PHONE_E164, PHONE_NA, SSN_US, IBAN, IPV4/6_PUBLIC, CREDIT_CARD-Luhn, PATH_USERNAME, URL_USERINFO). Redact-no-block hard rule. Audit log aidefence-redactions.jsonl. LATENCIA NO CUMPLE criterio <30ms (p99 77ms POS) por floor bash+python startup ~35ms + I/O. Decision creator: aceptar v1.0, re-spec a <80ms, o bloquear hasta rewrite nativo TRANCH 3. 4/6 TRANCH 2 done con SEC1 status pending decisión latencia.
- [2026-05-06] claude-flow MCP toma over los 16 slots de hooks de Helix (PreToolUse, PostToolUse, SessionStart, etc) silenciando HSL v1 sin warning visible. Síntoma: 0 entries de un proyecto en passive-captures/aidefence/egress-audit logs. Detección: grep cwd_proyecto en logs HSL — si vacío y otros proyectos sí registran, hay bypass.

### Operatividad
- [2026-05-02] Cuando el usuario pide expertos por nombre, NO hacer pre-validacion yo mismo. Verificar 1 vez (grep al agents-index). Si faltan, preguntar. Si estan, invocar Capa 2 o Capa 1 y dejar que ellos validen. Pre-trabajo de mi parte es ruido.
- [2026-05-02] Sub-investigacion en cascada: cuando una verificacion simple falla, NO escalar a busqueda en backups/patterns multiples. 1 find acotado, si no aparece preguntar al usuario donde mirar. Test: si llevo >3 tool calls de discovery sin avanzar al deliverable, parar y reportar.

> Bloques anteriores (2026-04-24 → 2026-04-27) archivados a `~/.claude/memory/topics/operatividad.md` §"Bloque archivado 2026-05-03".
- [2026-05-03] FASE 9 HW-aware implementada (A2 TRANCH 1 plan v4): hwprobe → hw-profile.json + capa0-policy ON|OPT_IN|OFF + models-suggest tabla compatible + bench-capa0 empírico (override heurística council dissent #3). capa0.sh wired con timeout 30s + policy gate. HW5 installer-prompt deferido a FASE 6 con interfaz documentada en topics/helix-hw-aware-fase9.md.
- [2026-05-03] MIT1 council #3 implementado: helix-lang-detect.sh escanea outputs YAML del council buscando patrones HELIX-LANG v2 (verbos, ops, temporales, S:hash, FROM->TO). Wireado al finalize de helix-council.sh para registrar adoption_pct en frequency.log post-cada-council. Resultado primera medición: 0% adoption en 3 councils (39 outputs). Convierte 'forzar adopción' (intervención circular sin causal mech) en dato medible — anti-CS1 devils-advocate. MIT2 (tokenizer real) y MIT3 (R2 saltable solo con votos activos) pendientes.
- [2026-05-06] M3 cheap-test antes de implementar precondiciones invalida propuestas complejas a costo cero. En el council session 20260506T204031Z-72444r la decisión APPROVE_WITH_PRECONDITIONS proponía F+D con 4 mitigaciones M1-M4 (~30 min trabajo). Ejecutar M3 primero (expert summons frontend-developer, ~10 min) reveló que la solución correcta era un script one-shot mucho más simple: F+M1+M2+M4 quedaron descartados. Lección: cuando council emite APPROVE_WITH_PRECONDITIONS, ejecutar la precondición más cheap+informativa primero — puede invalidar todo el resto.
- [2026-05-06] HSL hooks pueden desaparecer silenciosamente cuando un proceso reescribe settings.json sin preservar entradas previas. Validar post-edición: jq que confirme presence de helix-aidefence-hook, passive-capture-hook, helix-egress-audit-hook en PostToolUse.
- [2026-05-21] rfd 0.14 cambió backend default a xdg-portal (ashpd/DBus). En WSL sin systemd-user (sin /run/user/UID/bus) pick_file/pick_folder/save_file retornan None instantáneo, sin abrir ventana, sin logs incluso con G_MESSAGES_DEBUG=all. Fix: en Cargo.toml forzar rfd = { version = '0.14', default-features = false, features = ['gtk3'] }. gtk3 habla directo con libgtk-3-0 sobre X11/Wayland sin DBus.
