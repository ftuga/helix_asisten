# CLAUDE.md — [NOMBRE DEL PROYECTO]
> Reglas específicas de este proyecto. Las reglas universales están en `~/.claude/CLAUDE.md`.
> ⛔ No editar manualmente las zonas entre `<!-- X_START -->` y `<!-- X_END -->`.
> Última evolución: <!-- LAST_EVOLUTION -->YYYY-MM-DD<!-- /LAST_EVOLUTION -->

---

## 📊 MÉTRICAS DEL PROYECTO

<!-- METRICS_START -->
```json
{
  "total_sesiones": 0,
  "total_aprendizajes": 0,
  "errores_por_categoria": {
    "seguridad": 0, "interfaz": 0, "funcionalidad": 0, "operatividad": 0,
    "arquitectura": 0, "performance": 0, "testing": 0, "datos": 0,
    "celery": 0, "auth": 0, "docker": 0
  }
}
```
<!-- METRICS_END -->

---

## ⚠️ MAPA DE ZONAS DE RIESGO

<!-- RISK_MAP_START -->
| Archivo | Zona | Riesgo | Descripción |
|---|---|---|---|
| — | — | — | Sin zonas de riesgo registradas aún |
<!-- RISK_MAP_END -->

---

## 🧠 DECISIONES DE DISEÑO

<!-- REASONING_START -->
> Agregar aquí decisiones clave: qué se decidió, por qué, qué alternativas se descartaron.
<!-- REASONING_END -->

---

## 🗺️ MAPA DEL CÓDIGO

<!-- CODE_MAP_START -->
> Completar al inicio del proyecto. Ver `.claude/memory/project.md` para detalle completo.

🔴 Alta fragilidad: (identificar al explorar el proyecto)
<!-- CODE_MAP_END -->

---

## 🔐 SEGURIDAD

<!-- SECURITY_START -->
> Agregar reglas de seguridad específicas de este proyecto.
> Las reglas universales (no exponer env vars, .gitignore, etc.) están en ~/.claude/CLAUDE.md.
<!-- SECURITY_END -->

---

## 🖥️ INTERFAZ DE USUARIO

<!-- UI_START -->
> Agregar reglas específicas de UI de este proyecto.
> Sistema de diseño: ver `.claude/memory/design-system.md`
> Agentes de diseño: `ui-designer` (visual/estético) · `ui-ux-designer` (flujos/UX)
<!-- UI_END -->

---

## ⚙️ FUNCIONALIDAD

<!-- FUNCTIONALITY_START -->
> Documentar reglas de negocio y lógica específica del proyecto.
<!-- FUNCTIONALITY_END -->

---

## 🔧 OPERATIVIDAD

<!-- OPERABILITY_START -->
> Documentar cómo correr el proyecto, comandos frecuentes, gotchas de entorno.
<!-- OPERABILITY_END -->

---

## 🏗️ ARQUITECTURA

<!-- ARCHITECTURE_START -->
> Documentar decisiones arquitectónicas, patrones elegidos, restricciones.
<!-- ARCHITECTURE_END -->

---

## 🚀 PERFORMANCE / DATOS / AUTH

<!-- MISC_START -->
> Documentar gotchas de performance, manejo de datos, flujo de autenticación.
<!-- MISC_END -->

---

## 💬 HISTORIAL DE SESIONES

<!-- SESSIONS_START -->
| Sesión | Fecha | Resumen |
|---|---|---|
| #1 | YYYY-MM-DD | Sesión inicial |

> Historial completo en `.claude/memory/sessions.md`
<!-- SESSIONS_END -->

---

## 📚 SKILLS DEL PROYECTO

<!-- SKILLS_INDEX_START -->
| Skill | Descripción |
|---|---|
| — | Sin skills específicas aún |
<!-- SKILLS_INDEX_END -->

---

## 📈 EVOLUCIONES RECIENTES

<!-- EVOLUTION_LOG_START -->
| # | Fecha | Categoría | Aprendizaje |
|---|---|---|---|
| 1 | YYYY-MM-DD | — | Proyecto inicializado |

> Historial completo en `.claude/evolution-log.txt`
<!-- EVOLUTION_LOG_END -->

---

## 📖 Referencias

| Recurso | Ubicación |
|---|---|
| Stack, comandos, env vars, roles | `.claude/memory/project.md` |
| Sistema de diseño UI | `.claude/memory/design-system.md` |
| Checklist pre-cierre | `bash ~/.claude/self-check.sh` |
