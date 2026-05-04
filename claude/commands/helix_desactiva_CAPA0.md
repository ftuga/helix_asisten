# /helix_desactiva_CAPA0 — Desactivar Capa 0 (Ollama local)

Permite al usuario desactivar manualmente la Capa 0 de Helix (modelos
Ollama corriendo en local). Útil en máquinas con poco RAM/CPU/GPU
donde mantener Ollama corriendo es contraproducente.

Capa 0 está **activada por defecto** según HW detectado (FASE 9 HW-aware).
Este comando fuerza OFF independiente del HW.

---

## Al ejecutar `/helix_desactiva_CAPA0`

### Paso 1 — Preguntar alcance al usuario

Mostrar exactamente esto y esperar respuesta:

```
¿Cómo querés desactivar Capa 0?

  1. Solo esta sesión   (se reactiva sola al cerrar Claude Code)
  2. Persistente        (queda OFF en todas las sesiones futuras hasta /helix_activa_CAPA0)

Respondé: 1 o 2
```

NO ejecutar nada hasta que el usuario responda.

### Paso 2 — Aplicar según respuesta

Si responde **1** o "sesión" o "esta":
```bash
bash ~/.claude/helpers/helix-capa0-toggle.sh off --session
```

Si responde **2** o "persistente" o "todas":
```bash
bash ~/.claude/helpers/helix-capa0-toggle.sh off --persistent
```

Si la respuesta es ambigua → repetir la pregunta una vez. Si sigue ambigua → asumir 1 (más seguro, reversible).

### Paso 3 — Mostrar estado final

```bash
bash ~/.claude/helpers/helix-capa0-toggle.sh status
```

Confirmar al usuario en una línea: "Capa 0 desactivada (modo: session|persistent). Helix usará Claude para todo lo que iría a Ollama."

---

## Comportamiento esperado

- **Modo session:** `~/.claude/capa0-disabled` se borra automáticamente al ejecutar `bash ~/.claude/session-end.sh`.
- **Modo persistent:** queda hasta que el usuario ejecute `/helix_activa_CAPA0`.
- En ambos casos `helix-capa0-policy.sh` reporta `OFF` con razón "override manual del usuario".
- `capa0.sh` retorna exit 2 → caller escala a Capa 1 (Claude) automáticamente.

---

## Default

Capa 0 **activada por defecto** post-install. Solo se desactiva por:
1. HW insuficiente (heurística automática FASE 9)
2. Este comando manual
3. Env var `HELIX_CAPA0_DISABLED=1`
