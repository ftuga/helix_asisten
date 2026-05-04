# helix-statusline v0.1 — Test Plan

> Plan v4 FASE 0.5 — TRANCH 1 inmediato. Implementado 2026-05-04 sesión #19.
> Mitigación conservative: testear en 3 proyectos antes de roll out.

## Implementación

| Archivo | Estado |
|---|---|
| `~/.claude/helpers/helix-statusline.sh` | NUEVO — 379 LOC bash (target era ~250, aceptable) |
| `~/.claude/helpers/statusline.cjs` | EXISTENTE — sigue activo en settings.json |
| `~/.claude/helpers/statusline.cjs.bak` | BACKUP creado 2026-05-04 |
| `~/.claude/settings.json` `.statusLine.command` | NO MODIFICADO aún (pendiente test) |

## Performance baseline (medido en helix_asisten/)

| Run | Tiempo | Notas |
|---|---|---|
| Cold (sin cache) | 100ms | Vector count = "?", background populator |
| Warm (cache vectors) | 110ms | Todos los slots con valor |
| Cold cjs original | 60ms | Referencia |

Budget: <200ms p99. Cumplido.

## Diferencias vs cjs original

- **47% menos código:** 742L → 379L
- **Sin Node deps:** runtime puro bash + python3 (solo si futuro)
- **Slots reformulados** según diseño plan v4 FASE 0.5 (Helix-centric vs RuFlo-centric)
- **Stale-while-revalidate** para vector count (cjs hacía sync → bloqueaba)

## Procedimiento de testing en 3 proyectos

Para cada proyecto candidato, ejecutar el siguiente test sin swap permanente:

```bash
# 1. Test manual con input típico de Claude Code
INPUT='{"model":{"display_name":"Opus 4.7"},"workspace":{"current_dir":"'$(pwd)'"},"context_window_used_pct":18,"cache_efficiency_pct":92}'
echo "$INPUT" | bash ~/.claude/helpers/helix-statusline.sh

# 2. Medir performance cold + warm
rm -f ~/.claude/cache/statusline-* 2>/dev/null
echo "$INPUT" | /usr/bin/time -f "%e cold" bash ~/.claude/helpers/helix-statusline.sh
sleep 2
echo "$INPUT" | /usr/bin/time -f "%e warm" bash ~/.claude/helpers/helix-statusline.sh

# 3. Test swap temporal (no modifica settings.json)
# Crear settings.local.json con override y testear in-vivo:
cat > ~/.claude/settings.local.json.test <<'EOF'
{
  "statusLine": {
    "type": "command",
    "command": "bash $HOME/.claude/helpers/helix-statusline.sh"
  }
}
EOF
# Comparar con settings.json original
```

## Checklist por proyecto

| Proyecto | Render OK | Cold <200ms | Warm <200ms | Sin errores stderr | Notas |
|---|---|---|---|---|---|
| `helix_asisten` (creator) | ☐ | ☐ | ☐ | ☐ | Tier=medium |
| Proyecto cliente típico | ☐ | ☐ | ☐ | ☐ | Verificar sin stack manifest |
| Proyecto sin .claude/ | ☐ | ☐ | ☐ | ☐ | Verificar fallbacks |

## Limitaciones conocidas v0.1

| Slot | Limitación |
|---|---|
| 💰 cost/d | Muestra contador de tool calls de la sesión (placeholder hasta FASE 3 R2) |
| ⏳ Stale | Depende de `helix-staleness.sh --count` (verificar interfaz) |
| Session # | Muestra `total_sesiones` del JSON stats, no última fila de SESIONES table |

## Pasos de roll out (cuando los 3 tests pasen)

1. Confirmar que ningún test falló
2. Editar `~/.claude/settings.json` cambiando `.statusLine.command` a `bash $HOME/.claude/helpers/helix-statusline.sh`
3. Restart Claude Code
4. Validar render in-vivo
5. Si falla, revertir a `node $HOME/.claude/helpers/statusline.cjs` (el cjs sigue intacto)

## Rollback path

- `~/.claude/helpers/statusline.cjs` no fue modificado — sigue ejecutable
- `~/.claude/helpers/statusline.cjs.bak` es copia idéntica por si alguien edita el cjs
- Revertir = cambio de 1 línea en settings.json

## Próximos pasos en sesiones futuras

- [ ] Testear en 3 proyectos reales (próxima sesión que abra esos proyectos)
- [ ] Si todos pasan: swap settings.json → v0.1 estable
- [ ] FASE 3 R2 (cost-tracker) → reemplazar `Xc` placeholder con USD/día real
- [ ] Considerar background pre-warmer del cache de vectors al SessionStart
