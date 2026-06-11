# Auditoría arquitectural externa — HELIX

Evaluación basada exclusivamente en el bundle entregado (CLAUDE.md global, agents-index.md, frontmatter de agentes, inventario de skills, council-design, route-cost-audit). Donde el bundle no alcanza, lo declaro.

---

## 1. Funcionalidad

**Qué es.** Helix es una meta-capa personal sobre Claude Code: routing por capas (Ollama local → subagentes → swarm → teams), una capa de seguridad de hooks (HSL), un log de auto-evolución, un council deliberativo de 7 roles, tracking de costos, snapshots de sesión y un protocolo de compresión inter-agente. El problema que resuelve es real: un solo operador que quiere que su harness acumule aprendizajes, controle costos y no repita errores entre proyectos.

**Lo que funciona con evidencia de uso.** El council se usa de verdad (132 calls en routing-feedback, el dominio más activo) y ha producido valor verificable: el council del 2026-05-07 detectó que HELIX-LANG comprimía 2.2% contra una promesa de 59%. El loop de evolución también funciona: las evoluciones #87–#90 son un caso ejemplar de "promesa → bench → ajuste → archivo de la v3 por evidencia". Eso es disciplina empírica genuina, no decorado.

**Feature-creep identificable.**
- **Tres mecanismos de ahorro de tokens conviviendo**: HELIX-LANG, HELIX-SPEAK y HELIX-DISTILL. El propio bench (evolution #87) muestra que HELIX-LANG en inglés cuesta *más* que la prosa (-3.5% en cl100k), y la adopción medida fue 0% en 3 councils (MIT1) y 2.2% después. Tres protocolos para un problema que la evidencia propia dice que es marginal (#90: corpus near-óptimo, ahorro real 0.30% lexical).
- **Capacidades implementadas pero nunca cableadas**: evolution #83 lo admite — `helix-route.sh pick` existía sin uso, `r1-recommend-log.jsonl` tenía 0 líneas en todos los proyectos hasta el fix. El patrón "diseñar capability ≠ activar capability" está diagnosticado por el propio sistema y sigue ocurriendo.
- **Sobrecarga meta.** De las evoluciones #58–#94, la gran mayoría son sobre Helix mismo, no sobre productos. El dominio más invocado del routing es `council` (132 calls vs 36 de frontend y 14 de backend). Un harness cuyo mayor consumidor es su propia deliberación tiene un problema de ratio meta-trabajo/trabajo que conviene medir explícitamente.
- **Capa 3 (Agent Teams)**: declarada NO IMPLEMENTADA en la doctrina. Honesto, y correcto haberlo dejado visible.

---

## 2. Habilidades técnicas y stack

**Aciertos.**
- **D3 (bash+Python para core)** es la decisión correcta para un sistema de un solo mantenedor: cero toolchain, iteración barata, reversibilidad por `git restore`. La justificación está escrita y es defendible.
- **D2 (local-first, on-demand only para egress)** con el invariante D2.1 (sin cron, sin scheduler, creator como testigo) es un diseño de seguridad maduro y poco común.
- La cultura de **reversibilidad** (kill switches `HELIX_LANG_ENFORCE=0`, `HELIX_R1_ENABLED=0`, `HELIX_D1_TRIGGER_ENABLED=0`, backups timestamped) es consistente y bien aplicada.
- La honestidad de datos en route-cost-audit §4 ("success rate ~100% sugiere métrica sub-calibrada", "recomendaciones heurísticas no observadas") es lo que uno quiere ver en un sistema auto-evaluado.

**Deuda técnica con evidencia.**
- **La fragilidad de hooks es estructural, no incidental.** Dos incidentes documentados: claude-flow MCP secuestró los 16 slots de hooks silenciando HSL sin warning (2026-05-06), y "HSL hooks pueden desaparecer silenciosamente cuando un proceso reescribe settings.json" (mismo día). La mitigación es un consejo manual ("validar post-edición: jq que confirme presence..."). Un sistema cuya capa de seguridad puede apagarse en silencio y cuya defensa es "acuérdate de correr jq" no tiene defensa. Falta el check automático en session-start.
- **Latencia floor de bash+Python**: SEC1 no cumple su criterio (<30ms, p99 real 77ms) por el startup de ~35ms. La decisión quedó "pending decisión latencia" desde 2026-05-03 — un mes sin resolver. D3 tiene un costo real aquí que la doctrina no reconcilia.
- **Path bug parcial** (evolution #94): 3 helpers siguen sin respetar `CLAUDE_CONFIG_DIR` (`helix-project-consolidate.py`, `helix-multidomain-trigger.py`, `helix-judge.py`). Drift conocido y sin cerrar.
- **Pricing histórico 3× inflado** durante semanas (Opus hardcoded $15/$75 vs $5/$25 real). Se corrigió en #94, pero significa que toda decisión de costo tomada entre la migración a Opus 4.5+ y junio se basó en números falsos — incluyendo posiblemente las recomendaciones de DOMAIN_RECOS. El council-design todavía dice "$0.40-0.80 por council" calculado con precios viejos.

---

## 3. Agentes

**El índice y la realidad divergen seriamente.** Esto es el hallazgo más grave de la sección:

- **Un ecosistema UI completo no indexado**: `a11y-expert`, `design-bridge`, `motion-designer`, `performance-ui`, `refactoring-specialist`, `tokens-manager`, `ui-architect`, `ui-debugger`, `ui-designer`, `ui-tester`, `ux-researcher`, `code-reviewer-frontend` — ~12 agentes con frontmatter (sección 3 del bundle) que no aparecen ni en "Activos" ni en "Deshabilitados" de agents-index.md. El índice declara ser la fuente de routing ("1 dominio → 1 agente") y no conoce un quinto del catálogo.
- **"Deshabilitados" que sí se invocan**: route-cost-audit registra `backend-developer` (2 calls) y `ui-ux-designer` (5 calls), ambos en listas de deshabilitados/removidos. La lista de deshabilitados no se materializa en ningún mecanismo — es documentación aspiracional.
- **Contradicción directa**: `ui-designer` figura en "Removidos 2026-04-27 (no tenían archivo)" pero su frontmatter existe en el bundle. O se restauró sin actualizar el índice, o el índice nunca fue correcto.
- **`architect-reviewer` aparece duplicado** en el frontmatter (dos bloques idénticos) — probable archivo duplicado en disco.
- El bundle anuncia "65 agentes locales" pero lista ~47 frontmatter. Evidencia insuficiente para saber cuál cifra es la real.

**Redundancias concretas.**
- `test-engineer` vs `test-automator`: descripciones casi intercambiables ("test automation, coverage, CI"). Uno sobra o necesitan fronteras escritas.
- `security-auditor` vs `api-security-audit`: la regla dura exige invocar *ambos* en cada endpoint nuevo, lo que duplica costo sin justificación documentada de qué aporta cada uno.
- `code-reviewer` vs `code-reviewer-frontend`: el segundo no está indexado y el primero es obligatorio pre-cierre, así que el segundo probablemente nunca se invoca.
- `ui-designer` vs `ux-researcher`: ambos haiku, ambos "convertir requerimiento vago en spec antes de codificar". Solapados.

**Defectos puntuales.**
- `postgresql-dba` declara tools de la extensión PostgreSQL de VS Code (`pgsql_connect`, `pgsql_query`...) que no existen en el harness CLI. Agente probablemente no funcional tal como está; `sql-pro` y `database-architect` cubren el dominio.
- `app-creative-genius` dice "for **this CV evaluation API**" — un agente de proyecto específico promovido a catálogo global sin genericizar. Drift de copy-paste.
- `investment-expert` y `brand-identity-expert` en un harness de ingeniería: legítimos si el creator los usa, pero no hay evidencia de invocaciones en route-cost-audit. Evidencia insuficiente para pedir su remoción; sí para pedir que justifiquen su costo de contexto.

**Lo bien hecho**: la separación council-* con la advertencia "NUNCA invocar fuera de council" en cada description, el mix de modelos por rol (haiku para mecánicos, opus para síntesis), y el drift-cleanup del 2026-04-27 muestran que el mantenimiento existe — solo que no alcanza el ritmo al que el catálogo crece.

---

## 4. Prácticas y protocolos

**DISCOVERY-FIRST: útil, con un costo de fricción aceptable.** El chequeo stack↔petición y el staleness check atacan fallas reales de agentes LLM (asumir stack, responder con memoria vieja). La "regla dura" de auto-registro de fallos de protocolo es inusual y valiosa. Crítica menor: cinco condiciones de "preguntar antes" más el Protocolo de Diálogo (12 reglas) más el checklist pre-cierre (9 ítems) es mucha superficie normativa para que un modelo la cumpla consistentemente; no hay evidencia en el bundle de qué porcentaje de estas reglas se cumple en la práctica.

**HELIX-LANG: la contradicción más clara entre doctrina y evidencia propia.** La cronología lo condena: 2026-05-07 se hace OBLIGATORIO (evolution #84, council n0n28i); *el mismo día* el bench del linguista mide compresión real de 23.6% (no 59%), **negativa en inglés** (-3.5%), y un caso lossy real (#87); el 2026-05-08 la v3 se archiva porque el corpus es "near-óptimo entropicamente" con ahorro real de 0.30% (#90). La skill se corrigió con honestidad (v2.1, ADJ-1..4), pero **el mandato en CLAUDE.md sigue intacto**: "todo handoff entre agentes Helix DEBE incluir un bloque HELIX-LANG". El sistema mantiene obligatorio un protocolo que su propia medición muestra como costo neto en el idioma dominante de sus prompts (capa 5 = inglés). Esto es exactamente el tipo de inconsistencia que el council existe para evitar.

**Capa 2: una regla dura que apunta a un mecanismo descontinuado.** La tabla de ORQUESTACIÓN dice "Capa 2 — `mcp__claude-flow__swarm_init`" y la regla dura prohíbe múltiples Agent tool en paralelo para 2+ dominios. Pero D1' descontinuó claude-flow, la "Capa 2 propia" quedó "candidate TRANCH 3 si surge demanda" (evolution #76), y además la sección de seguridad documenta que claude-flow MCP **silencia HSL v1**. Resultado: la regla dura es insatisfacible — el modo `helix_control_total` promete 4 capas y opera con ~2. El hook D1' detecta el caso multi-dominio pero solo en modo advisory; no hay destino válido al que escalarlo.

**Council: el protocolo mejor diseñado del sistema.** Constitución con triggers y acciones por regla, audit inmutable chmod 400, mix de modelos justificado, agregación con confidence weighting, anti-herding (Round 1 ciego), y citas a literatura real. Dos críticas: (a) la tabla de costos usa pricing obsoleto; (b) el council aprobó el enforcement de HELIX-LANG que la evidencia desmontó horas después — el aprendizaje M3 ("ejecutar la precondición más cheap+informativa primero", 2026-05-06) existía y no se aplicó. El council es bueno deliberando y mediocre verificando antes de cementar.

**Decisiones cementadas**: D1' honesta (admite que la métrica original era inválida), D2/D2.1 sólida, D3 correcta con el caveat de latencia ya mencionado. **D4 (creator vs user) es productización prematura**: no hay evidencia en el bundle de que exista un solo usuario distinto del creator; el rol `user` es infraestructura especulativa.

**Referencia rota crítica**: las decisiones cementadas citan `topics/helix-evolution-plan-v4-decision.md` cuatro veces como fuente de detalle y audit; el bundle declara "(no existe — usar evolution-completed)". El documento de respaldo de las decisiones más importantes del sistema no está donde la doctrina dice.

**Drift de metadata**: el bloque METRICS dice `total_skills_creadas: 1` (hay 39 en inventario) y `ultima_actualizacion: 2026-04-18` (las evoluciones llegan a #94, 2026-06-10). La tabla SESIONES tiene una sola fila malformada con celdas rotas ("0\n0"). La numeración de evoluciones salta (58, 60, 62, 69, 75...) sin explicación. El protocolo de auto-evolución registra aprendizajes pero no mantiene sus propios contadores.

---

## 5. Skills

**El inventario tiene un problema de adopción sin curaduría.** De 39 skills, un bloque grande viene claramente de packs externos (aitmpl) sin reconciliar con el catálogo propio:

- **El pack `senior-*` (7 skills)**: senior-architect, senior-backend, senior-frontend, senior-fullstack, senior-qa, senior-security, senior-data-scientist. Cada una solapa con 1–3 agentes activos (backend-architect, frontend-developer, test-engineer, security-auditor, data-analyst...). Doble dispatch para el mismo dominio sin regla de cuándo usar la skill vs el agente.
- **Cinco-seis artefactos de diseño UI solapados**: `frontend-design`, `ui-ux-pro-max`, `ui-design-system`, `web-design-guidelines`, `ux-researcher-designer`, más `design-system` en memory y el ecosistema de 12 agentes UI no indexados. Es la zona de mayor redundancia de todo Helix.
- **Colisiones de nombre exacto**: skill `code-reviewer` vs agente `code-reviewer`; skill `ux-researcher-designer` vs agente `ux-researcher`. Para un sistema que rutea por nombre, esto es ambigüedad de dispatch directa.
- **React por cuadruplicado**: `react-best-practices`, `react-dev`, `nextjs-best-practices`, `senior-frontend` cubren territorio superpuesto sin fronteras declaradas.

**Las skills helix-* nativas son la parte buena**: naming consistente, disparadores explícitos en la description ("invocar cuando el creator pida X"), y varias codifican decisiones de council (helix-judge con D2.1, helix-route-recommend read-only). `context-budget` existe precisamente para auditar este bloat — evidencia insuficiente sobre si se ha corrido contra el propio inventario, pero los 39 skills sugieren que no, o que sus recomendaciones no se ejecutaron.

**Faltante crítico**: no hay skill ni hook de **verificación de integridad del harness** (presencia de hooks HSL en settings.json, consistencia agents-index↔disco, referencias de CLAUDE.md a archivos existentes). Los tres tipos de drift que esta auditoría encontró son exactamente los que esa skill detectaría.

---

## 6. Recomendaciones priorizadas

**P0 — drift activo que rompe flujos**

1. **Resolver la contradicción Capa 2.** CLAUDE.md manda usar `mcp__claude-flow__swarm_init` (descontinuado por D1' y documentado como secuestrador de hooks HSL) y prohíbe la única alternativa práctica (Agent tools paralelos). Decidir: o se implementa la Capa 2 propia mínima, o se relaja la regla dura a "Agent tools paralelos permitidos con log". Esfuerzo: S (editar doctrina) o L (implementar orquestador). Verificación: `grep -n "claude-flow" ~/.claude/CLAUDE.md` no devuelve referencias operativas en ORQUESTACIÓN ni en la tabla MCP.

2. **Sincronizar agents-index.md con el disco.** Indexar los ~12 agentes UI huérfanos, resolver el estado de `ui-designer` (removido pero con archivo), eliminar el duplicado de `architect-reviewer`, y decidir si "Deshabilitados" se materializa (mover archivos fuera de `~/.claude/agents/`) o se elimina la sección — hoy es ficción (backend-developer y ui-ux-designer registran invocaciones). Esfuerzo: M. Verificación: script que compare `ls ~/.claude/agents/*.md` contra el índice y salga 0.

3. **Restaurar o corregir la referencia a `topics/helix-evolution-plan-v4-decision.md`.** Las cuatro decisiones cementadas apuntan a un archivo inexistente. Recuperarlo de git/backups o reescribir las referencias al documento que sí existe. Esfuerzo: S. Verificación: todos los paths citados en §DECISIONES CEMENTADAS existen (`test -f`).

4. **Re-litigar HELIX-LANG obligatorio en council.** La evidencia propia (bench #87: -3.5% en EN; #90: ahorro real 0.30%; adopción 0–2.2%) contradice el mandato de #84. Degradar a opt-in para corpus no-EN, o producir el bench que justifique mantenerlo. Esfuerzo: S (council + edición). Verificación: CLAUDE.md §HELIX-LANG cita el bench y el alcance coincide con la evidencia; audit log del nuevo council.

**P1 — alto impacto, bajo costo**

5. **Hook de integridad HSL en session-start.** Convertir el consejo manual del 2026-05-06 ("jq que confirme presence de los 3 hooks") en chequeo automático con warning visible. Es la lección más cara del sistema y sigue siendo manual. Esfuerzo: S. Verificación: borrar un hook de settings.json en un entorno de prueba → session-start lo reporta.

6. **Actualizar METRICS, SESIONES y pricing del council-design.** Contadores congelados en 2026-04-18, tabla de sesiones malformada, y costo por council calculado con Opus a $15/$75. Esfuerzo: S. Verificación: METRICS refleja skills reales y fecha actual; council-design usa la pricing table de #94.

7. **Cerrar el path bug de los 3 helpers pendientes** (`helix-project-consolidate.py`, `helix-multidomain-trigger.py`, `helix-judge.py` sin `CLAUDE_CONFIG_DIR`), documentado en #94 como incompleto. Esfuerzo: S. Verificación: `grep -L CLAUDE_CONFIG_DIR` sobre los tres devuelve vacío y smoke test pasa.

**P2 — consolidaciones**

8. **Purga de skills externas.** Correr `context-budget` contra el inventario y archivar el pack `senior-*` (7 skills) y 3–4 de las skills UI solapadas, o escribir reglas de frontera skill-vs-agente. Resolver las colisiones de nombre (`code-reviewer`). Esfuerzo: M. Verificación: inventario ≤30 skills sin colisiones de nombre con agentes.

9. **Eliminar o reescribir `postgresql-dba`** (tools de extensión VS Code inoperantes en CLI; sql-pro + database-architect cubren) y **genericizar `app-creative-genius`** (referencia a "this CV evaluation API"). Esfuerzo: S. Verificación: ningún frontmatter referencia tools inexistentes ni proyectos específicos.

10. **Fusionar test-engineer/test-automator y definir frontera security-auditor/api-security-audit.** Dos pares con descripciones intercambiables; el segundo par además se invoca en tándem obligatorio sin justificación de qué aporta cada uno. Esfuerzo: M. Verificación: agents-index documenta una frontera de una línea por par, o el par quedó fusionado.

**Veredicto general.** Helix tiene una columna vertebral seria — council, reversibilidad, auditoría de costos con caveats honestos, y un loop de evolución que de verdad corrige rumbo con datos. Su patología no es falta de diseño sino exceso: la doctrina crece más rápido que su enforcement, y la brecha entre lo escrito y lo cableado (índices, hooks, reglas duras insatisfacibles, referencias rotas) es hoy el mayor riesgo operativo. El sistema ya sabe diagnosticarse (evolutions #83, #87, #90 lo prueban); lo que falta es que la limpieza tenga la misma prioridad que la creación.
