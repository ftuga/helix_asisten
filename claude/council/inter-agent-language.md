# Helix Council — Inter-Agent Language Protocol

> Establecido sesión #19 2026-05-04 a partir de observación del usuario creator: HELIX-LANG escapó accidentalmente a respuesta user-facing. Formalizamos la regla.

## Regla universal

**Capa interna del council** (entre roles, en YAML outputs, en context_pack): comprimida (HELIX-LANG ASCII, idioma-neutral).
**Capa externa del council** (al user creator): **idioma del usuario** (mirror del último turno), prosa legible. Fallback español neutro colombiano si el idioma es ambiguo. Override en `~/.claude/memory/user-profile.md` prevalece.

La traducción pasa **solo en el report final** (finalize step + chat back to user). Nunca antes.

## Qué SÍ va en compresión interna

- Outputs YAML de cada rol (ya estructurados — mantener YAML, no expandir a prosa).
- Context pack (yaml/keywords/short refs).
- Cross-references entre rondas (`see round_1_skeptic.challenges[3]` en lugar de citar texto completo).
- Estados de agentes en `helix-lang` (skill `~/.claude/skills/helix-lang/SKILL.md`) cuando coordinen ≥2 roles.
- Audit log entries (yaml estructurado, no prosa).

## Qué NUNCA va en compresión

- Mensajes del council al user creator (resumen post-finalize, escalation summary R7).
- Contenido de archivos `.md` que el creator lee.
- Comentarios en código fuente.
- Mensajes de commits.
- Texto en chat principal (Claude → creator).

## Por qué importa

1. **Costo:** outputs de LLM no se cachean. ~60% compresión en outputs internos = ahorro real en API tokens.
2. **Contexto:** mantener YAML estructurado entre rondas evita re-explicar y libera tokens del context window.
3. **Legibilidad humana:** el creator lee español. Forzarle a parsear `FROM->TO verb:object.domain` en una respuesta = mala UX.
4. **Auditabilidad:** YAML inmutable es más fácil de auditar que prosa.

## Implementación (hard rules en prompts del council)

Cada `prompts/<role>.md` generado por `helix-council.sh prepare` incluye:

```
LANGUAGE PROTOCOL:
- INTERNAL (your YAML output): structured, compressed, terse.
  Reference other rounds with paths like `round_1_<role>.<field>`, not full quotes.
  Use HELIX-LANG codes if coordinating with other roles (skill: ~/.claude/skills/helix-lang/SKILL.md).
- USER-FACING: never. The synthesizer/arbiter at finalize step translates to the user's language (mirror of the last user turn). Fallback Spanish only if user language is ambiguous.
- If you're tempted to write prose for the user, STOP — emit YAML facts, the report layer translates.
```

Y `helix-council.sh finalize` agrega un campo `user_facing_summary` redactado por el synthesizer:

```yaml
audit_log:
  ...
  user_facing_summary: |
    Resumen en el idioma del usuario (mirror del último turno; fallback español neutro
    colombiano si el idioma es ambiguo). Sin jerga inter-agente.
    Decisión + razón + riesgos + acción recomendada.
```

## Excepción declarada

Si el creator pide explícitamente "muéstrame el output crudo del agente X" → entonces SÍ se le muestra YAML/HELIX-LANG sin traducción. Esto es debug mode opt-in, no default.
