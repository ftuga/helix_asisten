# HELIX-NAV — Navegador interno con cuarentena (plan REQ)

> Fecha: 2026-07-15 · Estado: ACTIVO (F1-F3 completas, 22/22 tests)
> Review adversarial independiente (code-reviewer) en 2 rondas: 1a ronda 8 findings
> (C-1/H-1/H-2/H-3/M-1..M-4/L-1..L-4), 2a ronda verificó fixes y reabrió 2 (M-2 --js
> SSRF por redirect a IP literal — cerrado gateando --js tras opt-in + quitando
> --no-sandbox; y title/final_url sin sanear en el header — cerrado via _clean_field).
> Ambos cerrados y con test. --js queda opt-in HONESTO (HELIX_NAV_ALLOW_JS=1) porque
> chromium sigue redirects a IPs literales que el gate no puede interceptar.
> Estado histórico abajo.

> Fecha original: 2026-07-15 · Estado inicial: EN CONSTRUCCIÓN
> Origen: auditoría de navegación 2026-07-15 — el contenido web entra al contexto de Claude
> CRUDO y los hooks HSL (L1 injection, L2 egress) solo detectan POST-HOC.
> Decisión: convertir detección post-hoc en prevención estructural con un pipeline
> de navegación propio. Coherente con D2 (100% local) y D3 (bash+python).

## META

Que NINGÚN byte de contenido web crudo entre al contexto de Claude. Todo fetch pasa por:

```
URL/query → [1] gate egress (allowlist + first-seen, POR CADA redirect hop)
          → [2] fetch aislado (raw a ~/.helix/memory/nav-cache/, nunca a contexto)
          → [3] cuarentena (strip zero-width/bidi, NFKC homoglifos, redact patrones
                inyección, redact base64 largo, readability HTML→markdown)
          → [4] destilación Capa 0 opt-in (helix-scout; sandbox semántico:
                una inyección debe sobrevivir el resumen de un LLM sin tools)
          → [5] entrega digest + audit (egress-audit.jsonl + nav-audit.jsonl)
```

## COMPONENTES

| Artefacto | Ubicación | Capa idioma |
|---|---|---|
| `helix-nav.py` (pipeline core) | `~/helix_asisten/scripts/` | 6 (EN) |
| `helix-nav.sh` (wrapper CLI) | `~/helix_asisten/scripts/` | 6 (EN) |
| `helix-nav-gate-hook.sh` (PreToolUse WebFetch\|WebSearch) | `~/.helix/helpers/` | 6 (EN) |
| Cache + raw quarantine | `~/.helix/memory/nav-cache/<sha256-url>/` | — |
| Audit | `egress-audit.jsonl` (tool=helix-nav) + `nav-audit.jsonl` (stats saneo) | 3 (EN) |
| Tests | `~/helix_asisten/scripts/tests/test-helix-nav.sh` | 6 (EN) |

## CLI

```
helix-nav.sh <url> [--raw-sanitized] [--distill "pregunta"] [--js] [--no-cache]
             [--max-chars N] [--gate-check]
helix-nav.sh search:"query"          # búsqueda local vía DuckDuckGo HTML (sin JS)
```

- Default: markdown saneado (readability) con header de metadata (dominio, trust,
  hits de saneo, cache hit/miss).
- `--distill`: paso 4 vía `capa0.sh` (respeta HW policy; timeout → fallback a
  raw-sanitized con banner UNTRUSTED).
- `--js`: render con chromium headless (`--headless=new --dump-dom`) si existe el
  binario; si no, error accionable. Mismo pipeline de saneo después.
- `--gate-check`: solo evalúa el gate (ALLOW / FIRST_SEEN / BLOCKED) — testeable.

## POLÍTICA DE GATE

| Dominio | Comportamiento default | `HELIX_NAV_STRICT=1` |
|---|---|---|
| known (egress-known-domains.txt) | fetch normal | igual |
| first-seen | fetch permitido + saneo forzado + banner UNTRUSTED + auto-add a known (consistente con SEC2) | BLOCKED (exit 3) |
| en blocklist futura | BLOCKED | BLOCKED |

