# /helix-salud — Evaluación de Salud de Helix

Evalúa el estado actual de Helix bajo demanda y reporta problemas de eficiencia.
Úsalo cuando querés saber si Helix está funcionando bien antes de una sesión intensa.

---

## Al ejecutar este comando

### Paso 1 — Calcular métricas

```bash
bash ~/.claude/helpers/helix-metricas.sh {PROJECT_ROOT}
```

### Paso 2 — Interpretar y reportar

Mostrar al usuario un reporte honesto en este formato:

```
🏥 Helix Salud — {fecha}

Contexto    {score}/100  {✅/❌}  {problemas si los hay}
Calidad     {score}/100  {✅/❌}  {problemas si los hay}
Overhead    {score}/100  {✅/❌}  {problemas si los hay}

{Si todo OK:}
✅ Helix está funcionando bien. Sin problemas detectados.

{Si hay problemas:}
⚠️ Necesitamos hablar — detecté estas ineficiencias:
1. [problema 1]
2. [problema 2]

Propuesta de acción:
→ {acción concreta para resolver cada problema}
```

### Paso 3 — Proponer acciones concretas si hay problemas

- Contexto ❌ → proponer `/helix-actualiza` (comprime CLAUDE.md + refresca análisis)
- Calidad ❌  → mostrar los errores/pendientes de bitácora, pedir al usuario revisarlos
- Overhead ❌ → listar agentes/skills que probablemente no se usan en este proyecto

### Paso 4 — Preguntar si desea actuar ahora

"¿Querés que resuelva esto antes de continuar? (`/helix-actualiza` resuelve la mayoría)"

---

## Cuándo usar

- Antes de una sesión de trabajo intensa
- Cuando sentís que Helix está lento o torpe
- Cuando `/economia?` muestra métricas preocupantes
- session-start lo ejecuta implícitamente — `/helix-salud` es la versión interactiva
