---
name: helix-snapshot
description: Persistencia conversacional cross-session. Captura snapshot YAML del estado actual al cierre, ofrece resume opt-in al inicio. 100% local (sin egress, sin paid). Invocar antes de cerrar sesión larga, al pedir continuar trabajo previo, o si el usuario reporta crash y quiere recuperar contexto.
version: 0.1
status: piloto
---

# Helix Snapshot — Persistencia conversacional

Sistema de captura/recuperación de estado conversacional entre sesiones. Resuelve dos problemas:

1. **Crash recovery**: si la terminal/WSL muere, retomar donde se dejó.
2. **Resume controlado**: empezar nueva sesión con la opción de cargar contexto previo (opt-in) o chat limpio.

Diseño completo: `~/.claude/memory/topics/conversation-context-research.md`

## Cuándo invocar

- Antes de cerrar sesión larga con decisiones importantes (Helix lo hace en `session-end.sh` automáticamente)
- Al inicio si `[HELIX-SUGGEST-RESUME]` aparece en session-start
- El usuario pide explícitamente "guardar contexto" o "retomar de la última vez"
- Tras crash detectado (file `.claude/SESSION_CRASHED` presente)

## Cuándo NO invocar

- Sesión corta de <10 tool calls (no aporta valor)
- Conversación puramente social / informativa
- Usuario inició sesión limpia explícitamente

## Flujo

### 1. Capture (al cierre o cada N tool calls)

Helix construye un YAML con el estado y lo pipea al helper:

```bash
cat <<YAML | bash ~/.claude/helpers/helix-snapshot.sh capture
summary: "≤200 chars: qué se hizo en esta sesión"
status: in_progress | completed | crashed
current_task: "lo que está abierto en este momento"
completed_today:
  - "hito 1"
  - "hito 2"
pending:
  - "qué queda"
critical_decisions:
  - "acuerdos con el usuario que no se deben perder"
open_questions:
  - "preguntas que quedaron sin responder"
files_modified:
  count: 18
  list:
    - "~/.claude/CLAUDE.md"
    - "~/.claude/helpers/helix-route.sh"
evolutions_registered:
  count: 19
  ids: ["routing-fase2-complete", "..."]
tool_calls: 247
estimated_tokens_used: 180000
YAML
```

Persiste en `~/.claude/snapshots/<project>/<ts>.yaml` con permisos 600.

### 2. Resume (opt-in al inicio)

`session-start.sh` detecta snapshot reciente del proyecto y emite:

```
[HELIX-SUGGEST-RESUME] última sesión hace 4h: "Refactor routing + stack manifest"
Para retomar: helix-snapshot resume helix_asisten
```

Helix al final del primer mensaje pregunta:
```
Detecté snapshot de hace 4h: "Refactor routing + stack manifest"
(1) Retomar contexto y continuar
(2) Nuevo chat (snapshot queda guardado)
(3) Ver detalle del snapshot antes de decidir
```

Solo si el usuario elige **(1)**, Helix carga el snapshot al contexto vía `helix-snapshot show`.

### 3. Staleness automático

Antes de afirmar info del snapshot:
```bash
bash ~/.claude/helpers/helix-snapshot.sh stale-check <file>
```

Retorna `STALE: <razones>` o `FRESH`. Si stale, Helix advierte al usuario antes de usar la info.

Razones posibles de stale:
- Edad >24h
- Commits posteriores al snapshot en el repo del proyecto

### 4. Lifecycle

- **Snapshots activos**: `~/.claude/snapshots/<project>/*.yaml` (≤7 días)
- **Archive**: `~/.claude/snapshots/<project>/archive/*.yaml` (7-30 días, accesible pero no por defecto)
- **Prune**: >30 días → eliminado automáticamente

Comandos: `archive` y `prune` son idempotentes, se pueden correr en cron.

## Comandos

| Comando | Propósito |
|---|---|
| `capture` | Persiste snapshot (lee YAML por stdin) |
| `resume [project]` | Resumen ejecutivo del último snapshot |
| `list [project]` | Lista snapshots con metadata |
| `show <file>` | Snapshot completo |
| `archive` | Mueve >7d a archive/ |
| `prune` | Elimina archives >30d |
| `stale-check <file>` | Valida si snapshot está fresh |

## Privacidad

- Permisos `chmod 600` en cada snapshot (solo el usuario lee)
- `~/.claude/snapshots/` está en `.gitignore` global
- Snapshots NUNCA al repo público
- Aplican reglas estándar de `topics/privacy.md` (no credentials, no IPs internas)

## Anti-patterns

| Mal uso | Por qué |
|---|---|
| Auto-cargar snapshot al inicio sin preguntar | Viola "max contexto, min costo" |
| Capturar cada tool call | Overhead innecesario, snapshots no aportan valor en alta frecuencia |
| Pasar contenido sensible al YAML (credentials, tokens) | Riesgo de leak; el L3 secrets-scanner debería bloquear |
| Confiar ciegamente en snapshot >24h | Usar siempre `stale-check` antes de afirmar |

## Estado actual (2026-04-27)

- [x] Helper `helix-snapshot.sh` con 7 subcomandos
- [x] Schema YAML estructurado (D5 del research)
- [x] Storage por proyecto + archive/prune lifecycle
- [x] Stale-check automático (edad + git)
- [x] Permisos restrictivos
- [x] .gitignore configurado
- [ ] Hook Stop para auto-capture (pendiente — requiere edit settings.json)
- [ ] Cron 30min anti-crash (pendiente — usuario debe agregar a su crontab)
- [ ] Integración con session-start (en progreso esta sesión)
- [ ] Regla #12 PROTOCOLO DE DIÁLOGO en CLAUDE.md (en progreso esta sesión)
