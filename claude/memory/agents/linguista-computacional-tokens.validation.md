# Validación — linguista-computacional-tokens

> **Nota operativa:** el agente acaba de crearse. Agent tool carga su lista de agents al inicio de sesión (limitación documentada en evolution #60), por lo que no puede invocarse en esta misma sesión. Esta validación lista las preguntas + respuestas correctas para auto-evaluación cuando se invoque por primera vez. Threshold de activación: ≥80% (≥7/8 correctas).

---

## Preguntas (8 ítems del dominio)

### Q1 — Cross-lingual unfairness
¿Cuál es el ratio máximo documentado de diferencia en tokens para el mismo texto traducido entre dos idiomas, según la literatura peer-reviewed?

**Respuesta correcta:**
Hasta **15× de diferencia** entre algunos pares de idiomas. Incluso modelos byte-level muestran >4× diferencia. Fuente: Petrov, La Malfa, Torr, Bibi (2023) "Language Model Tokenizers Introduce Unfairness Between Languages" — NeurIPS 2023, arXiv:2305.15425.

---

### Q2 — Tokenizer ground truth
¿Por qué medir compresión en chars o words es metodológicamente inválido para un protocolo destinado a LLMs?

**Respuesta correcta:**
Porque LLMs procesan tokens, no chars/words. La relación char↔token varía por idioma (Anthropic glossary: "1 token ≈ 3.5 EN chars, varies by language") y por tokenizer (cl100k_base vs o200k_base vs claude tokenizer producen counts distintos). Un bench en chars puede mostrar 60% compresión que en tokens reales sea 20% o 90%. La métrica USD depende de tokens, no chars. Sin tokenizer + corpus + N declarados, el bench es soft-injection.

---

### Q3 — Diseño ASCII
¿Por qué un protocolo basado en ASCII puro (operadores `:`, `->`, `@`, `{}`) tokeniza eficientemente cross-lingual?

**Respuesta correcta:**
Byte-level BPE (usado por GPT-2/3/4 y derivados) tiene como vocabulario base los **256 valores de byte UTF-8**. Todo carácter ASCII (≤U+007F) ocupa 1 byte = 1 token base. En cambio, caracteres Unicode > U+007F ocupan 2-4 bytes UTF-8 = potencialmente 2-4 tokens. Un protocolo ASCII consume el mismo costo bajo independiente del idioma del usuario. Fuente: HF Transformers tokenizer summary §Byte-level BPE.

---

### Q4 — Vocabulario declarado
¿Qué ventaja tiene declarar un vocabulario al inicio de sesión y referenciarlo por hash (S:vocab) en lugar de re-citarlo en cada mensaje?

**Respuesta correcta:**
Evita re-tokenizar el mismo diccionario en cada handoff. Inspirado en SentencePiece (Kudo & Richardson 2018, arXiv:1808.06226): declarar el vocabulario una vez, hashearlo, y todos los agentes referencian por hash. Si el vocab es N tokens y se referencia M veces, el ahorro es ~(N×(M-1)) tokens. Para sesiones largas con re-uso de contexto este es el mecanismo donde HELIX-LANG promete ~97% (S:hash).

---

### Q5 — Lossless verification
Un colega afirma que su protocolo "comprime 60%". ¿Qué test mínimo exiges para validar que es lossless?

**Respuesta correcta:**
**Round-trip test:** `decode(encode(NL)) == NL` para un corpus de N≥50 mensajes representativos. Si la igualdad falla en cualquier mensaje, el protocolo es lossy y NO preserva contexto. Adicionalmente: declarar tokenizer, vocabulario base, y mostrar el corpus. Sin round-trip, "60% compresión" puede ser 60% de pérdida de información disfrazada.

---

### Q6 — Exclusiones del scope
Te piden aplicar HELIX-LANG a los commits de git para reducir costo. ¿Aceptas o rechazas? ¿Por qué?

**Respuesta correcta:**
**Rechazo.** Mensajes de commit son artefactos versionados leídos por humanos (revisores, archaeology git blame) y por herramientas formales (changelogs, semantic-release, CI/CD parsers que esperan conventional commits). Comprimirlos los hace ilegibles y rompe pipelines. La regla del experto es no comprimir lenguajes formales ni outputs user-facing. Recomiendo mantener commits en lenguaje natural y aplicar HELIX-LANG SOLO a handoffs inter-agente (capa interna).

---

### Q7 — Tradeoff vocabulario
Si aumentamos el vocabulario base de 256 a 50,000 tokens (como GPT-2 byte-level BPE), ¿qué ganamos y qué perdemos?

**Respuesta correcta:**
- **Ganamos:** mejor compresión para términos frecuentes (palabras comunes son 1 token en lugar de varios bytes).
- **Perdemos:** matriz de embeddings 195× más grande → más memoria, más cómputo, más latencia. Tokens raros pueden quedar fuera y caer a `<unk>` (en BPE clásico) o degradar a bytes (en byte-level).

Para HELIX-LANG el tradeoff aplica al vocabulario declarado por sesión: vocab demasiado grande → más overhead al transmitirlo; vocab demasiado pequeño → más términos sin código corto. Sweet spot empírico: ~30-100 entradas por sesión.

Fuente: HF Transformers §Byte-level BPE (GPT-2: 256 base + 50,000 merges + special token = 50,257). Sennrich 2016 §3 sobre tradeoff.

---

### Q8 — Cross-tokenizer replication
Tu bench en `cl100k_base` muestra 50% compresión. ¿Puedes prometer que en `o200k_base` o claude tokenizer también será 50%?

**Respuesta correcta:**
**No.** Cada tokenizer tiene vocabulario y reglas de merge distintos. Un protocolo que aprovecha tokens compuestos comunes en `cl100k_base` puede no encontrarlos en `o200k_base` (vocab más nuevo, ~200k entries) ni en claude tokenizer (proprietario, no público). Anthropic explícitamente: "exact number can vary depending on the language used". Recomiendo replicar el bench en cada tokenizer del modelo target antes de prometer un número. Si el protocolo se va a usar con varios modelos, reportar el rango (min-max) o el peor caso, no el promedio.

---

## Auto-evaluación

Cuando el agente se invoque por primera vez (próxima sesión), debe poder responder estas 8 preguntas con ≥80% de acuerdo con las respuestas de arriba. Si <80%, volver a fase 4 (síntesis insuficiente) o fase 2 (research insuficiente, no parchar con más texto).

Resultado validación: **PENDIENTE primera invocación**.
