# /helix-analiza — Análisis Inicial del Proyecto

Diagnóstico completo del proyecto. Guarda memoria persistente para no repetir el trabajo.
Arquitectura híbrida: resumen en archivo (carga siempre), detalles en vector memory si está disponible.

---

## Paso 0 — Auto-detectar capacidades disponibles

Antes de empezar, evaluar:

```
¿Está disponible mcp__claude-flow__memory_store?
  → Sí: modo VECTOR (detalles en vector, solo resumen en archivo)
  → No: modo FILE   (todo en helix-analysis-full.md + resumen en helix-analysis.md)
```

Para detectarlo: intentar `mcp__claude-flow__memory_store` con un valor de prueba mínimo.
Si falla o no existe → usar modo FILE. No preguntar al usuario cuál usar.

---

## Paso 1 — Detección de stack (bash — determinista)

```bash
bash ~/.claude/helpers/helix-detect-stack.sh {PROJECT_ROOT}
```

Esto devuelve JSON con: backend, frontend, database, auth, infra, servicios Docker, conteos de archivos.
Leer el JSON. Si el script falla → detectar manualmente leyendo los archivos clave en paralelo.

---

## Paso 2 — Leer contexto ya conocido

Si existe `{PROJECT_ROOT}/CLAUDE.md` → leer las secciones:
- MAPA DE ZONAS DE RIESGO
- DECISIONES DE DISEÑO
- ARQUITECTURA
No releer si ya están en contexto.

---

## Paso 3 — Mapear agentes necesarios

Basado en el stack detectado, mapear qué agentes de `~/.claude/memory/agents-index.md` aplican.
Indicar: cuáles están activos, cuáles habría que habilitar.

---

## Paso 4 — Mapear skills aplicables

Listar skills en `~/.claude/skills/` y `{PROJECT_ROOT}/.claude/skills/` que aplican al stack.
Indicar si falta alguna skill crítica para este tipo de proyecto.

---

## Paso 5 — Pre-identificar zonas de riesgo

Basado en el stack y los patrones conocidos, identificar archivos/módulos que típicamente
son frágiles. Si CLAUDE.md ya tiene un mapa de riesgo, enriquecerlo.

---

## Paso 6 — Guardar resultados

### Siempre (ambos modos):

Escribir `{PROJECT_ROOT}/.claude/memory/helix-analysis.md` con SOLO el resumen ejecutivo:

```markdown
# Helix Analysis — {nombre}
> Generado: {fecha} | Modo: vector|file | Actualizar con: /helix-actualiza
> ⚠️ Si este archivo tiene >30 días, ejecutar /helix-actualiza

## Resumen ejecutivo
{≤150 palabras: stack, agentes clave, skills críticas, riesgos principales}

## Stack (resumen)
Backend: {x} | Frontend: {x} | DB: {x} | Auth: {x} | Infra: {x}

## Agentes prioritarios para este proyecto
{lista corta: agente → cuándo usarlo aquí}

## Skills críticas
{lista: skill → disponible/falta}

## Zonas de riesgo iniciales
{lista: archivo → nivel → razón}
```

### Modo VECTOR (si MCP disponible):

Almacenar en vector memory con namespace `helix/{project_name}/`:
- `helix/{name}/stack` → JSON completo del stack detectado
- `helix/{name}/agents` → mapeo detallado de agentes
- `helix/{name}/skills` → skills completas con razones
- `helix/{name}/risks` → zonas de riesgo con contexto

### Modo FILE (fallback):

Escribir `{PROJECT_ROOT}/.claude/memory/helix-analysis-full.md` con todos los detalles.

---

## Paso 7 — Inicializar bitácora

Si `helix-bitacora.md` NO existe → crearlo:

```markdown
# Helix Bitácora — {nombre del proyecto}
> Iniciada: {fecha}
> Propósito: Registro continuo. Helix actualiza automáticamente vía hook PostToolUse.

## 📝 Cambios Realizados
| Fecha | Archivo(s) | Cambio | Sesión |
|-------|-----------|--------|--------|

## 💡 Recomendaciones
| Fecha | Recomendación | Estado |
|-------|--------------|--------|

## 🐛 Errores Cometidos
| Fecha | Error | Solución | Aprendizaje |
|-------|-------|----------|-------------|

## 🧠 Decisiones de Diseño Validadas
| Fecha | Decisión | Por qué |
|-------|---------|---------|
```

Si ya existe → NO sobreescribir. Informar que existe.

---

## Paso 8 — Reportar al usuario

Mostrar resumen breve:
- Stack detectado (1 línea)
- Agentes recomendados (lista)
- Skills faltantes (si hay)
- Zonas de riesgo iniciales
- Modo usado (vector/file) y qué se guardó
- Confirmar que no volverá a preguntar automáticamente

---

## Si el usuario dijo "no" al análisis automático

```bash
mkdir -p {PROJECT_ROOT}/.claude/memory
touch {PROJECT_ROOT}/.claude/memory/.analysis-declined
```

Decir: "Entendido. Cuando quieras: `/helix-analiza`. No vuelvo a preguntar."
