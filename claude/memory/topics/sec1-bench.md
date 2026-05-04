# SEC1 helix-aidefence v1.0 — bench y validación

> Implementado 2026-05-04 sesión #21. Componente: `~/.claude/helpers/helix-aidefence-hook.py` (+ wrapper `.sh`). Wired a `settings.json` PostToolUse `Write|Edit|MultiEdit` (4° hook en cascada).

---

## Cobertura PII (criterio: 10/10 nuevos types, sin overlap con HSL L3)

**Resultado: 10/10 PASS.**

Sample sintético con 14 entradas, 10 types únicos detectados y redactados:

| # | Type | Pattern | Test sample | Resultado |
|---|---|---|---|---|
| 1 | EMAIL | `\b[\w.%+\-]+@[\w.\-]+\.[A-Za-z]{2,}\b` | `alice@example.com` | `[PII:EMAIL]` |
| 2 | PHONE_E164 | `\+\d{1,3}[\s\-]?...` | `+34 612 345 678` | `[PII:PHONE_E164]` |
| 3 | PHONE_NA | `\(\d{3}\)\s?\d{3}[\s\-\.]?\d{4}` o `\d{3}[\s\-\.]\d{3}[\s\-\.]\d{4}` | `(555) 123-4567`, `555-123-4567` | `[PII:PHONE_NA]` |
| 4 | SSN_US | `\b\d{3}-\d{2}-\d{4}\b` | `123-45-6789` | `[PII:SSN_US]` |
| 5 | IBAN | `\b[A-Z]{2}\d{2}[A-Z0-9]{10,30}\b` | `GB29NWBK60161331926819` | `[PII:IBAN]` |
| 6 | IPV4_PUBLIC | regex IPv4 + filtro privadas | `8.8.8.8` redact, `192.168.1.1` skip | `[PII:IPV4_PUBLIC]` |
| 7 | IPV6_PUBLIC | regex IPv6 (full + compressed) + filtro loopback/ULA | `2001:db8::8a2e:370:7334` | `[PII:IPV6_PUBLIC]` |
| 8 | CREDIT_CARD | `\b(?:\d[ \-]?){13,19}\b` + Luhn validation | `4111 1111 1111 1111` redact, `1234 5678 9012 3456` skip (Luhn fail) | `[PII:CREDIT_CARD]` |
| 9 | PATH_USERNAME | `(?:/home\|/Users)/([\w.\-]+)/` | `/home/USER/`, `/Users/jdoe/` | `/home/[PII:USERNAME]/`, `/Users/[PII:USERNAME]/` |
| 10 | URL_USERINFO | `https?://[^/\s:]+:[^/@\s]+@` | `https://admin:passw0rd@host` | `https://[PII:URL_USERINFO]@host` |

**Sin overlap con HSL L3 (secrets API keys):** los 10 types son PII clásica de personas, ortogonal a la cobertura existente del secrets-scanner.

