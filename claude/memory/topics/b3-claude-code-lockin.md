# Gate B3 — Lock-in Claude Code (trade-off declarado consciente)

> Council #1 synthesizer dissent residual #4 mitigated. Decisión explícita.

---

## El trade-off

Helix está construido SOBRE Claude Code (CLI de Anthropic). Sin Claude Code, Helix muere:
- Sin Anthropic API → sin Claude → sin Capa 1
- Sin claude-code CLI → sin hooks, sin Agent tool, sin statusLine, sin .mcp.json
- Sin formato `~/.claude/` → sin agents-index, sin skills, sin settings.json

Esto es **lock-in profundo** a un proveedor (Anthropic) y una herramienta (claude-code CLI).

---

## Decisión: aceptar como trade-off consciente

NO se invierte en abstraction layer prematuro. Razones:

1. **Claude Code es la mejor herramienta hoy** para el caso de uso de Helix (agente CLI con hooks, slash commands, statusLine, MCP).
2. **Construir abstraction layer = ~6 meses de trabajo** sin valor inmediato.
3. **N=1 audiencia (creator)** — el costo de migrar Helix a otro runtime es del creator solo, no de clientes.
4. **El valor diferencial de Helix** está en la lógica del harness (council, evolutions, HSL, Canon), NO en el runtime.

Innovador R2 propuso (P3 abstraction layer) — fue **descartado** explícitamente. Si Anthropic introduce breaking changes o sube precios > umbral, se reevalúa.

---

## Exit path mínimo (declarado)

Si en algún momento futuro se necesita migrar fuera de Claude Code, estos son los activos portables:

| Activo Helix | Portabilidad | Conversión necesaria |
|---|---|---|
| `~/.claude/CLAUDE.md` (reglas) | Alta — texto markdown | Cambiar referencias a hooks/tools específicos |
| `~/.claude/memory/` (estado) | Alta — markdown/yaml/json | Ninguna |
| `~/.claude/skills/` | Media — markdown con frontmatter | Adaptador de invocación según runtime nuevo |
| `~/.claude/agents/` | Media — system prompts en md | Adaptador igual que skills |
| `~/.claude/snapshots/` | Alta — yaml | Ninguna |
| `~/.claude/council/` | Alta — bash + yaml + md | Cambiar Agent tool calls por equivalente del nuevo runtime |
| `~/.claude/helpers/*.sh` | Alta — bash puro mayormente | Mínima — algunos asumen jerarquía `~/.claude/` |
| Hooks en settings.json | Baja — formato Anthropic-específico | Reescribir según runtime nuevo |
| `.mcp.json` | Media — formato MCP estándar | Probable compatibilidad si nuevo runtime soporta MCP |

**Tiempo estimado de migración** a un runtime hipotético equivalente (asumiendo que existe): 2-4 semanas con scripts de portabilidad.

**Realidad operativa hoy:** ningún runtime equivalente existe. Helix se mantiene en Claude Code hasta que sea irracional.

---

## Triggers de reevaluación

Reabrir esta decisión si:
1. **Anthropic deprecia Claude Code** (improbable corto plazo, monitorear changelog).
2. **Costo Anthropic API >$X/mes** sostenido por Helix solo (umbral a definir si llegamos).
3. **Aparece runtime equivalente** con paridad de features (hooks, statusLine, MCP, agentes) y mejor disponibilidad/precio.
4. **Helix gana usuarios significativos (>10)** y la decisión cambia de N=1 a N=multi.

Hasta entonces: lock-in aceptado, no mitigado.

---

## Lo que NO se hace (anti-paternalismo)

- ❌ NO se construye abstraction layer especulativo.
- ❌ NO se evita usar features útiles de Claude Code "por si acaso".
- ❌ NO se reescribe en Go/Rust por miedo a Anthropic.
- ❌ NO se evalúan alternatives sin trigger de reevaluación.

Helix abraza Claude Code y lo explota al máximo. La portabilidad es teórica, documentada por completitud, no priorizada.
