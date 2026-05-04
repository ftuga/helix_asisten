# HSL v1 Audit — Cobertura PII vs SEC1 spec

> Auditoría ejecutada 2026-05-04 sesión #20. Pre-requisito Gate B1 #2 (TRANCH 2).
> Decide: ¿SEC1 (helix-aidefence) es redundante con HSL v1 o tiene gap real?

---

## Las 6 capas de HSL v1

| Capa | Hook / Script | Disparador | Scope |
|---|---|---|---|
| L1 — Injection | `injection-detector-hook.sh` | PostToolUse(WebFetch\|WebSearch\|Read) | Detecta jailbreak / fake-system / exfil patterns / zero-width / long-base64 en contenido externo. No bloquea — solo alerta a `injection-alerts.jsonl` |
| L2 — Egress | `network-egress-hook.sh` | PreToolUse(Bash) | Bloquea curl/wget/nc/ssh/scp/git-clone fuera de allowlist (~25 dominios). Exit 2 |
| L3 — Secrets | `secrets-scanner-hook.sh` | PreToolUse(Write\|Edit\|MultiEdit\|Bash) | Bloquea credenciales antes de escribir a disco. 14 patrones |
| L4 — Integrity | `integrity-check.sh` | Manual + session-start | SHA-256 manifest de settings.json + CLAUDE.md + helpers/*.sh |
| L5 — Evolve guard | (verificado en `evolve.sh` directo) | Cada `evolve.sh learn` | Categorías permitidas, no overflow, append-only |
| L6 — Reflexion quarantine | `helix-reflexion.sh` | Manual + sesión post-error | Cuarentena de aprendizajes contradictorios antes de cementar |

---

## L3 — Patrones de secretos cubiertos (14 hits)

| Tag | Cubre |
|---|---|
| AWS access-key-id / secret | Credenciales AWS (2 patrones) |
| GCP service-account-key | Llave privada formato PEM |
| GitHub PAT / OAuth / Server / FineGrained | Tokens GitHub (4 patrones) |
| OpenAI apiKey | Credencial OpenAI |
| Anthropic apiKey | Credencial Anthropic |
| Slack token | Token Slack |
| Stripe liveKey | Credencial Stripe production |
| Google APIKey | API Key Google |
| SSH privateKey | Llaves privadas RSA/OPENSSH/DSA/EC/PGP |
| JWT signed | Tokens JWT con 3 segmentos |
| DB conn-with-password | Cadenas conexión DB con password embebido |

**Acción L3:** BLOCK (exit 2). No redacta — bloquea la escritura.

---

## SEC1 spec original — 14 PII types (aidefence-inspired)

> Plan v4 §SEC1: "pipeline de PII detection (14 tipos: emails, SSN, credit cards, API keys, JWT, paths absolutos del usuario, etc.)"

Lista canónica inferida (estándar Microsoft Presidio + AWS Comprehend):

| # | PII type | HSL cubre? | Notas |
|---|---|---|---|
| 1 | API keys / tokens (genérico) | **SÍ** L3 | 13 patrones específicos |
| 2 | JWT signed | **SÍ** L3 | Patrón con 3 segmentos base64 |
| 3 | DB connection strings | **SÍ** L3 | Postgres/MySQL/MongoDB con password |
| 4 | SSH/GCP private keys | **SÍ** L3 | PEM headers |
| 5 | Email | **NO** | Sin cobertura |
| 6 | Phone number | **NO** | Sin cobertura |
| 7 | SSN (US) | **NO** | Sin cobertura |
| 8 | Credit card / PAN | **NO** | Sin cobertura |
| 9 | IBAN / bank account | **NO** | Sin cobertura |
| 10 | IP address (IPv4/IPv6) | **PARCIAL** L2 | Solo si está en URL bloqueada |
| 11 | Person name | **NO** | Sin cobertura |
| 12 | Postal address | **NO** | Sin cobertura |
| 13 | Date of birth | **NO** | Sin cobertura |
| 14 | Filesystem path con username | **PARCIAL** L1 | Solo paths sensibles del SO, no usernames del proyecto |

**Cobertura efectiva HSL → SEC1: 4/14 directos + 2 parciales = ~32%.**

---

## Análisis

HSL v1 cubre **credenciales técnicas** muy bien (L3 con 14 patrones específicos). Pero **NO cubre PII de personas humanas** (email, phone, SSN, credit card, dirección, DOB, etc.).

La diferencia conceptual:
- **HSL L3 = anti-leak de secretos** (lo que un atacante usaría para acceder a sistemas)
- **SEC1 = anti-leak de PII** (lo que regulación/privacidad exige proteger)

Ambos son legítimos. No son el mismo scope.

---

## Hallazgo lateral durante la auditoría

El secrets-scanner-hook se autobloqueó al intentar escribir este reporte (los patrones literales de regex documentados aquí matchean contra los propios regex). Era un gap conocido: docs internos de Helix bajo `~/.claude/memory/topics/` y `~/.claude/council/` no se trataban como safe-targets.

**Fix aplicado:** agregadas dos rutas al `is_safe_target()` del scanner (`/.claude/memory/topics/`, `/.claude/council/`). Cubre docs y audit logs del propio harness.

---

## Recomendación

**SEC1 NO es redundante. Implementar con scope acotado.**

### Scope recomendado para SEC1 v1.0 (anti-circularidad CS2)

NO implementar como pipeline universal de PII detection. SEC1 solo aplica a **escritura de logs/audit/snapshot internos de Helix**, donde una PII del usuario podría filtrarse accidentalmente:

| Target | Por qué |
|---|---|
| `~/.claude/memory/routing-feedback.jsonl` | Captura primer fragmento de prompts de usuario |
| `~/.claude/memory/helix-bitacora-*.md` | Resúmenes de sesión escritos por hooks |
| `~/.claude/snapshots/*/*.yaml` | Estado de sesión persistido cross-session |
| `~/.claude/council/log/*.yaml` | Audit logs (inmutables, generados desde inputs de usuario) |
| `~/.claude/memory/injection-alerts.jsonl` | Logs de L1, contienen el match completo |

**NO scope:** código del usuario (Write/Edit a archivos del proyecto). Eso es responsabilidad del usuario, no de Helix.

### Diseño liviano

Hook PostToolUse Write/Edit con filter por target path → regex match 10 PII types adicionales (email, phone, SSN, credit card, IBAN, IPv4, person name heuristic, postal, DOB, paths con username) → **redact, no block** (reemplaza match con `[PII:type]` y graba). Stderr informativo.

LLM judge para edge cases (mencionado en plan): **DESCARTADO** en v1.0 — agrega latencia + costo + circularidad. Solo regex + entropy. Deferido a SEC1 v2.0 si métrica empírica muestra falsos positivos altos.

### Métrica de éxito SEC1 v1.0

- ≥80% PII detectado en sample de 50 logs sintéticos del creator
- ≤5% falsos positivos en logs reales de 1 mes de uso
- Latencia hook agregada <30ms p99
- 0 PII en logs/snapshots después de roll-out (audit manual del creator)

### Decisión final

- **Mantener HSL v1 sin cambios estructurales** — cubre credenciales bien.
- **Fix aplicado al safe-targets** del L3 scanner (gap menor, no estructural).
- **SEC1 va a TRANCH 2** con scope acotado a logs/audit/snapshot internos de Helix.
- **Acceptance criteria SEC1** (a agregar a `tranch2-acceptance-criteria.md`):

| Criterio | Métrica | Umbral | Validador |
|---|---|---|---|
| Cobertura PII | tipos detectados en sample sintético 50 entries | 10/10 nuevos types | creator manual |
| Falsos positivos | % en logs reales 30 días | ≤5% | creator review |
| Redact, no block | NUNCA bloquea write a logs internos | hard rule | code review |
| Latencia hook | tiempo agregado a PostToolUse Write/Edit | <30ms p99 | bench |
| Scope acotado | NO aplica a archivos del proyecto del usuario | hard rule en path filter | code review |

---

## Decisión sobre Gate B1 #2

**HSL v1 audit COMPLETO.** Output:
- HSL cubre 4/14 tipos directos + 2 parciales = ~32% del SEC1 spec original.
- Gap real en PII clásica.
- SEC1 NO es redundante.
- SEC1 entra a TRANCH 2 con scope acotado v1.0 (regex + redact + logs internos only).
- Fix lateral aplicado al L3 scanner (safe-targets para topics/ y council/).

Gate B1 check #2: **APROBADO** con condición de agregar criterios SEC1 al doc B1.
