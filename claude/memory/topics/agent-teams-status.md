# Agent Teams (Capa 3) — Status real

Última verificación: 2026-04-27

## Promesa documentada

CLAUDE.md afirmaba "Agent Teams nativo (mailbox). Ya habilitado en settings.json". Evolución #7 del 2026-04-11 reportó "Capa 3 real con peer-to-peer mailbox".

## Realidad verificada (2026-04-27)

| Componente | Estado |
|---|---|
| Hook `TaskCreated` | NO registrado en settings.json |
| Hook `TeammateIdle` | Registrado pero llama `agent-routing-hook.sh` (no es comunicación peer-to-peer) |
| Hook `TaskCompleted` | Registrado pero llama `self-check.sh` (cierre de sesión, no mailbox) |
| Directorio `~/.claude/teammates/` | NO existe |
| Directorio `~/.claude/mailbox/` | NO existe |
| Helpers de read/write mailbox | No existen |
| Invocaciones de swarm (Capa 2) últimos 30d | 0 |
| Invocaciones de team (Capa 3) últimos 30d | 0 |

## Conclusión

**Capa 3 NO está implementada.** La promesa del CLAUDE.md era falsa. Helix funcionalmente opera en Capa 0 (Ollama), Capa 1 (Agent tool) y nada más.

## Por qué no se notó antes

- No hubo necesidad real de peer-to-peer en proyectos pasados
- Yo (Claude) nunca intenté invocar Capa 3 — la lógica de routing del CLAUDE.md me lleva a Capa 1 por defecto
- El staleness check verifica memoria vs git, no infraestructura vs documentación

## Implementación mínima (futuro)

Si en algún momento se necesita Capa 3 real:

1. **Crear infraestructura física**:
   ```
   ~/.claude/mailbox/<agent>/inbox.jsonl
   ~/.claude/teammates/<agent>/state.json
   ```

2. **Hooks faltantes en settings.json**:
   - `TaskCreated`: helper que escribe en mailbox del agente destino
   - `TeammateIdle`: ya existe pero debería leer mailbox y procesar mensajes pendientes

3. **Helpers**:
   - `~/.claude/helpers/teammate-mailbox.sh send|recv|peek <agent>`
   - `~/.claude/helpers/teammate-state.sh get|set <agent> <key> <value>`

4. **Tests E2E**: validar mensaje de A → B en proyecto real

## Mientras tanto

Para tareas que requerirían peer-to-peer:
- Usar Capa 2 (swarm claude-flow) si los agentes pueden coordinarse vía lead
- Usar Capa 1 secuencial si la dependencia es simple (output de A → input de B)
- HELIX-LANG comprime los hand-offs entre agentes secuenciales

## Compromiso de honestidad

CLAUDE.md ahora refleja el estado real. Si en el futuro se implementa Capa 3, ESTE archivo es la prueba de verificación: cada componente listado debe existir y testearse.
