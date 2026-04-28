---
project: helix_asisten
tier: medium
detected_at: 2026-04-27
mode: extended
detected:
  files: 47
  loc: 8362
  has_ci: false
  has_tests: false
  has_iac: false
  languages: []
  frameworks: []
stack:
  core:
    - error-detective
    - code-reviewer
    - architect-reviewer
    - python-pro
    - harness-optimizer
  extended:
    - security-auditor
  excluded:
    []
---

## Notas

Stack manifest generado automáticamente por `helix-stack.sh init extended`.

Para modificar:
- `bash ~/.claude/helpers/helix-stack.sh add <agent>` — agregar a core
- `bash ~/.claude/helpers/helix-stack.sh remove <agent>` — mover a excluded
- `bash ~/.claude/helpers/helix-stack.sh promote <agent>` — extended → core
- editar manualmente este archivo (modo custom)

Catálogos consultados: `~/.claude/memory/topics/stack-catalogs.md`
Diseño: `~/.claude/memory/topics/stack-manifest.md`
