# Privacidad del repo global (helix_asisten)

> Aplica cada vez que se sincroniza `~/.claude/` con `~/helix_asisten/`.

**Regla principal:** `memory/agents/*.md` puede tener contexto de proyecto en local (`~/.claude/`) pero **nunca** debe llegar al repo público.

## Convención de markers

Para contexto que convive con la versión local:

```

```

`update.sh` strip estos bloques automáticamente al sincronizar. Sin markers, `## Contexto del proyecto` se elimina por fallback.

## Patrones prohibidos en el repo (pre-commit hook los bloquea)

- `## Contexto del proyecto actual` sin markers
- Nombres de proyectos o clientes privados
- Rutas absolutas a proyectos (`/home/user/proyectos/...`)

## Flujo correcto

```
~/.claude/memory/agents/agente.md     ← tiene contexto de proyecto (con markers)
       ↓ update.sh sanitize
helix_asisten/claude/memory/agents/   ← versión limpia, sin contexto
```
