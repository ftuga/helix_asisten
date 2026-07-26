# Telemetría deprecada — 2026-07-26

## `agent-spawn.jsonl` — ELIMINADO
Huérfano: 6 entradas, última 2026-04-18, **sin ningún writer en el código**.
Registraba `injection_hits` + `secret_hits` por spawn de subagente.
Esa función se **restituyó como control activo**, no como log: `secrets-scanner-hook.sh`
ahora corre en `PreToolUse(...|Agent)` y **bloquea** (exit 2) el spawn si el prompt
trae un secreto. Bloquear > registrar. No revivir este archivo.

## `mcp-calls.jsonl` — ELIMINADO
Huérfano: 6 entradas, última 2026-04-18. El tracker real (`mcp-tracker-hook.sh`,
registrado en `PostToolUse(mcp__.*)`) escribe a `skill-usage.jsonl` con `tipo:"mcp"`.
Dos telemetrías del mismo evento es deuda, no redundancia.

Backup de ambos: scratchpad de la sesión 2026-07-26 + este commit en git.
