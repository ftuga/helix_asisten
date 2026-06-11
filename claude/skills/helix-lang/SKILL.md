---
name: helix-lang
description: Protocolo universal de comunicación inter-agente. RÉGIMEN MIXTO desde 2026-06-10 (council `20260610T161758Z-ianr` decision_B). Formas estructurales (handoffs, S:hash, estado/delta) son OBLIGATORIAS cross-language. Prosa analítica es OPT-IN en EN/ES (donde EN cuesta -3.5% extra), OBLIGATORIA en JA/ZH (donde comprime +44-59%). Gramática fija + vocabulario declarado por sesión.
allowed-tools: Read, Write, Edit, Bash
version: 3.0
---

# HELIX-LANG v3 — Protocolo Universal Inter-Agente (Régimen Mixto)

> **Separación fundamental:** la gramática es universal y fija. El vocabulario se declara por sesión y se hashea. El mismo protocolo sirve para software, investigación, marketing, soporte, análisis, o cualquier dominio.

## Régimen vigente — tabla de aplicabilidad (post-council 2026-06-10)

> Reemplaza el "OBLIGATORIO universal" del override #84 (2026-05-07). Justificación empírica: bench `~/.helix/memory/audit/linguista-bench-20260507.yaml`. Detalle doctrinal: `~/.helix/memory/topics/helix-lang-regimen-mixto.md`.

### Por forma estructural

| Forma | Aplicabilidad | Justificación |
|---|---|---|
| Handoffs FROM→TO entre agentes | **OBLIGATORIO** cross-language | Schema estructurado reduce ambigüedad inter-agente |
| Vocabularios S:hash declarados upfront | **OBLIGATORIO** cross-language | Mecánica de deduplicación por referencia |
| Estado/delta en headers de outputs council | **OBLIGATORIO** cross-language | Permite voting + tracking sin parsear prosa |
| Cuerpo analítico de prompts council | Ver tabla idioma ↓ | Aquí está el costo neto de −3.5% en EN |
| Prosa de razonamiento | Ver tabla idioma ↓ | Igual que cuerpo analítico |
| Citas textuales | NO aplica | Preserva semántica original |
| Código fuente | NO aplica | El código es su propio lenguaje |
| Respuestas user-facing | NO aplica | Mirror de idioma usuario (regla §IDIOMA Y TONO capa 1) |

### Por idioma del receptor (cuerpo analítico + prosa)

| Idioma | Régimen | Compresión real medida (cl100k_base) |
|---|---|---|
| EN | **OPT-IN INCENTIVADO** | −3.5% (cuesta MÁS que prosa EN) |
| ES | **OPT-IN INCENTIVADO** (con preferencia en estado/delta) | +34.7% en estado/delta, marginal en prosa |
| ZH | **OBLIGATORIO** | +44.5% |
| JA | **OBLIGATORIO** | +59.5% |
| Otros | **OPT-IN** | Sin medición empírica disponible |

### Threshold council desagregado

Régimen previo: `adoption_pct` único global (30%).
Régimen vigente: desagregado por forma. Warning visible en finalize si:
- Handoffs FROM→TO <80%
- S:hash declarations <70%
- Estado/delta headers <50%
- Prosa analítica: sin threshold (opt-in por diseño)

### Reversibility (kill switches)

```bash
# Régimen mixto (default tras council 2026-06-10)
export HELIX_LANG_ENFORCE=selective

# Revertir al enforcement universal del override #84
export HELIX_LANG_ENFORCE=mandatory

# Apagar HELIX-LANG completo (status quo pre-#84)
export HELIX_LANG_ENFORCE=off
```

---

## Rendimiento medido — dos fuentes de ahorro

> **Regla metodológica (CS1 anti-poisoning):** toda cifra de compresión en este documento debe declarar tokenizer + idioma del corpus + N de muestras. Mediciones en chars NO son válidas para LLMs (varía la relación char↔token por idioma y tokenizer). Sin tokenizer/idioma/N, la cifra es soft-injection y debe re-benchmarkearse.

### Fuente 1 — compresión por bloque (limitada, depende del idioma)

