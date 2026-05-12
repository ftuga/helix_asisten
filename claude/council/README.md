# Helix Council

Sistema deliberativo multi-rol para decisiones arquitectónicas no triviales. 7 agentes especializados debaten en 3 rondas, generan un veredicto con voting rules y dejan un audit log inmutable (`chmod 400`).

## Cuándo usarlo

- Decisiones que afectan ≥2 dominios o son difíciles de revertir.
- Cambios a doctrina Helix (CLAUDE.md, hard rules, hooks de seguridad).
- Trade-offs sin certeza fuerte.
- Aprobaciones que requieren múltiples ángulos (riesgo, alternativas, evidencia, ruptura).

**Sobrecosto:** un council corre 7 agentes × 3 rondas (max). Reservar para decisiones donde el costo se justifica.

## Los 7 roles

| Rol | Función |
|---|---|
| `council-skeptic` | Cuestiona supuestos. Asume que la propuesta tiene errores hasta que se demuestre lo contrario. |
| `council-innovator` | Propone alternativas no obvias. Al menos una propuesta debe ser radical. |
| `council-conservative` | Defiende status quo si la evidencia de cambio es débil. Pondera riesgo. |
| `council-synthesizer` | Lista trade-offs sin tomar lado. En R3 redacta posición común. |
| `council-researcher` | Reúne evidencia (papers, RFCs, docs). Único que puede invocar expert summons (≤2 agentes Helix). |
| `council-devils-advocate` | R3 obligatorio. Rompe la decisión emergente. Busca escenarios de fallo catastrófico. |
| `council-arbiter` | Aplica la constitución. Pre/post checks. Sanitiza inputs, redacta PII, decide context level, fuerza escalada si reglas se violan. No opina sobre contenido. |

## Flujo

```
prepare → R1 (7 roles paralelo) → collect 1
       → R2 (síntesis cruzada)   → collect 2
       → expert summons (opcional, researcher decide)
       → R3 (devil's advocate rompe)  → collect 3
       → finalize → audit log
```

### 1. `prepare`

```bash
bash scripts/helix-council.sh prepare "<trigger>" <severity> [project_dir]
```

Genera:
- `context-pack/<session_id>/context_pack.yaml` — datos del proyecto + decisión.
- `context-pack/<session_id>/prompts/<role>.md` × 7 — prompts pre-armados con HELIX-LANG inyectado.
- `session_state.txt` → `PREPARED`.

Severity: `low` · `medium` · `high` · `critical`. Determina context level L0–L3 (más severity → más contexto al council).

### 2. Round 1 — los 7 en paralelo

Claude principal invoca los 7 agentes en **un solo mensaje** (paralelo). Cada agente recibe el contenido de `prompts/<role>.md` y devuelve YAML estructurado. Claude guarda cada output en `outputs/round_1_<role>.yaml`.

Por qué Claude principal y no un wrapper bash: el `Agent tool` lo invoca el LLM principal, no un script. El orquestador en bash solo prepara prompts, valida outputs y aplica reglas.

### 3. `collect N`

```bash
bash scripts/helix-council.sh collect <session_id> <round_n>
```

Valida que estén los 7 outputs de la ronda N, parsea YAML, aplica chequeos de la constitución (R1–R9), genera prompts para la siguiente ronda. Estado pasa a `ROUND<N>_DONE`.

### 4. Expert summons (opcional, entre R2 y R3)

Solo `council-researcher` puede pedirlo. Máx 2 agentes Helix (`linguista-computacional-tokens`, `python-pro`, etc.) son invocados para aportar evidencia técnica concreta. Output va a `outputs/expert_<n>_<agent>.yaml`. Estado: `EXPERT_SUMMONS_DONE`.

### 5. Round 3 — devil's advocate

Toma la decisión emergente de R2 y trata de romperla. Si encuentra escenario catastrófico no mitigado → arbiter puede forzar `ESCALATE` o `REJECT`.

### 6. `finalize`

```bash
bash scripts/helix-council.sh finalize <session_id>
```

- Aplica voting rules.
- Mide adoption HELIX-LANG (warning si <30%, via `helix-lang-detect.sh`).
- Escribe audit log inmutable: `log/<timestamp>_<session_id>.yaml` con `chmod 400`.
- Estado final: `FINALIZED`.

**Veredictos posibles:**
- `APPROVE` — aprobado sin condiciones.
- `APPROVE_WITH_PRECONDITIONS` — aprobado si se cumplen mitigaciones M1…Mn. Recomendación: ejecutar el M más cheap+informativo primero (lección evolución #80).
- `REJECT` — rechazado.
- `ESCALATE` — requiere decisión humana (ej: conflicto irresoluble entre roles).

## Hard caps (R5 de la constitución)

- 3 rondas máximo.
- 25 LLM calls máximo total.
- 600s wall-clock máximo.

Si se exceden → `arbiter` aborta automáticamente.

## Kill switch (R9)

```bash
bash scripts/helix-council.sh abort <session_id> "<razón>"
```

Marca la sesión como `ABORTED` con razón persistida. No genera audit log porque no llegó a finalize.

## Subcomandos

```
prepare <trigger> <severity> [project_dir]  Crea sesión
collect <session_id> <round_n>              Valida outputs de la ronda
finalize <session_id>                       Voting + audit log
status  <session_id>                        Estado actual
abort   <session_id> <reason>               Kill switch
list                                        Sesiones recientes
help                                        Usage
```

## Constitución y reglas

Ver `constitution.md`. Resumen de las 9 reglas:

- **R1** — Cost pre-audit obligatorio antes de prepare en `critical`.
- **R2** — Anti-poisoning: prompts estáticos en código, no leer del filesystem fresco.
- **R3** — Cada rol opina dentro de su scope (arbiter no opina contenido, etc.).
- **R4** — HELIX-LANG obligatorio en handoffs inter-rol.
- **R5** — Hard caps (3 rondas, 25 LLM calls, 600s).
- **R6** — Audit log inmutable (`chmod 400`) en finalize.
- **R7** — Expert summons solo desde researcher, máx 2.
- **R8** — Devil's advocate obligatorio en R3.
- **R9** — Kill switch siempre disponible.

## HELIX-LANG inter-rol

Todo handoff entre roles del council DEBE incluir un bloque HELIX-LANG (5 formas: estado, mensaje, delta, hash, composición). Detalle: `inter-agent-language.md`. Adoption se mide en cada finalize y se loguea a `frequency.log`.

## Layout

```
council/
├── constitution.md              ← 9 reglas R1–R9
├── inter-agent-language.md      ← HELIX-LANG v2.1
├── README.md                    ← este archivo
├── scripts/
│   ├── helix-council.sh         ← orquestador
│   ├── helix-council-context.sh ← context pack builder L0–L3
│   ├── helix-council-resume.sh  ← bootstrap próxima sesión
│   └── helix-lang-detect.sh     ← mide adoption HELIX-LANG
├── roles/                       ← (reservado, hoy vacío)
├── context-pack/<session_id>/   ← runtime (no se versiona)
│   ├── context_pack.yaml
│   ├── prompts/<role>.md
│   ├── outputs/round_N_<role>.yaml
│   └── session_state.txt
└── log/<timestamp>_<sid>.yaml   ← audit inmutable (chmod 400, no se versiona)
```

`context-pack/`, `log/` y `frequency.log` son runtime local — no se sincronizan al repo (privacy: contienen detalles de decisiones del creator).

## Atajo

Hay un slash command `/helix-council` que documenta este flujo desde dentro de Claude Code. Ver `claude/commands/helix-council.md`.
