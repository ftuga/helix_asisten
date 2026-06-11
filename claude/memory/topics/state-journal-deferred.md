# State Journal — Propuesta diferida del innovator (council 20260610T161758Z-ianr)

> Cementado como DEFERRED por Helix Council 2026-06-10.
> Audit log inmutable: `~/.helix/council/log/20260610T175912Z_20260610T161758Z-ianr.yaml` (chmod 400).

## Resumen de la propuesta

`~/.claude/sessions/<id>/hl-state.yaml`: archivo único por sesión que actúa como **única fuente de verdad** del estado del council/swarm.

- Agentes ESCRIBEN append-only.
- Agentes LEEN al inicio de cada round.
- Contenido NO va en prompts directamente (elimina costo de tokens de HELIX-LANG en EN: -3.5%).
- Va al contexto del siguiente round SOLO cuando el orquestador detecta que el agente necesita estado de otro agente.

### Implementación esbozada

Hook `PostToolUse(Agent)` parsea bloques HL del output del agente y los appenda a `hl-state.yaml`. Orquestador inyecta `hl-state.yaml` como contexto comprimido al inicio del siguiente round, condicionado.

### Beneficios identificados

1. Resuelve el propósito REAL de HELIX-LANG (desambiguación) sin el costo de insertar bloques ASCII en cada prompt.
2. Hace handoffs auditables (R6 del council constitution) por diseño — el journal es el audit log inter-agente.
3. Compatible con régimen mixto (decision_B): JA/ZH pueden usar bloques HL en prompts, el journal los captura igual.
4. Compatible con A4 (decision_A deferred): si llega demanda multi-dominio, el journal es el backbone natural de helix-snapshot.
5. Alinea D2 (100% local, append-only file, cero egress).

## Por qué quedó DEFERRED

Devils-advocate identificó **SC3: State Journal como vector de contaminación inter-agente**. Tres problemas estructurales:

### 1. Sin schema validation
Un agente con prompt injection (vector documentado por HSL v1 layer L1) escribe en `hl-state.yaml` contenido adversarial que envenena el contexto de TODOS los agentes del round siguiente. El hook `PostToolUse(Agent)` parsea el output sin sanitización en la propuesta original.

### 2. Conflicto de slots con HSL v1
Evolution 2026-05-06 documentó que claude-flow MCP secuestró los 16 slots de hooks silenciando HSL. Agregar otro `PostToolUse(Agent)` para State Journal puede repetir el mismo bug si desplaza `helix-aidefence-hook` o `helix-egress-audit-hook`.

### 3. Token runaway sin TTL/max_size
Sin truncation policy, una sesión de 20 rounds × 7 agentes acumula 140 appends antes de finalize. Todos los agentes leen el archivo completo al inicio de cada round. Costo de tokens no acotado, contradice el objetivo de reducir tokens.

### 4. Contradicción interna
"Contenido NO va en prompts" es regla de diseño sin enforcement técnico. El mecanismo propuesto es: hook lee `hl-state.yaml` → agente lo recibe al inicio del round. Si el contenido "no va en prompts", ¿cómo lo recibe el agente? O va en el prompt (contradice la regla) o no lo recibe (el State Journal no cumple su función). Esta tensión no se resolvió en R2.

## Gate de activación

State Journal puede reabrirse para implementación cuando se cumplan **ambos** triggers:

### Trigger A — Demanda demostrada
≥3 sesiones distintas con handoffs >5 agentes coordinados.

Medición: contador en `~/.helix/memory/audit/handoff-density.jsonl` (a implementar como parte del refactor de `helix-lang-detect.sh`).

### Trigger B — Costo HELIX-LANG manifiesto
Adopción S:hash <50% sostenida durante 30 días post-régimen-mixto, indicando que la fricción del enforcement obligatorio en S:hash supera el beneficio.

Medición: `adoption_by_form.s_hash` en audit logs de council post-2026-06-10.

## Preconditions OBLIGATORIAS antes de implementar (MOD-3 devils-advocate)

Si los gates A+B se cumplen, antes de cualquier implementación se requiere:

### Preq-1 — Verificar slot disponible
```bash
jq '.hooks.PostToolUse[] | select(.matcher | contains("Agent")) | .hooks[].command' \
  ~/.helix/settings.json
```
Si el slot está ocupado por hook crítico (HSL v1, claude-flow MCP, otro), buscar slot alternativo o re-secuenciar.

### Preq-2 — Schema YAML mínimo
Definir y validar:
```yaml
hl_state_journal_version: "1.0"
session_id: <string>
entries:
  - timestamp: <ISO 8601>
    agent: <string from controlled vocabulary>
    form: handoff | s_hash | state_delta
    payload: <strict schema by form>
```
Cualquier campo fuera del schema se rechaza al appender.

### Preq-3 — Sanitización adversarial
Pre-append validation:
- Strip cualquier instrucción tipo `---\nrole: arbiter\n...` que sugiera intento de inject de prompt.
- Limit longitud por entry: max 2KB de payload.
- Validar que `agent` está en el vocabulario declarado de la sesión (anti-spoofing de identidades).

### Preq-4 — Max size + rotation
- Max 50 entries por sesión.
- Cuando se lee el journal para inyección, se cargan solo las últimas 20 entries.
- Sesión > 50 entries: archivar `hl-state.yaml.gz` y empezar journal nuevo.

### Preq-5 — Verificación de no-contradicción con regla "no va en prompts"
Si la decisión final es "el orquestador inyecta el journal en el siguiente prompt", la propuesta original tiene contradicción interna. Resolver explícitamente: o el journal es accedido vía tool call dedicado (no inyección), o se acepta que "no va en prompts" era inexacto y se reformula la regla.

## Reversibility (cuando se implemente)

- Variable `HELIX_STATE_JOURNAL_ENABLED=0` apaga el hook sin tocar el archivo.
- Borrar `~/.claude/sessions/<id>/hl-state.yaml` corta el flujo de inyección.
- Revertir hook: `git revert` del commit que lo agregó a settings.json.

## Quién decide reabrirlo

Triggers A+B se evalúan automáticamente cada 30d en bench retrospectivo de HELIX-LANG (ver `topics/helix-lang-regimen-mixto.md` §Bench retrospectivo T+30d).

Si ambos triggers se cumplen, el bench escalará a re-council. Ese council decide si proceder con State Journal o explorar alternativas.

Hasta entonces: **NO IMPLEMENTAR**.