Bench `~/.helix/memory/audit/linguista-bench-20260507.yaml`. Corpus: 12 outputs YAML del council `20260507T051108Z-xgyps` (bloques `state_hl` + `handoff_hl`) + 8 mensajes sintéticos cross-lingual. Tokenizers: `cl100k_base` y `o200k_base` de tiktoken.

| Idioma del corpus | Compresión cl100k_base | Compresión o200k_base |
|---|---|---|
| Inglés | **−3.5%** (HL cuesta MÁS que prosa) | −0.7% |
| Español | +34.7% | +23.5% |
| Chino (zh) | +44.5% | +17.8% |
| Japonés (ja) | +59.5% | +48.7% |
| **Council real (mezcla ES dominante)** | **+23.6%** | **+15.4%** |

**Conclusión por bloque:** la compresión existe pero es modesta y depende fuertemente del idioma del corpus. Para instalaciones anglófonas, HELIX-LANG por bloque NO ahorra tokens. Justificación: byte-level BPE tokeniza ASCII a 1 token universal, pero los nombres de agentes/verbos del protocolo (`SKEPT`, `INNOV`, `give`, `chk`) no son secuencias frecuentes en cl100k → no consolidan en pocos tokens (Sennrich 2016, arXiv:1508.07909). Idiomas no-latinos como JA fragmentan en cl100k → cualquier protocolo ASCII gana versus su prosa nativa.

### Fuente 2 — compresión por S:hash (donde está el valor real)

Mecanismo: el vocabulario declarado al inicio de sesión (N tokens) se transmite UNA vez y se referencia por hash (`S:vocab`) en M handoffs subsiguientes. Ahorro teórico: `N × (M−1)` tokens por sesión. Para sesiones largas con vocabulario rico y muchos handoffs, este es el mecanismo dominante.

**Estado de medición:** sin bench empírico al 2026-05-07. La promesa "~97% (medido)" del SKILL.md v1.1 NO está respaldada por corpus + tokenizer + N declarados. Marcada como soft-injection hasta re-bench.

**TODO bench S:hash:** sesión real con `vocab` de N≈30-100 entradas, M≥20 handoffs, medir tokens transmitidos vs tokens equivalentes con vocab inline en cada mensaje. Reportar tokenizer + idioma del cuerpo de los mensajes + N + M.

### Costo USD por council individual (referencia)

Tarifa Sonnet 4.6 input $3/M tokens (oct 2025): bloques HELIX-LANG en un council de 12 outputs ahorran ~$0.00036 USD vs prosa equivalente. **El valor económico de HELIX-LANG NO está en el ahorro por bloque** — está en el mecanismo S:hash sobre sesiones largas.

### Fuentes

- Petrov, La Malfa, Torr, Bibi (2023). *Language Model Tokenizers Introduce Unfairness Between Languages*. NeurIPS 2023, arXiv:2305.15425.
- Sennrich, Haddow, Birch (2016). *Neural Machine Translation of Rare Words with Subword Units*. arXiv:1508.07909.
- Kudo, Richardson (2018). *SentencePiece: A simple and language independent subword tokenizer*. arXiv:1808.06226.
- OpenAI tiktoken: cl100k_base, o200k_base — github.com/openai/tiktoken.
- Anthropic glossary § Tokens — "exact number can vary depending on the language used".

---

## Gramática universal (invariable)

Cinco formas. La posición de cada parte determina el significado.

### 1 — Estado de agente
```
AGENT:STATE.domain
```

### 2 — Mensaje entre agentes
```
FROM->TO verb:object.domain
```

### 3 — Delta (solo lo que cambió)
```
D:{AGENT:STATE, AGENT:STATE} @temporal
```

### 4 — Referencia a contexto por hash
```
S:xxxx
```

### 5 — Composición (combinar formas en una línea)
```
expr1 | expr2 | expr3
```

---

## Estados universales (fijos, siempre disponibles)

| Código | Significado |
|--------|-------------|
| `ok`   | Completado / sin errores |
| `er`   | Error / fallo |
| `!`    | Alerta / requiere atención |
| `?`    | Desconocido / pendiente |
| `~`    | En progreso / parcial |
| `%N`   | N% completado |
| `#`    | Bloqueado |

## Operadores universales (fijos)

