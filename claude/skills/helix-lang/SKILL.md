---
name: helix-lang
description: Protocolo universal de comunicación inter-agente. Gramática fija + vocabulario declarado por sesión. ~60% compresión en mensajes, ~97% en contexto compartido (S:hash). Usar en cualquier dominio en Capa 2 y 3 de Helix.
allowed-tools: Read, Write, Edit, Bash
version: 2.0
---

# HELIX-LANG v2 — Protocolo Universal Inter-Agente

> **Separación fundamental:** la gramática es universal y fija. El vocabulario se declara por sesión y se hashea. El mismo protocolo sirve para software, investigación, marketing, soporte, análisis, o cualquier dominio.

---

## Rendimiento medido (benchmark v1.1)

| Métrica | Valor |
|---------|-------|
| Compresión de tokens en mensajes | ~59% (medido) |
| Compresión de chars en mensajes | ~64% (medido) |
| Compresión via S:hash (contexto) | ~97% (medido) |
| Ahorro combinado total | ~65% (medido) |

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
