---
name: helix_control_total
description: Activa el modo helix_control_total — 4 capas de orquestación (Ollama + Subagents + Swarm + Agent Teams) con auto-evolución. Ejecutar al inicio de sesiones de trabajo.
---

# HELIX — Modo Control Total

Activando todas las capas de orquestación.

## Estado de activación

```
Capa 0 — Ollama        → logs, texto largo, salida Docker
Capa 1 — Subagents     → artefacto concreto (endpoint, componente, query)
Capa 2 — Swarm         → feature ≥2 dominios en paralelo
Capa 3 — Agent Teams   → colaboración peer-to-peer (NO IMPLEMENTADO, ver topics/agent-teams-status.md)
```

## Capacidades activas

| Sistema | Estado |
|---------|--------|
| Hooks PreToolUse / PostToolUse / UserPromptSubmit / SessionStart/End | activos |
| Cost tracker (R2) | $/sesión real desde transcripts JSONL |
| Routing advisor (R1) | recomendación de modelo por dominio (read-only) |
| Multi-domain trigger (D1') | detecta 2+ dominios en prompts a `Agent` |
| Council v1.0 | 7 roles disponibles para deliberaciones críticas |
| HSL v1 | 6 capas de seguridad (injection, egress, secrets, integrity, evolve-guard, reflexion-quarantine) |
| Capa 0 HW-aware | ON / OPT_IN / OFF según hw-profile.json |

## Regla de routing (automático — no preguntar al usuario)

| Señal | Capa |
|-------|------|
| Log / texto largo / Docker output | 0 (Ollama) |
| Un artefacto concreto | 1 (Agent tool con agente del catálogo) |
| Feature que toca ≥2 dominios | 2 (swarm_init + agent_spawn) |
| Diálogo peer-to-peer entre agentes | 3 (Agent Teams — pendiente) |

## Catálogo de agentes

- Globales: `~/.claude/agents/` + índice en `~/.claude/memory/agents-index.md`
- Council: 7 agentes `council-*` para deliberaciones de alto impacto
- Para buscar/instalar agentes faltantes: skill `helix-agent-manager`

## Protocolo anti-drift

Tareas complejas (≥3 archivos): preferir swarm Capa 2 sobre múltiples Agent en paralelo (antipattern evolution #58 — invisible en swarm panel).

---

**Helix está activo. El usuario solo ve resultados.** Si un agente falla → registrar en evolution-log y corregir.