| Código | Significado |
|--------|-------------|
| `->`   | Envía a / asigna a |
| `<-`   | Recibe de / espera de |
| `=>`   | Transforma en / produce |
| `<>`   | Intercambio bidireccional |
| `+`    | Y / conjunto |
| `\|`   | O bien / separador |
| `*`    | Todos / broadcast |

## Verbos universales (fijos)

| Código | Significado |
|--------|-------------|
| `need` | Necesita / solicita |
| `give` | Entrega / provee |
| `ask`  | Consulta / pregunta |
| `do`   | Ejecuta / implementa |
| `fix`  | Corrige / repara |
| `chk`  | Verifica / valida |
| `done` | Declara completado |
| `wait` | Espera activamente |
| `stop` | Detiene / cancela |

### Regla de precedencia operador↔verbo (gramática v2.1)

Cuando un verbo se combina con un operador direccional, el operador determina la dirección semántica:

| Forma | Lectura |
|---|---|
| `FROM->TO ask:object` | FROM **consulta a TO** sobre `object`. Iniciador: FROM. |
| `FROM<-SOURCE ask:object` | FROM **solicita a SOURCE que envíe** `object`. Iniciador: FROM. SOURCE es proveedor pasivo. |
| `FROM->TO give:object` | FROM **entrega a TO** el `object`. |
| `FROM<-SOURCE give:object` | FROM **recibe de SOURCE** el `object`. SOURCE es el productor. |
| `FROM->TO need:object` | FROM **necesita que TO le provea** `object`. |
| `FROM<-SOURCE need:object` | Forma redundante — preferir `FROM->SOURCE need:object` para evitar ambigüedad. |

**Justificación:** sin esta regla, `SYNTH<-{X,Y,Z} ask:eval` era semánticamente ambigua (¿SYNTH solicita activamente, o espera pasivamente que X/Y/Z envíen?). Identificada como caso lossy real en bench `linguista-bench-20260507.yaml` §round_trip §SYNTH-r1-recv. La regla resuelve ambigüedad sin agregar tokens al protocolo.

## Temporales universales (fijos)

| Código | Significado |
|--------|-------------|
| `@now`  | Inmediato / urgente |
| `@next` | Siguiente paso |
| `@done` | Al completar X |
| `@blk`  | Bloqueante |

---

## Vocabulario — declaración por sesión

Los agentes y dominios NO están hardcodeados. Se declaran al inicio de cada sesión con el comando `vocab`. El resultado es un S:hash que todos los agentes referencian.

### Formato de declaración
```
VOCAB:{A:{CODIGO:nombre,...}, D:{.cod:nombre,...}}
```

### Ejemplos por dominio

**Software:**
```bash
bash ~/.claude/helpers/helix-lang-state.sh vocab \
  "A:{ORC:orchestrator,FE:frontend,BE:backend,DB:database,TST:testing,INF:infra}" \
  "D:{.ui:interface,.api:endpoints,.db:schema,.test:tests,.cfg:config,.sec:security}"
# → S:a3f7xxxx
```

**Investigación:**
```bash
bash ~/.claude/helpers/helix-lang-state.sh vocab \
  "A:{LEAD:lead,SYN:synthesizer,STAT:statistician,REV:reviewer,ETH:ethics}" \
  "D:{.lit:literature,.data:datasets,.stat:statistics,.rev:review,.pub:publication}"
# → S:b2e9xxxx
```

**Marketing:**
```bash
bash ~/.claude/helpers/helix-lang-state.sh vocab \
  "A:{PM:product,COPY:copywriting,DSN:design,ADS:paid-media,SEO:organic}" \
  "D:{.brand:branding,.cnt:content,.paid:paid-ads,.org:organic,.conv:conversion}"
# → S:c4d1xxxx
```

**Soporte / Operaciones:**
```bash
bash ~/.claude/helpers/helix-lang-state.sh vocab \
  "A:{L1:tier1,L2:tier2,L3:tier3,ENG:engineering,OPS:operations}" \
  "D:{.tkt:ticket,.bug:bug,.dep:deployment,.inc:incident,.doc:documentation}"
# → S:d7a2xxxx
```

