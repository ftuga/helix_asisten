---
name: helix_control_total
description: Activa el modo helix_control_total — 4 capas de orquestación, swarm RuFlo V3, memoria HNSW y auto-evolución. Ejecutar al inicio de cualquier sesión de trabajo.
---

# ⚡ HELIX — Modo Control Total

Activando todas las capas de orquestación de Helix.

## Estado de activación

Helix evalúa en este orden:

```
Capa 0 — Ollama        → logs, texto largo, salida Docker
Capa 1 — Subagents     → artefacto concreto (endpoint, componente, query)
Capa 2 — Swarm RuFlo   → feature ≥2 capas del stack
Capa 3 — Agent Teams   → colaboración frontend+backend+tests
```

## Verificación del motor

$CLAUDE_PROJECT_DIR/.claude/helpers/hook-handler.cjs status

## Capacidades activas

| Sistema | Estado |
|---------|--------|
| Hooks (11 tipos) | ✓ PreToolUse / PostToolUse / UserPromptSubmit / SessionStart/End / Stop / PreCompact / SubagentStart/Stop / Notification |
| Memoria HNSW | ✓ hybrid backend — `.claude-flow/data/` |
| SONA Learning | ✓ LearningBridge activo |
| Swarm | ✓ hierarchical-mesh — máx 15 agentes |
| Daemon Workers | ✓ audit(1h) / optimize(30m) / ultralearn(1h) |
| Agent Teams | ✓ CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 |
| 3-Tier Routing | ✓ WASM(<1ms) → Haiku → Sonnet/Opus |

## Catálogo de agentes disponibles

**En este proyecto (.claude/agents/):** 99 agentes RuFlo en 23 categorías
**Globales (~/.claude/agents/):** 18 activos + 17 deshabilitados

Para buscar/instalar agentes faltantes: skill `helix-agent-manager`

## Regla de routing (automático — no preguntar al usuario)

| Señal | Acción |
|-------|--------|
| Log / texto largo / Docker output | Capa 0: Ollama |
| Un artefacto concreto | Capa 1: agente especializado correcto |
| Feature que toca ≥2 capas | Capa 2: swarm_init + task_orchestrate |
| Frontend+backend+tests simultáneo | Capa 3: Agent Teams |

## Protocolo anti-drift

Para tareas complejas (≥3 archivos):
```
swarm_init(topology="hierarchical", maxAgents=8, strategy="specialized")
→ coordinator + architect + coder + tester en paralelo
```

---

**Helix está activo. El usuario solo ve resultados.**
Máximo paralelismo. Si un agente falla → Helix corrige y registra en evolution-log.
