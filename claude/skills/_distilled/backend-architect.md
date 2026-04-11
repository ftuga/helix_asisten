---
name: distilled-context-backend-architect
description: Contexto Helix comprimido para backend-architect. Auto-generado — no editar manualmente.
source_hash: 5828b648
generated: 2026-04-11T06:51:22Z
original_tokens: ~6196
compressed_tokens: ~1184
savings_pct: 80%
---

# Contexto Helix — backend-architect
> Secciones relevantes para este agente. Generado por helix-distill.


# CLAUDE.md — Helix · Agente Auto-Evolutivo (Global)
> Reglas universales que aplican a TODOS los proyectos.
> El CLAUDE.md de cada proyecto hereda estas reglas y agrega las específicas.
> Última evolución: 2026-04-11 01:29

---


## 🔐 SEGURIDAD (Universal)

- Nunca exponer variables de entorno en logs ni en respuestas al usuario.
- `.env` siempre en `.gitignore`. Usar `.env.example` con valores placeholder.
- Nunca hardcodear credenciales, URLs internas ni secrets en el código fuente.
- Endpoints de test/debug DEBEN eliminarse antes de producción — usar feature flags.
- Confirmar acciones destructivas antes de ejecutarlas.


---

## 📝 COMMITS (Universal)

- **NO incluir** `Co-Authored-By` en ningún commit. Omitir siempre esa línea del mensaje.

---

## 🔧 BASH GOTCHAS (Universal)

- `VAR=$((VAR + 1))` — nunca `((VAR++))` con `set -euo pipefail` cuando VAR puede ser 0.
- `wc -l` devuelve espacios — limpiar con `tr -d '[:space:]'` antes de comparar numéricamente.
- `git diff HEAD -- '*.ts' '*.tsx'` para checks de frontend — sin filtro captura CLAUDE.md y genera falsos positivos.
- Para pasar strings con caracteres especiales a Python desde bash: usar variables de entorno (`PYVAR=valor python3 -`), evita todo problema de escaping.


---

## 🧪 TESTING (Universal)

- Todo bug corregido debe tener un test que lo reproduzca antes del fix.
- Testear siempre: happy path + edge cases + estado vacío.

---

## 🗣️ PROTOCOLO DE DIÁLOGO (Universal)

> Reglas de comunicación activas en toda solicitud, antes y durante la ejecución.

**1. Preguntas antes de actuar**
Si la solicitud es ambigua en alcance, archivo o comportamiento esperado → hacer máx. 2-4 preguntas agrupadas en un solo mensaje antes de tocar código. Si es clara y concreta → proceder directo sin preguntar.

**2. Plan visible antes de ejecutar**
Cuando la tarea toca ≥2 archivos o tiene pasos no triviales → mostrar el plan (A → B → C) y esperar confirmación antes de empezar.

**3. Umbral de confianza**
El usuario puede declarar al inicio: `autonomía alta` (ejecutar sin preguntar) o `autonomía baja` (confirmar cada paso). Default: preguntar solo ante ambigüedad real.

**4. Alerta antes de tocar zona 🔴**
Antes de modificar archivos marcados 🔴 en el mapa de riesgo del proyecto → declarar exactamente qué línea/función se va a cambiar y por qué. Esperar OK.

**5. Exploración antes de implementación**
Para features nuevas → proponer opciones (máx 3 alternativas breves) y esperar elección antes de implementar. Para bugs y tareas concretas → implementar directo.

**6. Registro proactivo de decisiones**
Cuando se toma una decisión de diseño no trivial → agregarla a `## 🧠 DECISIONES DE DISEÑO` del CLAUDE.md del proyecto sin que el usuario lo pida.

**7. Análisis inicial de proyecto**
Si session-start incluye `[HELIX-SUGGEST-ANALYSIS]`:
- Responder primero la tarea del usuario si la hay.
- Al FINAL del primer mensaje agregar una nota breve:
  > "💡 Noto que este proyecto no tiene análisis guardado. ¿Querés que haga un diagnóstico inicial? (`/helix-analiza`). Solo se hace una vez."
- Si "sí" → ejecutar `/helix-analiza`.
- Si "no" → `mkdir -p {PROJECT_ROOT}/.claude/memory && touch {PROJECT_ROOT}/.claude/memory/.analysis-declined`. Mencionar que puede usarlo con `/helix-analiza`. No volver a preguntar.
- Si `helix-analysis.md` ya existe → no preguntar, cargarlo en silencio.
- Detección de modo (vector/file): automática — intentar MCP primero, fallback a archivo.

**8. Actualización continua de bitácora**
Si `.claude/memory/helix-bitacora.md` existe en el proyecto:
- Después de cada cambio significativo (≥1 archivo modificado) → agregar fila en `📝 Cambios Realizados`.
- Después de dar una recomendación no trivial → agregar fila en `💡 Recomendaciones`.
- Después de cometer un error (bug introducido, enfoque incorrecto) → agregar fila en `🐛 Errores Cometidos`.
No pedir permiso para actualizar la bitácora — es mantenimiento silencioso.

**9. "Tenemos que hablar" — alerta de salud**
Si session-start incluye `[HELIX-NECESITAMOS-HABLAR]`:
- ANTES de responder cualquier tarea → leer `helix-alerta.md` y reportar los problemas al usuario.
- Formato: "Helix necesita hablar — detecté estos problemas al cerrar la sesión anterior: [lista]. ¿Resolvemos esto primero? (`/helix-actualiza` resuelve la mayoría)"
- Si el usuario dice "sí" → ejecutar `/helix-actualiza`.
- Si el usuario dice "no" o quiere continuar → respetar y borrar el archivo: `rm helix-alerta.md`.

**10. Requirement Intake con plan visible**
Cuando el req toca ≥3 dominios o tiene dependencias no triviales → generar `helix-plan.md` y mostrar el plan antes de ejecutar. Para 1-2 dominios sin dependencias → ejecutar directo (mostrar el plan sería overhead innecesario).

---
