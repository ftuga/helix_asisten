# /helix_activa_CAPA0 — Reactivar Capa 0 (Ollama local)

Reactiva Capa 0 después de un `/helix_desactiva_CAPA0`. Borra el override
manual y devuelve la decisión a la heurística HW (FASE 9 HW-aware).

---

## Al ejecutar `/helix_activa_CAPA0`

### Paso 1 — Borrar override

```bash
bash ~/.claude/helpers/helix-capa0-toggle.sh on
```

### Paso 2 — Mostrar estado resultante

```bash
bash ~/.claude/helpers/helix-capa0-toggle.sh status
```

### Paso 3 — Confirmar al usuario

Una línea según la policy efectiva resultante:

- Si policy = **ON** → "Capa 0 reactivada. Tu HW soporta modelos completos."
- Si policy = **OPT_IN** → "Capa 0 reactivada en modo OPT_IN — solo modelos pequeños según HW."
- Si policy = **OFF** → "Capa 0 sigue OFF: tu HW no la soporta (RAM/GPU insuficiente). Razón: <reason>." y sugerir mantener desactivada o revisar `bash ~/.claude/helpers/helix-hwprobe.sh`.

---

## Casos especiales

- Si no había override activo → el helper imprime "Capa 0 ya estaba activada (sin override manual)". Mostrar al usuario tal cual y reportar la policy efectiva igual.
- Si está activa la env var `HELIX_CAPA0_DISABLED=1` → advertir al usuario: "Tenés `HELIX_CAPA0_DISABLED=1` exportado en el shell. Mientras esa variable exista, Capa 0 sigue OFF. `unset HELIX_CAPA0_DISABLED` o reiniciá la terminal."
