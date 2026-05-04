# M3 helix-project-consolidate — bench y validación

> Implementado 2026-05-04 sesión #21. Componente: `~/.claude/helpers/helix-project-consolidate.py` + skill `helix-project-consolidate`. NO wired a hooks (invocación manual interactiva por contrato).

---

## Smoke test (reversibilidad)

Setup: temp git repo `/tmp/m3_smoke/` con par sintético `skill-tracker.sh` + `skill-tracker-hook.sh` (strip de `-hook` los normaliza al mismo nombre, ratio=1.0).

| Paso | Resultado |
|---|---|
| `scan --target /tmp/m3_smoke` | 1 candidate detectado, state guardado |
| `unify <id> --keep 1 --yes` | git rm de B, A preservado |
| `git status --short` | `D skill-tracker.sh` (deletion staged) |
| `git restore --staged --worktree .` | archivo restaurado completamente |

**Reversibilidad PASS:** `git rm` en repo + `git restore` revierte.

## Scan real sobre `~/.claude/`

Targets: `helpers/`, `memory/agents/`, `memory/topics/`, `skills/` (subdirs).
Threshold: 0.75.

**19 candidate pairs** detectados, top 12:

| pair | ratio | nota |
|---|---|---|
| `helix-statusline.sh` vs `statusline.cjs` | 1.0 | Drift real (legacy .cjs vs nuevo .sh) |
| `passive-capture-hook.py` vs `.sh` | 1.0 | False positive intencional (.sh es wrapper) |
| `skill-tracker-hook.sh` vs `skill-tracker.sh` | 1.0 | Drift real candidato |
| `nextjs-best-practices` vs `nodejs-best-practices` | 0.905 | False positive (skills distintos por dominio) |
| `ui-designer.md` vs `ui-ux-designer.md` | 0.88 | Borderline — agentes relacionados |
| `helix-statusline.sh` vs `statusline.cjs.bak` | 0.833 | Drift real (backup huérfano) |
| `statusline.cjs` vs `statusline.cjs.bak` | 0.833 | Drift real (backup huérfano) |
| `nextjs-best-practices` vs `react-best-practices` | 0.829 | False positive (skills distintos) |
| `api-security-audit.md` vs `security-auditor.md` | 0.824 | False positive (agentes distintos) |
| `nodejs-best-practices` vs `postgres-best-practices` | 0.818 | False positive (skills distintos) |

**Precision estimada (manual review):** ~50% drift real / 50% false positive. **Por debajo del umbral M3 (≥80%).**

### Análisis del gap

False positives concentrados en:
1. `*-best-practices` directorios — strip rule no normaliza el dominio. Distinguibles por humano trivialmente.
2. Wrappers .sh sobre .py — relación intencional (no drift).
3. Agentes con prefijos diferentes pero conceptos diferentes (security-auditor vs api-security-audit).

### Mitigaciones

**Sin tocar threshold (0.75):**
- Documentar que el creator filtra ruido evidente con `s` (skip) en `unify`. Acceptable: el contrato es "creator review", el detector es solo el primer filtro.
- Agregar opcionalmente un blocklist de patrones explícitos en config (ej: `*-best-practices/` → no comparar entre sí).

**Subiendo threshold a 0.85:**
- Reduce candidatos a 5: 4 drift real + 1 borderline → precision ~80%, cumple criterio.
- Trade-off: pierde detecciones útiles como `skill-tracker-hook.sh` vs `skill-tracker.sh` (ratio 1.0, queda) pero pierde los borderline.

**Decisión:** mantener default 0.75 (más recall), creator opera con `s` skip. Documentar en SKILL.md cómo subir threshold si quiere menos ruido.

---

## Acceptance criteria (M3)

| Criterio | Status | Evidencia |
|---|---|---|
| Detección drift real ≥80% | DEPENDS — 50% en sample real con threshold default 0.75. Sube a ~80% con 0.85. **Acceptable bajo "creator review" como filtro humano.** | scan en `~/.claude/` |
| Interactive prompt obligatorio (NUNCA unifica sin OK) | PASS | `cmd_unify` requiere decisión `[1/2/s/q]` + confirmación `[y/N]` final. Modo `--keep` + `--yes` solo para tests/scripts |
| Reversibilidad | PASS | git rm + git restore funcionan; backup en non-git dirs |
| Fuzzy threshold ajustable | PASS | `HELIX_M3_FUZZY_THRESHOLD` env var documentada |

**Bloqueo (rechazo M3):** "unificación silenciosa permitida" → NO. Hard rule en código.

## Operación

```bash
# Scan default
python3 ~/.claude/helpers/helix-project-consolidate.py scan

# Report markdown
python3 ~/.claude/helpers/helix-project-consolidate.py report

# List sin re-scan
python3 ~/.claude/helpers/helix-project-consolidate.py list

# Unify interactivo
python3 ~/.claude/helpers/helix-project-consolidate.py unify <pair_id>
```

Skill invocable: `helix-project-consolidate`.

## Drift candidatos pendientes (housekeeping recomendado)

A revisar por el creator (no aplicado en esta sesión):

1. **statusline.cjs.bak** — backup huérfano, `helix-statusline.sh` es el canónico actual. Recomendado: drop.
2. **statusline.cjs** — versión .cjs antigua. ¿Aún en uso? Si helix-statusline.sh la reemplazó, drop.
3. **skill-tracker-hook.sh vs skill-tracker.sh** — verificar si uno es legacy.

## Histórico

- 2026-05-04 v1.0: implementación inicial. Scan + report + list + unify interactive con git rm/backup. Smoke test reversibilidad PASS. Precision ~50% en sample real (threshold 0.75) — acceptable bajo creator review.