**Caveats:**
- `PATH_USERNAME_WINDOWS` (`C:\Users\X\`) implementado pero no probado en sample (escape literal del JSON heredoc no permitió validarlo). Patrón es paralelo al Linux y debería funcionar en payloads reales.
- Luhn validation evita falsos positivos en números 16-dígitos sin checksum válido.
- IPV4 privadas (10/8, 172.16/12, 192.168/16, 127/8, 169.254/16, 0/8, multicast 224+) no se redactan.

---

## Latencia (criterio: <30ms p99) — NO CUMPLE en runtime actual

Bench Python `time.perf_counter()`, 60 runs por escenario, payload realista.

| Escenario | p50 | p95 | p99 | avg |
|---|---|---|---|---|
| POS (in-scope, PII presente, redact + write) | 40.9ms | 57.7ms | 76.8ms | 42.4ms |
| in-scope clean (no PII, read sin write) | 40.0ms | 55.5ms | 64.6ms | 40.5ms |
| out-of-scope (path-miss, salida temprana) | 35.7ms | 50.7ms | 54.3ms | 36.1ms |

### Diagnóstico

- **Floor inevitable:** ~35ms = bash (~5ms) + python3 startup (~25-30ms en WSL2). No reducible sin cambio de runtime.
- **In-scope path-match adicional:** +5ms por compilar regex patterns (cached al module level pero igual hay carga inicial).
- **Read+regex+write:** +5-10ms cuando hay PII (depende tamaño file, cap 1MB).

### Comparación con M2 (mismo runtime, similar arquitectura)

M2 passive-capture: p99 POS 48.7ms / NEG 34.4ms — bench cumplido (criterio <50ms). M2 NO toca filesystem; SEC1 sí (read + write back) → +25ms reales por I/O.

### Opciones para el creator

1. **Aceptar p99 ~77ms para v1.0** (recomendado). Documentar plan de optimización v2.0 (rewrite Go o Rust si SEC1 se vuelve hot path). Justificación: criterio funcional 10/10 cumple; latencia es overhead del runtime decidido en D3 (bash+Python core, no Go/Rust hasta TRANCH 3).
2. **Re-spec el criterio a <80ms p99**, alineado con M2 + I/O overhead realista. Anti-circularity safe: el creator decide externo al sistema.
3. **Bloquear SEC1 hasta que p99 <30ms** (requiere reescritura nativa). Bloqueo TRANCH 2 SEC1 sine die hasta TRANCH 3 I5.

**No es bloqueo absoluto del componente:** p99 76.8ms está bien debajo del soft-blocker que aplican otros hooks (bloqueo >100ms). El hook nunca falla, solo overhead.

---

## Acceptance criteria SEC1

| Criterio | Status | Evidencia |
|---|---|---|
| Cobertura PII 10/10 nuevos types | PASS | tabla arriba |
| Falsos positivos ≤5% (logs reales 30d) | PENDING | requiere ejecución real durante 30d |
| Redact, no block (NUNCA bloquea writes) | PASS | hard rule en código (`return 0` siempre); rewrite in-place sin alterar exit |
| Latencia <30ms p99 | **FAIL** v1.0 (p99 76.8ms POS) | bench arriba; ver §Opciones |
| Scope acotado (NO archivos del usuario) | PASS | hard rule path filter en `_in_scope()` con whitelist explícita |

**Bloqueo M3 acceptance:** "cobertura <10/10 types nuevos OR bloquea writes" → SEC1 NO se rechaza por estos criterios (10/10 ✓, no block ✓). Latency es separado.

---

## Schema redaction log

`~/.claude/memory/aidefence-redactions.jsonl` — append-only audit trail.

```json
{
  "ts": "2026-05-04T04:19:04Z",
  "file": "/home/USER/.claude/memory/test-aidefence-sample.jsonl",
  "tool": "Write",
  "counts": {"EMAIL": 2, "SSN_US": 1, "CREDIT_CARD": 1, ...},
  "total": 10
}
```

Auto-skip: el archivo de log mismo (`aidefence-redactions.jsonl`) está en `SCOPE_DENY` para evitar recursión.

---

## Limitaciones v1.0 (documentadas)

1. **Hooks que escriben directo al disco (no via Edit/Write/MultiEdit) NO son interceptados.** Ejemplos: `passive-capture-hook.py` escribe a `passive-captures-pending.jsonl` directamente. Si el `new_string` interceptado contenía PII, queda en pending sin redact. **Mitigación parcial:** el primer Edit posterior al pending file sí redacta (rare path real, ya que pending es solo escrito por el hook).
   - **v1.1 plan:** invocar redacción explícita en hooks productores (passive-capture, bitacora, etc.) antes de write. Acoplamiento aceptable a cambio de cobertura completa.
2. **NO LLM judge.** Solo regex + heurística (Luhn, IP class). PII contextual (nombres de personas en prosa, fechas DOB sin formato) NO se detecta. v2.0 si métrica empírica lo justifica.
3. **NO sanitiza path components.** Solo `/home/X/` y `/Users/X/` y `C:\Users\X\`. Otros paths con username embebido (custom mounts, `/srv/X/`) no.
4. **Latencia documentada** (§Latencia arriba). Pendiente decisión creator.

---

## Operación

### Hook (automático)
PostToolUse Write|Edit|MultiEdit. Solo actúa si el target match el scope whitelist.

### Audit
```bash
# Ver todas las redacciones del último mes
grep "$(date '+%Y-%m')" ~/.claude/memory/aidefence-redactions.jsonl | wc -l

# Ver counts por type acumulados
python3 -c "
import json, collections
c = collections.Counter()
for ln in open('$HOME/.claude/memory/aidefence-redactions.jsonl'):
    if ln.strip():
        e = json.loads(ln)
        for t, n in e.get('counts', {}).items():
            c[t] += n
for t, n in c.most_common():
    print(f'{t:20s} {n}')
"
```

### Tuning
No hay env vars en v1.0. Para ajustar patterns: editar `~/.claude/helpers/helix-aidefence-hook.py` y agregar/quitar entries en `_redact_text()`. Re-bench después.

---

## Histórico

- 2026-05-04 v1.0: implementación inicial. 10/10 PII types PASS. Redact-no-block PASS. Scope acotado PASS. **Latency p99 76.8ms POS — NO cumple criterio <30ms.** Pending decisión creator entre (a) aceptar v1.0 con plan v2.0 nativo, (b) re-spec criterio a <80ms, (c) bloquear hasta TRANCH 3 rewrite.
- 2026-05-04 v1.0 ACK: **creator (ftuga) aceptó opción (a)** — v1.0 con p99 ~77ms aceptable, plan v2.0 rewrite nativo cuando SEC1 sea hot path. SEC1 cuenta como TRANCH 2 [4/6] DONE con caveat de latencia documentado.
