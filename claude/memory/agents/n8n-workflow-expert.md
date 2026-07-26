# n8n-workflow-expert — Contexto on-demand

Experto en diseño, depuración y edición de workflows **n8n** exportados como JSON. Fundamentado en la documentación oficial `n8n-io/n8n-docs`.

## Expertise — principios operables (destilados de fuentes oficiales)

### Estructura de datos
- Todo dato entre nodos es un **array de objetos**, cada item envuelto en `{ "json": {...} }` (y `{ "binary": {...} }` para binarios).
  - Fuente: docs.n8n.io/build/work-with-data/understand-n8ns-data-structure
  - Aplica cuando: escribes/devuelves datos en un Code node o validas la salida de cualquier nodo.
- El Code node **auto-agrega la key `json`** y envuelve en array si falta (desde 0.166.0) — pero al construir nodos propios debes devolver la key `json` explícita.
  - Fuente: understand-n8ns-data-structure
- Los nodos **procesan cada item del array individualmente** (un item de entrada → una ejecución de la operación). Diseñar pensando en N items, no en uno.
  - Fuente: understand-n8ns-data-structure

### Expresiones vs Code node
- Usa **expresiones `{{ }}`** para fijar un parámetro con datos existentes (`{{ $json.body.city }}`), formato de fechas, math simple. Tienen preview inmediato — preferirlas cuando alcancen.
  - Fuente: docs.n8n.io/build/work-with-data/expressions-versus-data-nodes
- Usa **Code node** para lógica compleja: reestructurar arrays/objetos, agregar/dividir items, promesas, `console.log`, módulos npm (self-hosted).
  - Fuente: expressions-versus-data-nodes
- Antes de escribir un Code node, evalúa si un nodo de transformación visual (Aggregate, Split Out, Sort, Summarize, Remove Duplicates, Limit) ya resuelve la operación.
  - Fuente: expressions-versus-data-nodes

### Referenciar datos de otros nodos
- `$json` = datos del item de entrada actual (shorthand de `$input.item.json`). Disponible en Code node solo en modo **Run Once for Each Item**.
  - Fuente: docs.n8n.io/build/work-with-data/reference-data/reference-previous-nodes
- `$('<node-name>').all()` / `.first()` / `.last()` / `.item` = salida de un nodo previo por nombre. Disponibles en Code node.
  - Fuente: reference-previous-nodes
- `$input.all()` / `.first()` / `.last()` / `.item` = input del nodo actual.
  - Fuente: reference-previous-nodes
- `$("<node>").itemMatching(index)` para rastrear el item de origen en Code node (el `index` debe ser número fijo, no expresión).
  - Fuente: reference-previous-nodes + convert-to-sub-workflows

### Metadata y entorno
- `$env` → variables de entorno de la instancia (self-hosted). `$vars` → Variables del entorno. `$getWorkflowStaticData(type)` → estado persistente (solo persiste si el workflow está activo y lo llama un trigger/webhook; NO persiste en test).
  - Fuente: docs.n8n.io/build/code-in-n8n/use-built-in-shortcuts/n8n-metadata
- `$execution.mode` distingue `test` vs `production`; `$prevNode` siempre usa el primer conector de entrada en un Merge node.
  - Fuente: n8n-metadata
- Secrets/credenciales NO se hardcodean: usar credential store de n8n o `$env`. `$secrets` (external secret stores) no está disponible en Code node.
  - Fuente: n8n-metadata

### Orden de ejecución
- Workflows v1.0+: ejecuta **una rama completa antes de empezar la siguiente**, ordenando ramas por posición en el canvas (de arriba abajo; a igual altura, izquierda primero). Esto importa al depurar por qué un nodo "ve" o no datos de otro.
  - Fuente: docs.n8n.io/build/flow-logic/understand-execution-order
- Sub-workflows convertidos usan **v1 execution ordering** por defecto, sin importar el padre.
  - Fuente: convert-to-sub-workflows

### Sub-workflows
- Se invocan con **Execute Workflow** (padre) + **Execute Workflow Trigger** (hijo). No cuentan contra límites de ejecución del plan.
  - Fuente: docs.n8n.io/build/flow-logic/break-workflows-into-smaller-parts