Cada hop de redirect re-pasa el gate (mitiga open-redirect de dominio known → malicioso).

## HOOK `HELIX_NAV_ENFORCE` (reversibilidad D5-style)

- `advisory` (default): WebFetch a dominio first-seen → stderr sugiere helix-nav. Sin ruido en known.
- `strict`: WebFetch a first-seen → exit 2 (bloquea, redirige a helix-nav). WebSearch nunca se bloquea (los snippets los cubre L1 post-hoc).
- `off`: hook inerte.
- Config: env `HELIX_NAV_ENFORCE` o `~/.helix/config/helix-nav.conf`.

## AMENAZAS CUBIERTAS (delta vs status quo)

1. Prompt injection en contenido web → redactado ANTES de entrar a contexto (hoy: alerta después).
2. Zero-width/bidi/homoglifos → strip/normalize NFKC (hoy: solo alerta).
3. Open redirect known→malicioso → gate por hop (hoy: sin cobertura).
4. Exfil por query string → sanitización SEC2 reutilizada en audit.
5. Bypass del network-egress-hook vía scripts que hacen curl interno → helix-nav se auto-gatea (los demás scripts siguen siendo gap conocido — anotado para HSL).

## NO CUBIERTO (honesto)

- PDFs y binarios (out of scope v1; mensaje accionable).
- WebSearch nativo sigue existiendo (search local DDG es complemento, no reemplazo).
- Imágenes con texto malicioso (OCR out of scope).
- La destilación Capa 0 puede perder detalle → `--raw-sanitized` siempre disponible.

## CRITERIOS DE ACEPTACIÓN

1. Fixture con zero-width + jailbreak + `<script>` → output limpio: 0 zero-width, patrón redactado con marker, sin script.
2. Segunda invocación misma URL → cache hit (sin egress, verificable en audit).
3. Redirect a dominio no-known con `HELIX_NAV_STRICT=1` → BLOCKED.
4. `--distill` responde con helix-scout o hace fallback limpio si timeout.
5. Review de seguridad independiente sin hallazgos CRITICAL/HIGH abiertos (lección sprint 4: barrer la clase — interpolación en `-c`, /tmp, command injection en args).
6. Reversible: quitar hook = `HELIX_NAV_ENFORCE=off`; el pipeline es opt-in por naturaleza.

## FASES

- F1: core (gate+fetch+cuarentena+cache+audit) + tests fixture local ← ✅ completa
- F2: Capa 0 distill + search DDG + modo --js ← ✅ completa
- F3: hook PreToolUse + doctrina CLAUDE.md + commit ← ✅ completa (merge a main cf64f35)

## VALIDACIÓN REAL (2026-07-15)
- first-seen real (rfc-editor.org): banner UNTRUSTED disparó, redirect de 2 hops re-gateado, saneo limpio. ✓
- distill helix-scout: 15.4s end-to-end, resumen correcto de 1 frase, banner force_untrusted en output distilado. ✓ → confirma que distill debe quedar OPT-IN (latencia real ~15s), no default.
- Gate hook queda en `advisory` mientras se acumula data en `nav-audit.jsonl`; evaluar `strict` tras 2-3 semanas de uso real (no antes — sería fricción sin datos).

---

## F4 — DIFERIDO (planes documentados, NO implementar sin gate)