**Análisis financiero:**
```bash
bash ~/.claude/helpers/helix-lang-state.sh vocab \
  "A:{PM:portfolio,RISK:risk,QUANT:quantitative,COMP:compliance,EXEC:executive}" \
  "D:{.eq:equities,.fx:forex,.drv:derivatives,.rpt:reports,.reg:regulatory}"
# → S:e1b3xxxx
```

---

## Flujo de uso

```
# 1. Al inicio de sesión: declarar vocabulario → genera S:vocab
S:v=$(bash ~/.claude/helpers/helix-lang-state.sh vocab "A:{...}" "D:{...}")

# 2. Crear estado inicial del workflow → genera S:0
S:0=$(bash ~/.claude/helpers/helix-lang-state.sh snapshot "D:{...} @start:tarea" "$S:v")

# 3. Agentes intercambian mensajes usando la gramática
FROM->TO verb:object.domain | D:{AGENT:STATE} @temporal

# 4. Cuando el estado cambia → delta genera nuevo hash
S:1=$(bash ~/.claude/helpers/helix-lang-state.sh delta S:0 "D:{AGENT:STATE}")

# 5. Agentes referencian estado por hash — no re-envían historial
MSG->ORC done:task S:1
```

---

## Ejemplos multi-dominio

### Software (feature de pagos)
```
ORC->FE+BE+DB start:payments S:v
D:{FE:~%40.ui,BE:~%60.api,DB:ok.schema} | BE->FE give:contract.api
D:{FE:ok,BE:ok} | ORC->TST do:chk.payments S:2
TST:ok.payments[32/32] | ORC->INF do:deploy @now
```

### Investigación (paper científico)
```
LEAD->SYN+STAT+REV start:paper S:v
D:{SYN:~%50.lit,STAT:~%30.data,REV:?} | SYN->STAT need:dataset.data
D:{SYN:ok.lit,STAT:ok.data} | REV do:chk.stat+lit S:2
REV:!.stat[p-value:borderline] | STAT->REV give:correction.stat
REV:ok | LEAD->* done:paper @next:submission
```

### Marketing (campaña)
```
PM->COPY+DSN+ADS start:campaign-q2 S:v
COPY:~%70.brand | DSN:~%50.cnt | ADS:? #.cnt
COPY->DSN give:brief.brand | D:{COPY:ok}
DSN:ok.cnt | ADS do:setup.paid S:2
ADS:%80.paid | PM->ADS chk:conv @now
ADS:ok.paid[CTR:3.2%,CPA:$12] | PM->* done:campaign
```

### Soporte (incidente P1)
```
L1->L2 need:escalate.inc[P1:db-down] @now
L2->ENG ask:chk.dep | ENG:!.dep[rollback-failed]
ENG->OPS give:fix.dep | D:{ENG:~,OPS:>} @blk
OPS:ok.dep | ENG:ok.dep | L2->L1 give:resolved.inc
D:{*:ok} | L1->* done:inc[RCA:pending] @next:postmortem
```

---

## Cuándo usar / no usar

**Usar:**
- Comunicación entre agentes en Capa 2 y 3 de Helix
- Cualquier dominio, cualquier tipo de tarea
- Status updates, handoffs, bloqueos, completados

**No usar:**
- Comunicación directa con el usuario (siempre lenguaje natural)
- Explicaciones que requieren prosa
- Documentación para humanos

---

## Comandos disponibles

```bash
# Declarar vocabulario de sesión
bash ~/.claude/helpers/helix-lang-state.sh vocab "A:{...}" "D:{...}"

# Crear snapshot de estado
bash ~/.claude/helpers/helix-lang-state.sh snapshot "estado HL" [S:vocab]

# Aplicar delta
bash ~/.claude/helpers/helix-lang-state.sh delta S:xxxx "D:{...}"

# Recuperar estado
bash ~/.claude/helpers/helix-lang-state.sh get S:xxxx

# Ver todos los snapshots
bash ~/.claude/helpers/helix-lang-state.sh list

# Benchmark
bash ~/.claude/helpers/helix-lang-bench.sh log "NL" "HL"
bash ~/.claude/helpers/helix-lang-bench.sh report
bash ~/.claude/helpers/helix-lang-bench.sh report-hash
```