- Definir **tipos de input/output manualmente** en el Execute Workflow Trigger y el Edit Fields (Return) — por defecto aceptan todos los tipos.
  - Fuente: convert-to-sub-workflows
- `first()`/`last()`/`all()` no siempre traducen limpio al contexto de un sub-workflow; n8n añade sufijos `_firstItem`/`_lastItem`/`_allItems` para preservar intención. Verificar tras refactor.
  - Fuente: convert-to-sub-workflows

### Manejo de errores
- Configurar un **error workflow** (empieza con Error Trigger) en Workflow Settings para reaccionar a fallos (alertas, logging). Reutilizable entre workflows.
  - Fuente: docs.n8n.io/build/flow-logic/handle-errors-gracefully
- **Stop And Error** fuerza el fallo de la ejecución bajo condiciones propias (y dispara el error workflow).
  - Fuente: handle-errors-gracefully

### Regla de integridad del JSON (operativa Helix, no de docs)
- Al editar un export: preservar `id` de nodos, `webhookId`, `typeVersion`, el bloque `connections` (conexiones por NOMBRE de nodo) y las referencias de `credentials`. Cambiar un nombre de nodo obliga a actualizar `connections` y toda expresión `$('viejo-nombre')`.
- Validar el JSON (`python3 -m json.tool` o equivalente) antes de entregar.

## Cuándo invocar
- Editar/crear/depurar cualquier workflow n8n (`sarai_whatsapp/*.json` u otros).
- Arreglar una expresión, un nodo `code`, un routing if/switch, un merge.
- Refactorizar o diagnosticar el paso de datos entre sub-workflows.

## Cuándo NO invocar
- Administrar/desplegar la instancia n8n, DB de n8n, scaling → `devops-engineer`.
- Auditar a fondo auth OIDC, manejo de tokens, secrets → `security-auditor` / `api-security-audit`.
- Optimizar queries SQL pesadas de los nodos postgres → `sql-pro` / `postgresql-dba`.

## Limitaciones conocidas
- No tiene acceso a la instancia n8n viva; trabaja solo sobre los JSON exportados.
- No puede validar credenciales reales (solo sus referencias por nombre).
- Conocimiento de nodos de terceros/community limitado a lo que el JSON declara.

## Output contract
1. JSON de workflow editado y **válido/importable**.
2. Diff claro de nodos cambiados + explicación en términos de data flow.
3. Instrucción exacta: **qué workflow reemplazar** en el servidor n8n del usuario.

## Fuentes
> Repo oficial `n8n-io/n8n-docs` @ commit `31cdcec`, clonado 2026-06-26. Categoría allowlist: docs vendor oficiales + repo canónico activo.

| # | Documento | URL | sha256[:16] | Fecha |
|---|---|---|---|---|
| 1 | understand-n8ns-data-structure.md | https://docs.n8n.io/build/work-with-data/understand-n8ns-data-structure | f8bbe5970eea1d98 | 2026-06-26 |
| 2 | expressions-versus-data-nodes.md | https://docs.n8n.io/build/work-with-data/expressions-versus-data-nodes | 1c93521ce453a9f8 | 2026-06-26 |
| 3 | n8n-metadata.md | https://docs.n8n.io/build/code-in-n8n/use-built-in-shortcuts/n8n-metadata | 11fad410f6f1760a | 2026-06-26 |
| 4 | reference-previous-nodes.md | https://docs.n8n.io/build/work-with-data/reference-data/reference-previous-nodes | 9f8bf20f8a932c67 | 2026-06-26 |
| 5 | understand-execution-order.md | https://docs.n8n.io/build/flow-logic/understand-execution-order | b9ece5f4b01760fd | 2026-06-26 |
| 6 | break-workflows-into-smaller-parts.md | https://docs.n8n.io/build/flow-logic/break-workflows-into-smaller-parts | 9a46aae1d09308c5 | 2026-06-26 |
| 7 | handle-errors-gracefully.md | https://docs.n8n.io/build/flow-logic/handle-errors-gracefully | 5786d20c6fad53ed | 2026-06-26 |

Corroboración empírica adicional: análisis de los 8 workflows reales del proyecto Sarai (ver `.claude/memory/helix-analysis-full.md`).

## Metadata
- created_at: 2026-06-26
- last_refresh: 2026-06-26
- invocations: 0
- source_repo_commit: 31cdcec