### F4.1 — OCR de imágenes (texto malicioso en imágenes)
**Problema:** hoy una imagen con instrucciones de inyección (texto renderizado en PNG/JPG) pasa invisible — el pipeline solo ve el `alt`. Un atacante puede poner "ignore all previous instructions" como imagen y evadir toda la cuarentena de texto.
**Diseño propuesto:**
- Nuevo paso opcional `--ocr` en helix-nav: extrae `<img src>` del HTML saneado, descarga cada imagen POR EL MISMO GATE (allowlist + IP fijada — una imagen es egress igual que una página), corre OCR local (tesseract via `pytesseract`, o un modelo de visión Ollama si el HW lo aguanta), y pasa el texto extraído por `sanitize_text` como cualquier otro contenido.
- El texto OCR se marca explícito en el output (`[OCR de imagen N]`) para que yo sepa que su procedencia es una imagen, no el DOM.
**Gates de activación (NO implementar hasta que se cumplan):**
- G1: aparezca ≥1 caso real donde una imagen cargue instrucciones (registrar en `nav-audit.jsonl` un campo `images_seen` primero, para medir si el vector siquiera ocurre).
- G2: `tesseract` disponible local (cero egress — coherente con D2) o modelo de visión Ollama validado en HW.
- G3: costo/latencia aceptable — OCR por imagen puede ser segundos; debe quedar opt-in duro, nunca en el path default.
**Amenaza nueva que introduce:** descargar imágenes amplía la superficie de egress (cada `<img>` es un fetch). El gate por-imagen es obligatorio; sin él, OCR abre un canal de exfil (img src con querystring a dominio atacante). Por eso G2/G3 antes de tocar código.

### F4.2 — Navegación profunda (multi-página / sesión / crawl)
**Problema:** hoy helix-nav es single-shot (una URL → un digest). No sigue enlaces, no mantiene cookies/sesión, no llena formularios, no navega flujos autenticados. Para investigar un tema o auditar un sitio hace falta profundidad.
**Diseño propuesto (por capas, cada una con su propio gate):**
- **N1 — crawl acotado:** `--crawl <depth> --same-domain` — sigue enlaces del markdown saneado hasta N niveles, SOLO dentro del dominio origen (o allowlist), cada URL re-pasa el gate completo. Dedup por hash de URL. Presupuesto duro de páginas (`--max-pages`) con `log()` de lo truncado (regla no-silent-caps). Cada página cae al cache; el digest final es una síntesis Capa 0 de todas.
- **N2 — sesión/cookies:** jar de cookies POR DOMINIO, aislado, nunca compartido cross-domain (evita CSRF/leak de sesión). Solo en `--js` o con manejo explícito de Set-Cookie. Cookies nunca a contexto ni a disco fuera del jar temporal.
- **N3 — navegación autenticada / formularios:** llenar y enviar forms (login, búsquedas). ALTO RIESGO — acciones mutantes, credenciales. Requiere council propio: un crawl que hace POST puede crear/borrar datos. NO diseñar en detalle hasta council.
**Gates de activación:**
- G1 (N1): pedido real de "investiga/audita este sitio" que single-shot no resuelva. Medir cuántas veces encadeno helix-nav manualmente sobre el mismo dominio — si ≥3 en una sesión, N1 se justifica.
- G2 (N2): N1 estable + caso que requiera estado entre páginas.
- G3 (N3): council obligatorio (acciones mutantes + credenciales). Reutilizar el protocolo de overrides D5.C si toca doctrina de egress.
**Por qué diferido:** N1 es tentador pero un crawler mal acotado es un cañón de egress (amplificación N^depth) y de tokens. El single-shot actual + `search:` cubre el 80% de los casos. Construir N1 solo cuando el uso real muestre el 20% restante, con presupuesto de páginas y gate por-URL desde la línea 1.

### F4.3 — Otros (menor prioridad)
- Blocklist explícita de dominios (hoy solo hay allowlist + first-seen; una blocklist da defensa en profundidad).
- Telemetría de ahorro de tokens (comparar bytes_raw vs chars_clean ya en `nav-audit.jsonl` → reporte agregado).
- Homoglyph folding cross-script (confusables Cyrillic→Latin antes de match de inyección) — flagged por review como hardening inherente, no bloqueante.

> Regla dura para TODO F4: cada capacidad nueva pasa por su gate ANTES de escribir código, y el gate egress por-URL/por-imagen es no-negociable — la lección de esta sesión (review adversarial cerró SSRF que el autor no vio) aplica doble cuando se amplía la superficie de red.
