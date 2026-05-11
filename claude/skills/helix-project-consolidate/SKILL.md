---
name: helix-project-consolidate
description: Detectar y unificar drift de nombres en Helix (helpers, skills, agents, topics). Encuentra pares de archivos/dirs con nombres similares (ratio ≥0.75 default), muestra diff lado a lado, y aplica unify SOLO con confirmación explícita del creator. Reversible via git restore en repos. Invocar cuando el creator pida "review drift", "consolidate names", o periódicamente como housekeeping del entorno Helix. NUNCA unifica sin OK.
version: 1.0
status: production
---

# Helix Project Consolidate — M3 drift de nombres

Detector + unificador de drift de nombres. Resuelve el problema de archivos huérfanos / variantes (ej: `script.sh` vs `script.cjs.bak`, `agent-foo.md` vs `foo-agent.md`) que se acumulan en `~/.claude/`.

## Contrato (de tranch2-acceptance-criteria.md §M3)

| Criterio | Cumplimiento |
|---|---|
| Detección de drift real ≥80% | Validación creator manual via `scan` |
| Interactive prompt obligatorio (NUNCA unifica sin OK) | Hard rule en `cmd_unify` — confirmación `[y/N]` |
| Reversibilidad | git rm si target en repo, backup→rm si no |
| Fuzzy threshold ajustable | `HELIX_M3_FUZZY_THRESHOLD` (default 0.75) |

**Bloqueo:** unificación silenciosa permitida → rechazado. **NO permitida.**

## Cuándo invocar

- Creator pide "consolidar nombres", "review drift", "limpiar duplicados"
- Housekeeping mensual de `~/.claude/`
- Tras refactor grande donde se renombraron muchos archivos

## Cuándo NO invocar

- En medio de tarea activa (interrumpe flujo)
- Sobre directorios de proyectos del usuario sin pedir explícitamente
- Cuando el creator no está disponible para revisar (la skill REQUIERE input interactivo o `--keep N --yes` explícitos)

## Flujo

### 1. Scan

```bash
python3 ~/.claude/helpers/helix-project-consolidate.py scan
# o con targets custom:
python3 ~/.claude/helpers/helix-project-consolidate.py scan --target ~/myproject/lib --target ~/myproject/utils
```

Default targets: `~/.claude/helpers`, `~/.claude/memory/agents`, `~/.claude/memory/topics`, `~/.claude/skills` (subdir nombres).

Output: lista priorizada por ratio descendente. State persistido en `~/.claude/memory/.m3-last-scan.json`.

### 2. Report (opcional, formato markdown)

```bash
python3 ~/.claude/helpers/helix-project-consolidate.py report > drift-report.md
```

### 3. List (releer última scan sin re-escanear)

```bash
python3 ~/.claude/helpers/helix-project-consolidate.py list
```

### 4. Unify (interactive, REQUIERE OK)

```bash
python3 ~/.claude/helpers/helix-project-consolidate.py unify <pair_id>
```

Pasos del unify:
1. Imprime A, B, ratio
2. Imprime diff unified (primeras 200 líneas)
3. Pide decisión: `1`=keep A drop B, `2`=keep B drop A, `s`=skip, `q`=quit
4. Imprime "Planned actions" con paths exactos y método (`git rm` o `backup→rm`)
5. **Pide confirmación final: `APPLY? [y/N]`**
6. Aplica solo si y

Modo no-interactivo (para tests / scripts):
```bash
python3 ~/.claude/helpers/helix-project-consolidate.py unify <pair_id> --keep 1 --yes
```

## Strip rules (normalización de nombres antes del ratio)

El detector normaliza nombres antes de calcular similarity:

- Drop prefix: `helix-`, `helix_`, `claude-`
- Drop suffix: `-hook`, `_hook`, `-helper`
- Lowercase

Esto agrupa `helix-foo.sh` y `foo-hook.sh` y `claude-foo.py` como variantes del mismo concepto.

**Limitación conocida:** strip rules conservadores. Wrappers `.sh` que llaman a `.py` (ej: `passive-capture-hook.sh` → `passive-capture-hook.py`) aparecen como falsos positivos. Decisión humana (`s` skip) es la respuesta correcta.

## Reversibilidad

Si el archivo a remover está dentro de un repo git:
- Usa `git rm` → revierte con `git restore --staged --worktree <path>` o `git revert`

Si no está en git:
- Backup automático en `~/.claude/backups/m3/<timestamp>/<rel-path>` antes del rm
- Restaurar manualmente: `cp ~/.claude/backups/m3/<ts>/<path> <orig-path>`

## Anti-patterns

- Bajar el threshold por debajo de 0.5 (genera demasiado ruido — el catálogo se vuelve ininspeccionable)
- Aplicar `unify` sin leer el diff (el diff existe por algo)
- Unificar sin que el creator esté revisando (rompe contrato hard rule)
- Olvidar que skills son directorios — unify sobre dirs hace `shutil.rmtree`, asegurar que el backup se generó

## Tuning

```bash
# Más estricto (menos falsos positivos):
HELIX_M3_FUZZY_THRESHOLD=0.85 python3 ~/.claude/helpers/helix-project-consolidate.py scan

# Más laxo (más candidatos, más ruido):
HELIX_M3_FUZZY_THRESHOLD=0.65 python3 ~/.claude/helpers/helix-project-consolidate.py scan
```

Si la precision (drift real / total candidatos) cae <80%, subir threshold o agregar strip rules en `_name_key()` del .py.
