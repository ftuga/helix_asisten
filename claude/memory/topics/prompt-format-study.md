# Estudio pendiente — formato de prompts/doctrina (md vs json vs xml)

> Apuntado 2026-05-07 por el creator al cierre de la sesión post-bench HELIX-LANG. No urgente. Diseñar bench antes de tocar archivos.

## Pregunta

¿Vale la pena migrar `~/.helix/CLAUDE.md`, `topics/*.md`, `agents/*.md`, prompts del council y skills a un formato más estructurado (JSON / XML / YAML estricto / TOML) para reducir tokens y mejorar parseo de los LLMs?

## Hipótesis previas (a validar empíricamente)

### Lo que apunta a favor de XML/JSON

- **Anthropic recomienda XML** explícitamente en su prompt engineering guide para Claude. Los modelos están entrenados con instrucciones marcadas con `<instructions>`, `<example>`, `<thinking>`. XML sintáctico parece tener inductive bias positivo en Claude específicamente.
- **JSON estructurado** es ideal cuando el LLM necesita extraer campos específicos sin parsear prosa. Reduce ambigüedad.
- **Schema declarativo** habilita validación previa al envío al modelo (jsonschema, json-schema-to-pydantic). Captura errores antes de gastar tokens.

### Lo que apunta en contra

- **Token overhead de sintaxis:** comillas, llaves, comas, indentación. Markdown es casi prosa pura, mínimo overhead.
- **Bench Anthropic Cookbook:** en pruebas internas, MD tiende a ganar en tareas narrativas; XML gana en tareas estructuradas con extracción. La doctrina de Helix es 80% narrativa.
- **Mantenibilidad:** el creator lee/edita `.md` con cualquier editor sin schema mental. JSON/XML obliga a respetar estructura — fricción para edits rápidos.
- **Búsqueda y diff legibles:** `grep` y `git diff` sobre MD son cristalinos; sobre JSON minified son ilegibles, sobre JSON pretty-printed siguen siendo ruidosos.
- **Cache hits de Anthropic:** prompts cacheados se penalizan si la sintaxis cambia frecuentemente. JSON/XML genera más cache misses por reformateo accidental.

## Bench propuesto (cuando se retome)

Ejecutar **antes** de migrar nada:

1. **Corpus:** `CLAUDE.md` actual (~700 líneas) + 3 prompts del council + 1 agente complejo (linguista o council-arbiter).
2. **Conversiones:**
   - Versión MD original (baseline)
   - Versión XML con tags semánticos (`<rule>`, `<section>`, `<example>`)
   - Versión JSON con schema (campos `rules[]`, `sections[]`, `examples[]`)
   - Versión YAML estricto (alternativa intermedia)
3. **Mediciones (con tiktoken local, regla CS1):**
   - Tokens de cada versión en `cl100k_base` y `o200k_base`
   - Latencia de la primera respuesta del modelo (p50, p95) sobre 10 queries idénticas
   - Calidad subjetiva del output: ¿el LLM extrae mejor las reglas? ¿reduce errores de routing?
   - Cache hit rate de Anthropic (en prompts cacheables)
4. **Costo de migración:**
   - Líneas de doctrina a re-escribir
   - Tooling para edits (¿editor con schema validation?)
   - Compatibilidad con `evolve.sh`, `session-start.sh`, `self-check.sh` (todos parsean MD hoy)

## Decisión criteria propuesta

Migrar **solo** si bench muestra:
- Reducción de tokens ≥ 25% en input total promedio
- Mejora medible en calidad de output (no solo tokens)
- Costo de migración < ahorro proyectado a 6 meses (estimar invocaciones × tokens × tarifa)

Si la mejora es <15% solo en tokens sin ganancia de calidad → **mantener MD** (mantenibilidad gana).

## Variantes intermedias a considerar

- **MD + frontmatter YAML enriquecido** (lo que ya hace Helix). Mantenibilidad alta + estructura mínima.
- **MD con tags XML embebidos** (`<rule id="R1">...</rule>` dentro de prosa MD). Híbrido — Anthropic friendly sin perder legibilidad.
- **Compilación derivada:** mantener MD como fuente, generar JSON/XML compilado on-demand para inyectar en prompts. Mejor de ambos mundos a costo de tooling extra.

## Fuentes a revisar al retomar

- Anthropic prompt engineering docs § Use XML tags
- Anthropic Cookbook benchmarks (si publican comparación de formatos)
- Petrov et al. 2023 (ya consultado) — relevante para tokens, no para estructura
- Bench propio: `linguista-computacional-tokens` puede correrlo (es exactamente su dominio)

## Estado

`PENDIENTE` — sin fecha. Volver cuando haya tiempo dedicado o cuando se observe friction con MD (parseo, errores de routing, cache miss alto).
