# /helix-analiza — Análisis Inicial del Proyecto

Ejecuta un diagnóstico completo del proyecto actual y guarda los resultados como memoria permanente.
Esto evita que Helix tenga que releer el proyecto desde cero en cada sesión.

---

## Protocolo de ejecución (seguir en orden)

### Paso 1 — Detección del stack
Leer en paralelo los archivos que existan:
- `package.json` → frameworks y dependencias JS/TS
- `requirements.txt` / `pyproject.toml` → dependencias Python
- `compose.yml` / `docker-compose.yml` → servicios y arquitectura Docker
- `CLAUDE.md` del proyecto → contexto ya registrado por el usuario
- Estructura de carpetas raíz → arquitectura general del proyecto

### Paso 2 — Identificar agentes necesarios
Basado en el stack, mapear qué agentes de Helix aplican a este proyecto.
Indicar cuáles ya están activos y cuáles habría que traer o configurar.

### Paso 3 — Identificar skills aplicables
Comparar las skills disponibles en `~/.claude/skills/` y `.claude/skills/` del proyecto
contra las necesidades detectadas. Indicar si falta alguna skill crítica.

### Paso 4 — Pre-mapear zonas de riesgo
Identificar archivos/funciones que típicamente son frágiles en este tipo de stack.
Si el proyecto ya tiene un mapa de riesgo en CLAUDE.md, enriquecerlo.

### Paso 5 — Generar helix-analysis.md
Escribir el diagnóstico completo en `.claude/memory/helix-analysis.md`
usando la estructura del template (ver abajo). Crear directorio si no existe.

### Paso 6 — Inicializar helix-bitacora.md
Crear `.claude/memory/helix-bitacora.md` con estructura vacía lista para usar.
Si ya existe, NO sobreescribir — solo informar que existe.

### Paso 7 — Reportar al usuario
Mostrar resumen del diagnóstico: stack detectado, agentes recomendados (lista),
skills faltantes (si hay), zonas de riesgo iniciales.
Confirmar qué archivos se guardaron y que no volverá a preguntar.

---

## Template: helix-analysis.md

```markdown
# Helix Analysis — {nombre del proyecto}
> Generado: {fecha} | Versión: 1.0
> Este archivo es memoria persistente. Helix lo carga al inicio de cada sesión.

## Stack detectado
- **Backend:** {framework, lenguaje, versión}
- **Frontend:** {framework, lenguaje, bundler}
- **Base de datos:** {motor, ORM}
- **Infraestructura:** {Docker, Nginx, servicios externos}
- **Auth:** {método de autenticación}

## Agentes recomendados para este proyecto
| Agente | Cuándo usarlo en este proyecto |
|--------|-------------------------------|
| {agente} | {contexto específico} |

## Skills aplicables
| Skill | Estado | Propósito en este proyecto |
|-------|--------|---------------------------|
| {skill} | disponible / falta | {uso concreto} |

## Zonas de riesgo pre-identificadas
| Archivo/Módulo | Nivel | Razón |
|----------------|-------|-------|
| {archivo} | 🔴/🟡/🟢 | {por qué es frágil} |

## Resumen ejecutivo (carga rápida)
> Máx. 150 palabras. Lo que Helix necesita saber para orientarse sin leer el código.
{resumen}
```

---

## Template: helix-bitacora.md

```markdown
# Helix Bitácora — {nombre del proyecto}
> Iniciada: {fecha}
> Propósito: Registro continuo para orientación rápida sin releer el proyecto.

## 📝 Cambios Realizados
| Fecha | Archivo(s) | Cambio | Sesión |
|-------|-----------|--------|--------|

## 💡 Recomendaciones
| Fecha | Recomendación | Estado |
|-------|--------------|--------|
| | | pendiente / implementada / descartada |

## 🐛 Errores Cometidos
| Fecha | Error | Solución | Aprendizaje registrado |
|-------|-------|----------|------------------------|

## 🧠 Decisiones de Diseño Validadas
| Fecha | Decisión | Por qué |
|-------|---------|---------|
```

---

## Si el usuario dice "no" al análisis inicial

1. Ejecutar: `touch {PROJECT_ROOT}/.claude/memory/.analysis-declined`
   (crear el directorio `.claude/memory/` si no existe)
2. Decirle: "Entendido. Podés pedirlo cuando quieras con `/helix-analiza`."
3. No volver a preguntar en sesiones siguientes.
