---
name: helix-lang
description: Protocolo inter-agente v3. Compresion empirica Forma 1 +33%, Forma 2 +14-40%, Forma 3 +38-47% sobre handoffs sinteticos (cl100k_base, tiktoken 0.12.0, N=14). ROI real sobre texto completo de council 10-23.6% segun corpus e idioma (ES +23.6%, EN -3.5%, CJK +44-59%). S:hash breakeven ~1.1 mensajes. Solo Capa 2, Capa 3 y Council. Nunca user-facing.
version: 3.0-DRAFT
status: DRAFT
council_authority: 20260507T215307Z-109qf (GO_WITH_PRECONDITIONS, 7 precondiciones)
allowed-tools: Read, Write, Edit, Bash
---

> DRAFT -- pendiente de piloto N=2 (Council A meta-circular + Council B tecnico externo).
> v2.1 en SKILL.md sigue siendo el spec activo hasta que el piloto pase criterios M1-M5.
> No activar en produccion sin que P1 (rubrica M3 firmada) este completa.
> Decision de council: audit log inmutable ~/.helix/council/log/20260507T221107Z_20260507T215307Z-109qf.yaml

---

# HELIX-LANG v3 -- Protocolo Universal Inter-Agente

Principio rector del creator (hard constraint, citado literal):
"ahorre pero no pierda contexto. De nada me sirve ahorrar el 100% si no soluciona."
Cualquier ahorro que comprometa claridad de contexto debe ser flaggeado y descartado
por default. Este principio tiene precedencia sobre cualquier optimizacion de tokens.

Scope: comunicacion INTERNA entre instancias LLM de Helix (council, swarm, agent teams,
memoria inter-agente). Nunca user-facing. La capa user-facing (Capa 1) permanece intacta
con las reglas de CLAUDE.md seccion IDIOMA Y TONO.

---

## 1. Anatomia del hablante BPE

El receptor de este protocolo no es un humano -- es un LLM con un tokenizador BPE.
Disenarlo como si fuera un humano (ingles con abreviaciones, colons como separadores
de rol) es equivalente a hablarle Klingon al alien sin boca (Infoprimates, 5 pasos de
diseno de idioma, Paso 1: la anatomia del hablante determina todo lo demas).

### 1.1 Landscape de tokenizadores

| Modelo | Tokenizador | Acceso en bench | Status |
|---|---|---|---|
| Claude Sonnet 4.6 / Opus 4.7 / Haiku 4.5 | Anthropic propietario | NO | Proxy declarado |
| Ollama llama3.2:3b (Capa 0) | SentencePiece / tiktoken fork | NO | Sin datos |
| GPT-4o | o200k_base | SI -- benchmarkeado | Referencia secundaria |
| GPT-3.5 / embeddings | cl100k_base | SI -- benchmarkeado | Proxy primario para Claude |

Gap CS1 declarado: todos los numeros de este spec usan cl100k_base como proxy del
tokenizador Anthropic (decision P3 del creator, council 20260507T215307Z-109qf).
Los numeros son "orden de magnitud correcto con proxy declarado" -- no medicion exacta.

Benchmarks: tiktoken 0.12.0 local. Corpus: 82 secuencias de protocolo + 14 lineas reales.
Fecha: 2026-05-07. Audit: ~/.helix/memory/audit/linguista-bench-20260507.yaml

### 1.2 Clausula de sunset por cambio de tokenizador (DA4-MIT)

CONDICION OBLIGATORIA: si Anthropic actualiza su modelo (nuevo Claude) o cambia los BPE
merges del tokenizador, HELIX-LANG v3 requiere revalidacion del bench M1 antes de
continuar en produccion. Racional: el bench de compresion de v3 esta condicionado a que
los 450 bigrams ASCII identificados como fusiones nativas de 1 token (seccion 1.3)
permanezcan estables. Esto no esta garantizado entre versiones de tokenizador.

Trigger de revalidacion: cualquiera de los siguientes eventos activa el proceso:
  (a) Anthropic anuncia nuevo modelo base (Claude N+1) con tokenizador diferente.
  (b) Los costs de API measurados en un council piloto divergen >5% respecto a la
      estimacion cl100k en la misma sesion.
  (c) Un bench cl100k/o200k muestra divergencia >10pp en las secuencias de la Tabla 1.3.

Accion ante trigger: re-correr el bench de la seccion 1.3 con el nuevo tokenizador.
Si el ahorro en ES cae por debajo del umbral M1 (15%), revertar a v2.1 sin council.
Si se mantiene >= 15%, registrar nuevo bench en audit y continuar con v3.

Fuente: round_3_devils_advocate.yaml DA4 + round_1_researcher.yaml evidencia[5].

### 1.3 Tabla de costos empiricos -- simbolos del protocolo

Bench: cl100k_base + o200k_base, N=82 secuencias, tiktoken 0.12.0, 2026-05-07.

SIMBOLOS DE 1 TOKEN (nativo -- usar sin restriccion):

  Operadores direccionales:  ->   <-   =>   <>
  Agrupadores:               {    }    [    ]
  Aritmeticos/logicos:       +    *    |
  Puntuacion:                .    :    @    #    ~    !    ?    %    =    ;    ,    _
  Estados textuales:         ok   er
  Fusiones nativas (1t):     !.   ?.   !!   ??   ::   ..   --   ==   >>   <<

SIMBOLOS DE 2 TOKENS (usar con consciencia del costo):

  Letra_mayuscula + colon:   D:   S:   A:   (TODA letra + colon = 2t. Invariable.)
  @ + palabra:               @now(2t)  @next(2t)  @blk(2t)  @done(2t)
  IDs de 3+ chars:           ORC(2t)  TST(2t)  SKEPT(3t)  INNOV(3t)  SYNTH(3t)

HALLAZGO CENTRAL (Paso 2 -- fonetica del alien BPE): ninguna combinacion
letra_mayuscula+colon es 1 token en cl100k ni o200k. BPE aprendio estas secuencias como
unidades separadas. Este resultado es invariable con vocabulario per-session -- el
tokenizador es fijo en tiempo de inference.

Hallazgo derivado: 450 combinaciones de 2 caracteres ASCII de puntuacion son 1 token en
cl100k. Este conjunto es la "fonologia nativa" del alien BPE y el fundamento de v3.

AVISO DA4: la estabilidad del conjunto de 450 bigrams NO esta garantizada entre versiones
de tokenizador. Ver clausula de sunset (seccion 1.2).

### 1.4 Capacidades del hablante LLM

PUEDE (ventajas sobre humanos):
  - Leer 200K tokens de contexto en un prompt sin fatiga ni degradacion de precision.
  - Pattern-match estructura posicional perfectamente dado ejemplos consistentes.
  - Tolerar ruido menor y recuperar significado por contexto local.
  - Beneficiarse de prompt cache: tokens en posicion fija al inicio del system prompt
    tienen costo de lectura ~90% menor en reusos (escritura $3.75/M, lectura $0.30/M,
    tarifas Sonnet 3.5 publicadas -- verificar para modelo actual antes de calcular).

NO PUEDE de forma confiable:
  - Resolver ambiguedad de operadores sobrecargados sin regla explicita.
  - Mantener estado entre llamadas sin mecanismo explicito -- S:hash es la solucion.
  - Desambiguar cuando 2+ elementos de una linea son candidatos al mismo rol semantico.
  - Propagar env vars entre llamadas -- motivo por el cual el toggle v3 debe inyectarse
    como parametro explicito per-prompt (DA3-MIT, seccion 3).

### 1.5 Topologia y presion de lenguaje por capa

| Capa | Topologia | M tipico | Presion dominante |
|---|---|---|---|
| Capa 1 / subagent 1:1 | unicast, shot unico | 1-2 | Minima -- vocab opcional |
| Council (actual) | broadcast + round-based + sintetizador | 7-14 outputs | S:hash critico |
| Capa 2 swarm | N:N peer, paralelo | 10-30 handoffs | S:hash + IDs cortos criticos |
| Capa 3 Agent Teams (futuro) | hub-spoke | variable | Hub amplifica ahorro |

---

## 2. Gramatica v3

Cinco formas. La posicion de cada parte determina el significado. El colon como
"marcador de rol" fue eliminado donde la posicion ya provee esa informacion -- esa
es la diferencia central entre v2.1 y v3.

Racional por Paso 3 (gramatica): el alien BPE aprende posicion igual que aprende
sintaxis de cualquier lenguaje formal dado ejemplos suficientes en el system prompt.
Un marcador de rol explicito (`:`) que cuesta 1 token sin aportar informacion que la
posicion no da es un token desperdiciado.

### 2.1 Forma 1 -- Estado de agente

v2.1:  AGENTE:ESTADO.dominio
v3:    AGENTE ESTADO.dominio

Tabla de costos empiricos (cl100k_base, N=6, bench 2026-05-07):

  CASO              V2.1            t21   V3              t3   AHORRO
  simple ok         FE:ok            3    FE ok            2    +1t (33%)
  simple error      BE:er            3    BE er            2    +1t (33%)
  alerta+dominio    SK:!.perf        4    SK !.perf        4     0t (0%)
  progreso          FE:~%60.ui       6    FE ~60.ui        4    +2t (33%)
  bloqueado         DB:#             2    DB #             2     0t (0%)
  desconocido       RE:?             2    RE ?             2     0t (0%)

Nota sobre ahorro real (council CRUX-1): el 33% aplica a handoffs sinteticos puros.
El ROI sobre texto completo de council (incluyendo cuerpo analitico) es 10-23.6% segun
corpus. Fuente: round_2_synthesizer.yaml CRUX-1, round_1_researcher.yaml evidencia[0].

Regla de dominio: el dominio va pegado al estado con punto sin espacio.
  CORRECTO:   FE ~60.ui
  INCORRECTO: FE ~60 .ui    (espacio antes del punto rompe la fusion; .ui = 2t)

### 2.2 Forma 2 -- Mensaje entre agentes

v2.1:  FUENTE->DESTINO verbo:objeto.dominio
v3:    FUENTE->DESTINO objeto.dominio         (entrega -- default)
v3:    FUENTE->DESTINO ?objeto.dominio        (pregunta/solicitud -- prefijo ?)

El verbo es opcional. La direccion semantica esta en el operador. El prefijo `?` (1 token)
diferencia pregunta de entrega cuando la distincion importa, reemplazando `ask:` (2t) y
`need:` (2t).

Tabla de costos empiricos (cl100k_base, N=6, bench 2026-05-07):

  CASO              V2.1                           t21   V3                          t3   AHORRO
  entrega           BE->FE give:contract.api         7    BE->FE contract.api         5    +2t (29%)
  pregunta          FE->BE ask:schema.db             7    FE->BE ?schema.db           6    +1t (14%)
  necesita          FE->BE need:schema.db            7    FE->BE ?schema.db           6    +1t (14%)
  ejecuta           ORC->TST do:chk.payments        10    OC->TS chk.payments         6    +4t (40%)
  broadcast         ORC->FE+BE+DB start:pay S:v     13    OC->FE BE DB pay S:v        8    +5t (38%)
  fix               ORC->BE fix:auth.api             8    OC->BE fix auth.api         6    +2t (25%)

Regla de verbo explicito: si la ambiguedad entre entrega y pregunta es real en el
contexto, usar `?` como prefijo del objeto. Si no hay ambiguedad, omitir el verbo.
Los verbos de v2.1 (give, ask, fix, chk, done, wait, stop) siguen validos como opcionales.

Regla de broadcast: `OC->FE BE DB` reemplaza `ORC->FE+BE+DB`. Lista de destinos separada
por espacio. El `+` se reserva para cuando la ambiguedad sin el es real.

Regla de precedencia operador+verbo (preservada de v2.1 ADJ-2, bench linguista 20260507):
  FUENTE->DESTINO verbo:obj  -->  FUENTE consulta/envia a DESTINO sobre obj
  FUENTE<-ORIGEN  verbo:obj  -->  FUENTE solicita a ORIGEN que envie obj (ORIGEN pasivo)

### 2.3 Forma 3 -- Delta multiple

v2.1:  D:{AGENTE:ESTADO,AGENTE:ESTADO} @temporal
v3:    AGENTE ESTADO AGENTE ESTADO @temporal          (2-3 agentes, sin llaves)
v3:    [AGENTE ESTADO AGENTE ESTADO] @temporal        (4+ agentes, con llaves [])

El prefijo D: cuesta 2t (D+:). Las llaves {} cuestan 2t ({+}). Para 2-3 agentes,
la posicion es suficiente. Para 4+ agentes, las llaves [] (1t apertura + 1t cierre = 2t)
son el agrupador mas barato disponible.

Tabla de costos empiricos (cl100k_base, N=4, bench 2026-05-07):

  CASO              V2.1                                            t21   V3                                     t3   AHORRO
  2 agentes         D:{FE:~%60.ui,BE:ok.api} @now                   16    FE ~60.ui BE ok.api @now                9    +7t (44%)
  3 agentes         D:{FE:ok,BE:ok,DB:ok} @done                     15    FE ok BE ok DB ok @done                 8    +7t (47%)
  3 agentes+msg     D:{FE:ok,BE:ok,DB:ok}|ORC->TST do:chk.pay S:2  27    FE ok BE ok DB ok | OC->TS chk.pay S:2 16   +11t (41%)
  con bloqueo       D:{FE:ok,BE:#.auth} @blk                        13    FE ok BE #.auth @blk                    8    +5t (38%)

Regla de ambiguedad en deltas: si cualquier estado de la secuencia puede confundirse con
un operador o con el inicio de un mensaje, usar [] explicitamente. Hard constraint del
creator: si hay duda, las llaves se ponen. El ahorro de 2 tokens no vale la perdida de
contexto.

Riesgo DA1 (devil's advocate): en contextos de alta carga cognitiva (councils de
seguridad, arquitectura), los marcadores eliminados de v3 amplian la superficie de
ambiguedad vs v2.1. Si un agente parsea "SK !.sec[auth>session]" como aprobacion
cuando es rechazo, la decision de governance es incorrecta. La mitigacion es el piloto
N=2 con el Council B en dominio tecnico no-meta-circular, ejecutado ANTES del rollout
a los 7 prompts. Fuente: round_3_devils_advocate.yaml DA1.

### 2.4 Forma 4 -- Referencia a contexto por hash

Sin cambio vs v2.1.

  S:xxxx

Costo: 5 tokens (S=1 + :=1 + 4 chars del hash). No hay alternativa mas barata que
provea la misma funcion de referencia legible. El prefijo S: (2t) es el costo minimo
de cualquier prefijo ASCII de 1 letra + delimitador.

Generacion:
  bash ~/.helix/helpers/helix-lang-state.sh vocab "A:{...}" "D:{...}"

Breakeven empirico por tipo de sesion (cl100k_base, bench 2026-05-07):

  TIPO DE SESION             VOCAB(t)   HASH(t)   SAVE/MSG(t)   BREAKEVEN(msgs)
  small (4 agentes)            38         5          33           1.15
  council (8 roles)            71         5          66           1.08
  full (13 agentes+9 dominios) 106        5         101           1.05

En todos los casos el breakeven es < 2 mensajes. Para M >= 2 handoffs, S:hash ya se paga.

Instrumentacion del piloto (P7 council): durante los councils piloto medir SEPARADAMENTE
  (a) tokens ahorrados por gramatica v3 (Formas 1-3)
  (b) tokens ahorrados por S:hash refs vs vocab inline en cada mensaje
Fuente: round_3_synthesizer.yaml P7, round_1_innovator.yaml A2.

### 2.5 Forma 5 -- Composicion

Sin cambio vs v2.1.

  expr | expr | expr

El pipe es 1 token nativo (cl100k_base, bench 2026-05-07). Correcto y sin mejora posible.

---

## 3. Toggle de version -- mecanismo y propagacion

Fuente y autoridad: council 20260507T215307Z-109qf, P2 (toggle) + DA3-MIT (propagacion).

### 3.1 Mecanismo elegido

Env var: HELIX_LANG_VERSION=2.1|3.0

  Scope:       session-local (no persistente entre sesiones sin re-export explicito).
  Lector:      orchestrator helix-council.sh en fase pre-prep.
  Precedencia: env var > frontmatter del SKILL.md activo > default 2.1
  Default:     2.1 (estabilidad -- preserva momentum de evolution #84)

Alternativas rechazadas y razon:
  - SKILL frontmatter solo: no permite override sin tocar archivo.
  - settings.json hook: agrega complejidad de hook chain y riesgo de silenciamiento
    silencioso (evolution #81: hooks desaparecen cuando un proceso reescribe settings.json).
  - Tiered intensity (innovator A1): se auto-cancela por multiplicar la superficie de
    M3 subjetivo x3 (round_2_innovator.yaml, propio innovator lo derankeo en R2).

### 3.2 Propagacion por prompt -- DA3-MIT

CRITICO: la env var NO puede propagarse por herencia de shell entre agentes del council
porque cada llamada al LLM es stateless. Si el orchestrator setea HELIX_LANG_VERSION=3.0
en el entorno del proceso pero no lo inyecta explicitamente en cada prompt, los agentes
de rondas posteriores pueden recibir v2.1 (env no propagada en fresh shell) mientras los
de rondas anteriores usaron v3 -- fragmentacion de protocolo.

Evidencia: evolution #81 (settings.json se reescribe silenciosamente), evolution #80
(claude-flow silencia hooks sin warning). Patron documentado de perdida silenciosa de
configuracion.

IMPLEMENTACION REQUERIDA: el orchestrator helix-council.sh en la fase prepare DEBE
inyectar HELIX_LANG_VERSION como parametro explicito en el bloque de instrucciones de
cada prompt, en CADA ronda, independientemente del estado de la env var en ese momento.

Formato del bloque a inyectar (ASCII, en el system prompt de cada agente):

  PROTOCOL_VERSION: HELIX_LANG_VERSION=3.0
  (or PROTOCOL_VERSION: HELIX_LANG_VERSION=2.1)

Si este campo no esta presente en el prompt de un agente, el agente debe asumir v2.1.

### 3.3 Smoke test de rollback (requerido antes del piloto -- P2)

Procedimiento:
  1. export HELIX_LANG_VERSION=3.0
  2. Correr helix-council.sh prepare sobre un topic dummy de 1 linea.
  3. Verificar que todos los prompts generados contienen "PROTOCOL_VERSION: HELIX_LANG_VERSION=3.0".
  4. unset HELIX_LANG_VERSION
  5. Correr helix-council.sh prepare sobre el mismo topic.
  6. Verificar que todos los prompts contienen "PROTOCOL_VERSION: HELIX_LANG_VERSION=2.1".
  7. Verificar que el diff entre los dos prepare muestra exactamente: ejemplos v3 vs v2.1
     + el campo PROTOCOL_VERSION.
  8. Cronometrar el rollback manual: unset + git restore ~/.helix/council/prompts
     Debe completarse en < 3 minutos.

Resultado esperado: PASS en los 8 pasos. Si cualquiera falla, el piloto NO arranca.

---

## 4. Politica de activacion por idioma

Fuente: council 20260507T215307Z-109qf P4 (M5 language-aware activation policy).
Evidencia empirica: bench linguista-bench-20260507.yaml (cl100k_base, N=20 muestras
cross-lingual: 4 en EN, 5 en ES, 6 en ZH, 5 en JA).

### 4.1 Regla de activacion

| Idioma del council | v3 por default | ROI empirico cl100k | Accion |
|---|---|---|---|
| Espanol (ES) | ACTIVADO | +23.6% | Default on. Env var no requerida. |
| Chino / Japones (CJK) | ACTIVADO | +44-59% | Default on. Env var no requerida. |
| Ingles (EN) | DESACTIVADO | -3.5% (cuesta MAS) | Requiere opt-in explicito del creator. |
| Ambiguo / mixto | DESACTIVADO | sin datos | Default off por precaucion. |

Override manual: HELIX_LANG_V3_LANG_OVERRIDE=en|es|cjk|off
  Ejemplo: HELIX_LANG_V3_LANG_OVERRIDE=en activa v3 para un council EN (opt-in creator).

### 4.2 Mecanismo de deteccion de idioma

El orchestrator helix-council.sh debe clasificar el idioma del trigger antes de la fase
prepare. Algoritmo heuristico simple (DA2-MIT requiere que el mecanismo sea explicito):

  1. Contar caracteres en rango Unicode CJK (U+4E00 a U+9FFF, U+3040 a U+30FF): si > 5%
     del total de chars del trigger -> clasificar como CJK -> activar v3.
  2. Contar ratio ASCII vs no-ASCII en el trigger:
     si ratio_no_ascii > 0.15 (15%) y no es CJK -> asumir idioma no-EN -> activar v3.
     si ratio_no_ascii <= 0.15 -> clasificar como EN -> desactivar v3 por default.
  3. Si HELIX_LANG_V3_LANG_OVERRIDE esta seteado -> el override gana sobre la heuristica.

Fallback mixto (DA2-MIT): si el trigger clasifica como ES o CJK pero el contenido
tecnico del prompt contiene > 30% tokens ASCII de palabras inglesas (variable names,
function signatures, error messages fuera de strings), el orchestrator emite un aviso:

  [HELIX-LANG-MIXTO] Trigger clasificado como ES pero contenido tecnico >30% EN.
  Activando v2.1 para esta sesion. Override: HELIX_LANG_V3_LANG_OVERRIDE=es

El aviso se loguea pero no bloquea -- el creator puede ignorarlo o hacer override.

Limitacion declarada: la heuristica de ratio ASCII no distingue perfectamente entre
"texto ES con terminos tecnicos EN" y "texto EN". Los casos ambiguos caen a v2.1 por
precaucion. Fuente: round_3_devils_advocate.yaml DA2.

---

## 5. Modo hibrido lossless

### 5.1 Regla de cuándo declarar vocabulario

REGLA DURA: si M >= 3 handoffs en la sesion, declarar vocabulario al inicio. Si M < 3,
IDs auto-descriptivos son validos.

| Contexto | M esperado | Modo | Razon |
|---|---|---|---|
| Subagent call 1:1, tarea puntual | 1-2 | IDs descriptivos (v2.1 style) | Vocab cuesta mas de lo que ahorra |
| Council (7 roles, N rondas) | 7-14 | Vocab obligatorio | Breakeven 1.08 msgs; ahorro neto grande |
| Capa 2 swarm (N agentes) | 10-30 | Vocab obligatorio | S:hash mecanismo dominante |
| Capa 3 hub-spoke (futuro) | variable | Vocab en hub, propagado a spokes | Hub amplifica el ahorro |

### 5.2 Condicion de lossless

v3 es lossless condicionado: dado el vocabulario declarado en el contexto, toda expresion
v3 puede round-tripearse a su equivalente en lenguaje natural sin perdida semantica.
Sin vocabulario, los IDs de 2 chars (OC, SK, SY) son opacos.

Esta es una relajacion de lossless-sin-vocabulario-externo. No es relajacion de
lossless-dado-el-vocabulario. Flaggeado explicitamente segun la doctrina del agente.

Fallback de backward compat (P5): si el detector helix-lang-detect.sh encuentra IDs de
2 chars (SK, IN, CO) sin S:vocab declarado en el contexto disponible, debe intentar
parseo con regex v2.1 explicito antes de reportar ambiguedad. Smoke test requerido: 3
councils historicos parseados sin errores semanticos (incluido 20260507T051108Z-xgyps).

### 5.3 Formato de declaracion de vocabulario

Sin cambio vs v2.1:

  VOCAB:{A:{OC:orchestrator,SK:skeptic,IN:innovator,...},D:{.api:api,.sec:security,...}}

Plantillas actualizadas con IDs v3:

Software:
  A:{OC:orchestrator,FE:frontend,BE:backend,DB:database,TS:testing,IF:infra}
  D:{.ui:interface,.api:endpoints,.db:schema,.test:tests,.cfg:config,.sec:security}

Council:
  A:{OC:orchestrator,SK:skeptic,IN:innovator,CO:conservative,SY:synthesizer,RE:researcher,DV:devil,AB:arbiter}
  D:{.perf:performance,.sec:security,.api:api,.arch:architecture,.test:tests,.cost:cost}

---

## 6. Temporales duales

### 6.1 Forma keyword (default seguro, siempre valida)

  @now   urgente, inmediato          2t  (@ + now)
  @next  siguiente paso              2t  (@ + next)
  @blk   bloqueante                  2t  (@ + blk)
  @done  al completar X              2t  (@ + done)

Usar siempre que haya duda. El costo de 2t es el precio de la claridad.

### 6.2 Forma posicional (1t, solo cuando cumple ambas condiciones simultaneamente)

  !  al final de linea  urgente (equivalente a @now)     1t
  ;  al final de linea  siguiente paso (equiv. a @next)  1t
  ^  al final de linea  bloqueante (equivalente a @blk)  1t

Verificado: todos son 1 token en cl100k_base y o200k_base (bench 2026-05-07).

Condicion de seguridad -- AMBAS deben cumplirse:
  (a) El simbolo es el UNICO elemento final de la linea sin otro candidato posicional.
  (b) El contexto previo establece con claridad que la linea es un estado/handoff,
      no un estado de agente donde el simbolo podria ser el estado mismo.

Tabla de ambiguedad validada (bench 2026-05-07):

  CASO                          LINEA                      VEREDICTO
  SAFE: temporal unico final    FE ok BE ok !              ! = urgente (claro)
  SAFE: siguiente step unico    OC->TS chk.pay ;           ; = next (claro)
  AMBIG: doble candidato        FE ! BE ok                 PROHIBIDO: ! = alerta FE o temporal?
  AMBIG: estado vs temporal     FE ? BE ok                 PROHIBIDO: ? = FE desconocido o pregunta?

Ahorro del posicional: 1t por uso vs keyword. En un council de 14 rondas con temporal:
  14 * 1t = 14t = $0.000042 USD (Sonnet 4.6 input $3/M, proxy cl100k).
  Modesto. La decision de usar posicional vs keyword se basa en claridad, no en el
  ahorro de 1 token.

---

## 7. Inventario v3

### 7.1 IDs de agente (todos 1 token cl100k verificado, bench 2026-05-07)

Council (7 roles):

  ID v3   Rol               cl100k   o200k   ID v2.1   t21 vs t3
  OC      orchestrator       1        1       ORC        2 -> 1  (-1t)
  SK      skeptic            1        1       SKEPT      3 -> 1  (-2t)
  IN      innovator          1        1       INNOV      3 -> 1  (-2t)
  CO      conservative       1        1       CONS       1 -> 1  (0t)
  SY      synthesizer        1        1       SYNTH      3 -> 1  (-2t)
  RE      researcher         1        1       RES        1 -> 1  (0t)
  DV      devil (d-advocate) 1        1       DEVIL      2 -> 1  (-1t)
  AB      arbiter            1        1       ARB        1 -> 1  (0t)

Software (Capa 2 tipico):

  ID v3   Rol          cl100k   o200k   ID v2.1   t21 vs t3
  FE      frontend      1        1       FE         1 -> 1  (0t)
  BE      backend       1        1       BE         1 -> 1  (0t)
  DB      database      1        1       DB         1 -> 1  (0t)
  TS      testing       1        1       TST        2 -> 1  (-1t)
  IF      infra         1        1       INF        1 -> 1  (0t)
  OC      orchestrator  1        1       ORC        2 -> 1  (-1t)

Ahorro por ronda de council completa (todos los roles, 2 menciones c/u):
  v2.1: 44 tokens totales (13 IDs x2). v3: 26 tokens totales.
  Ahorro: 18 tokens por ronda. Fuente: bench 2026-05-07, N=13 IDs x2 menciones.

Colision de IDs: ninguna colision en el inventario de council (7 roles, IDs unicos).
  Para dominios con colision potencial, declarar vocabulario S:vocab explicitamente.

### 7.2 Estados universales (sin cambio en simbolos)

  ok    completado, sin errores   1t
  er    error, fallo              1t
  !     alerta                    1t
  ?     desconocido, pendiente    1t
  ~     en progreso               1t
  ~N    N% completado             2t  (~ + digito 0-9)
  #     bloqueado                 1t

### 7.3 Operadores (sin cambio)

  ->    envia a / asigna a           1t
  <-    recibe de / espera de        1t
  =>    transforma en / produce      1t
  <>    intercambio bidireccional    1t
  +     y / conjunto (cuando lista por espacio es ambigua)  1t
  |     separador de expresiones     1t
  *     todos / broadcast            1t

### 7.4 Verbos (opcionales en v3)

Los verbos de v2.1 siguen validos. Son opcionales cuando el operador + posicion ya
comunican la accion. El prefijo `?` (1t) reemplaza `ask:` (2t) y `need:` (2t).

  give    entrega     1t   (opcional si -> y contexto claro)
  ?       pregunta    1t   (prefijo de objeto, reemplaza ask: y need:)
  fix     corrige     1t   (util cuando la accion es reparacion)
  chk     verifica    1t   (util para comandos de validacion)
  done    declara fin 1t   (confirmacion explicita)
  wait    espera      1t
  stop    cancela     1t

---

## 8. Ejemplos comparativos

### Ejemplo 1 -- Estado simple (Forma 1)

  v2.1: FE:ok.ui                       3t
  v3:   FE ok.ui                        2t   ahorro 1t (33%)

### Ejemplo 2 -- Mensaje con entrega (Forma 2)

  v2.1: BE->FE give:contract.api        7t
  v3:   BE->FE contract.api             5t   ahorro 2t (29%)

### Ejemplo 3 -- Delta 3 agentes + handoff (Formas 3 + 2)

  v2.1: D:{FE:ok,BE:ok,DB:ok} | ORC->TST do:chk.payments S:2   27t
  v3:   FE ok BE ok DB ok | OC->TS chk.payments S:2             16t   ahorro 11t (41%)

### Ejemplo 4 -- Alert de council (Forma 1 + anotacion)

  v2.1: SKEPT:!.perf[latency>200ms]    13t
  v3:   SK !.perf[lat>200ms]            9t (estimado)   ahorro ~4t (~30%)

  Nota: !. es fusion nativa de 1 token en cl100k (bench 2026-05-07).

### Ejemplo 5 -- Modo hibrido CON vocab declarado (Council -- M >= 3)

Inicio de sesion:
  VOCAB:{A:{OC:orchestrator,SK:skeptic,IN:innovator,CO:conservative,SY:synthesizer,RE:researcher,DV:devil,AB:arbiter},D:{.perf:performance,.arch:architecture,.cost:cost}}
  --> S:c9a1

Ronda 1 (todos los agentes conocen S:c9a1):
  SK:!.arch[complejidad>umbral] | SK->SY give:concerns.arch S:c9a1
  IN ok.arch | IN->OC give:alternatives.arch

Ronda 2 (S:c9a1 no se retransmite):
  CO:? cost | CO->SK ask:evidence.cost
  SY: IN ok.arch SK !.arch[3.mitigaciones] | SY->OC give:synthesis @now

El vocabulario (71 tokens) se transmite una vez y ahorra 66t por mensaje subsiguiente.
Breakeven: 1.08 mensajes (bench 2026-05-07).

### Ejemplo 6 -- Modo hibrido SIN vocab (Subagent 1:1 -- M < 3)

Caso: Claude principal invoca un subagente para revisar autenticacion. M=1.

  BE->OC er.api[auth:401 en /retiros] @now

FE, BE, OC son auto-descriptivos (1 token c/u, conocidos en el corpus de entrenamiento).
No hay necesidad de vocab declarado. El receptor entiende BE como backend por contexto.

---

## 9. Anti-patterns

Los siguientes "ahorros" violan el hard constraint del creator y deben rechazarse.

### AP-1: Temporal posicional cuando hay 2+ candidatos

INCORRECTO: FE ! BE ok
  El receptor no puede saber si ! es el estado de FE o el temporal urgente.
CORRECTO:   FE ! BE ok @now
  @now (2t extra) compra desambiguacion. Obligatorio en caso de doble candidato.

### AP-2: IDs de 2 chars sin vocab en sesiones M >= 3

INCORRECTO: usar SK, IN, SY en un council sin S:vocab declarado.
  Agentes externos al council (ej: memory/agents/*.md) no pueden desambiguar.
CORRECTO: declarar S:vocab al inicio. Breakeven: 1.08 mensajes. Siempre vale en council.

### AP-3: Omitir `?` cuando ask y give son ambiguos

INCORRECTO: FE->BE schema.db (cuando no es obvio si FE entrega o pide)
CORRECTO:   FE->BE ?schema.db (pide) | FE->BE schema.db (entrega -- solo si el contexto
  lo hace obvio)
Regla operativa: si un humano tardaria 1 segundo en determinar si es pregunta o entrega,
agregar `?`. El LLM receptor tampoco deberia tener que inferirlo.

### AP-4: Deltas de 4+ agentes sin llaves

INCORRECTO: FE ok BE ok DB ok TS ok IF ok @done
  Con 5 agentes en linea, la frontera AGENTE/ESTADO se vuelve ambigua especialmente si
  algun estado es un simbolo (! ? ~) que podria leerse como ID.
CORRECTO:   [FE ok BE ok DB ok TS ok IF ok] @done
  Las llaves cuestan 2t. La claridad vale esos 2t. (DA1, devil's advocate)

### AP-5: Verbos con colon cuando el verbo es opcional

INCORRECTO: BE->FE give:contract.api   (give:=2t, -> ya comunica entrega)
CORRECTO:   BE->FE contract.api         (5t vs 7t)
Excepcion: fix, chk, stop agregan semantica que el operador no da. Usarlos sin colon:
  OC->BE fix auth.api  (no OC->BE fix:auth.api)

### AP-6: Activar v3 en councils EN sin opt-in explicito

INCORRECTO: correr un council en ingles con HELIX_LANG_VERSION=3.0 sin override.
  v3 cuesta -3.5% en EN (cuesta MAS que v2.1). Fuente: bench 2026-05-07, cl100k, N=4.
CORRECTO: EN councils usan v2.1 por default. Para forzar v3 en EN:
  HELIX_LANG_V3_LANG_OVERRIDE=en (opt-in explicito del creator).

### AP-7: Rollout parcial de los 7 system prompts (DA5-MIT)

INCORRECTO: actualizar 3 de 7 prompts a v3 y dejar 4 en v2.1.
  Un agente con prompts v2.1 recibiendo handoffs v3 puede parsear "SK !.sec[auth>session]"
  como aprobacion cuando es rechazo -- fallo de governance, potencialmente irreversible.
  Fuente: round_3_devils_advocate.yaml DA5.
CORRECTO: el rollout es ATOMICO. Los 7 prompts se actualizan simultaneamente o ninguno.
  El script de rollout debe verificar atomicidad antes de modificar cualquier archivo.

### AP-8: HELIX-LANG en output user-facing

NUNCA. El protocolo es estrictamente inter-agente. El finalize del council traduce a
lenguaje natural en el idioma del usuario. Si el creator pide ver el output crudo,
mostrarlo en modo debug opt-in explicito.

---

## 10. Gate M3 -- mecanismo de bloqueo (DA6-MIT)

Fuente: round_3_devils_advocate.yaml DA6. Consenso: 4 de 5 roles flaggearon M3 como
el constraint mas fragil del piloto (round_2_synthesizer.yaml CRUX-4).

IMPLEMENTACION: helix-council.sh finalize honra la env var HELIX_M3_GATE=1.

Antes de registrar PASS en el audit log del piloto, el orchestrator emite:

  === M3 BLOCKING GATE -- manual confirmation required ===
  user_facing_summary from synthesizer R3:
  ---
  <summary completo>
  ---
  Rubric: ~/.helix/skills/helix-lang/m3-rubric.md
  Type PASS or FAIL followed by Enter:
  >

El orchestrator espera input del creator. Si el input es FAIL:
  - decision se override a REJECTED.
  - escalation_reason: "M3 manual gate FAIL -- creator confirmed clarity loss"
  - Audit log registra m3_gate.confirmation: FAIL.

Si el input es PASS:
  - Audit log registra m3_gate.confirmation: PASS junto con la cita del PASS-N reference.

El gate aplica SOLO al piloto v3 (cuando HELIX_M3_GATE=1 explicitamente). Los councils
normales no tienen este gate.

Rubrica pre-registrada (P1 -- archivo):

  ~/.helix/skills/helix-lang/m3-rubric.md

  La rubrica debe incluir antes de iniciar el piloto:
  - >= 3 ejemplos de PASS (con explicacion de por que pasa)
  - >= 3 ejemplos de FAIL (con explicacion de por que falla)
  - 2 ejemplos en EN y 2 en ES (control de idioma)
  - Definicion operativa de FAIL: "creator necesita re-leer un handoff >1 vez O hacer
    >2 lookups al vocab declarado para entender el handoff"
  - Definicion operativa de PASS: "< 2 iteraciones de debug durante el round 1"

La rubrica se escribe antes de ver los outputs del piloto. Su existencia es la P1
del council y su ausencia bloquea el inicio del piloto.

---

## 11. Plan de piloto N=2

Fuente: council 20260507T215307Z-109qf, P6 + synthesis round_3.

### 11.1 Pre-requisitos (todos bloqueantes antes de arrancar)

  P1: Rubrica M3 escrita y firmada por creator (ver seccion 10).
  P2: Smoke test de rollback completado (seccion 3.3).
  P4/M5: Politica de idioma documentada y verificada (seccion 4).
  P5: Detector helix-lang-detect.sh parsea 3 councils v2.1 historicos sin errores.
  P7: Instrumentacion de tokens split por mecanismo (gramatica vs S:hash) lista.
  Backup: cp -r ~/.helix/council/prompts ~/.helix/council/prompts.bak-pre-v3-pilot

### 11.2 Council A (gate para Council B)

  Tema: Politica de backup automatico de SKILL.md antes de rollout de cualquier v3.
  Razon: autocontenido, sin meta-circularidad, caso favorable sin sesgo de confirmacion.
  Idioma: ES (ROI positivo +23.6%). Control de idioma documentado.
  Gate: si M1 < 15% O M2 < 70% O M3 = FAIL -> ABORT, no ejecutar Council B.

### 11.3 Council B (solo si A pasa todas las M)

  Tema: Politica de retencion de logs de audit Helix (HSL v1).
  Razon: dominio tecnico externo (security/operabilidad), terminologia externa al protocolo.
  Idioma: ES (consistente con A).
  Gate: si B falla pese a A pasar -> senial de no-generalizacion -> council reconviene.

### 11.4 Metricas del piloto

M1 -- Ahorro de tokens:
  Threshold: >= 15% sobre texto completo del council (incluyendo cuerpo analitico).
  Medicion: cl100k_base + o200k_base (ambos reportados).
  Gap declarado: tokenizador Anthropic real no medido (P3 creator).
  Pass: mediana de 2 councils >= 15%, ningun council individual < 10%.

M2 -- Adopcion por agente:
  Threshold: >= 70% lineas v3-compliant en output de cada agente, en cada ronda.
  Medicion: helix-lang-detect.sh modo v3 (extendido para patrones v3).
  Pass: >= 70% en round 1 de council A; si < 70% en R1, abort sin esperar R2.

M3 -- Claridad del finalize:
  Threshold: rubrica P1 (PASS/FAIL binario por handoff).
  Medicion: creator anota cada handoff intra-rondas + finalize (NO solo el final).
  Pass: >= 80% handoffs marcados PASS en cada ronda incluyendo finalize.
  Hard constraint: M3 FAIL -> piloto FAIL aunque M1+M2 pasen. Sin excepciones.
  Gate mecanico: seccion 10.

M4 -- Backward compat:
  Threshold: 100% de councils v2.1 historicos parseables sin errores semanticos.
  Medicion: smoke test pre-piloto + re-run post-council A.

M5 -- Politica de idioma:
  Threshold: activacion correcta segun seccion 4. EN no activa v3 sin opt-in.

S:hash add-on (P7):
  Medir separadamente durante los mismos councils: tokens de gramatica vs tokens de S:hash.
  No es bloqueante del inicio del piloto.

### 11.5 Rollback si el piloto falla

  git restore ~/.helix/council/prompts/
  unset HELIX_LANG_VERSION
  Mantener este DRAFT con nota de resultado al inicio.
  Retro con datos del piloto: cual M fallo, en que agentes, con que ejemplos.

### 11.6 Criterios de exit hacia rollout

  Council A pasa M1+M2+M3+M4+M5.
  Council B pasa M1+M2+M3+M4+M5.
  Diagnostics report publicado.
  Council reconviene SOLO si B falla pese a A pasar.

Estimado de tiempo: ~75 minutos de creator (council 20260507T215307Z-109qf, P6
compromise_note). Rollback en < 3 minutos si falla.

---

## 12. Reversibilidad

v2.1 (SKILL.md) no se toca. Para rollout formal cuando el piloto pase:

  1. Backup:
     cp ~/.helix/skills/helix-lang/SKILL.md ~/.helix/skills/helix-lang/SKILL.md.bak-v2.1

  2. Kill switch de version:
     HELIX_LANG_VERSION=2.1  -->  fuerza v2.1 aunque el frontmatter del SKILL activo sea 3.0
     HELIX_LANG_VERSION=3.0  -->  activa v3 (requiere piloto completado)
     unset                   -->  default 2.1

  3. Revertir system prompts: git restore ~/.helix/council/prompts/
     Timeline documentado en smoke test (seccion 3.3): < 3 minutos.

  4. Este DRAFT no afecta produccion. Es documentacion. Su existencia no activa
     ningun comportamiento hasta que helix-council.sh prepare lo referencie
     explicitamente mediante HELIX_LANG_VERSION=3.0.

---

## 13. Fuentes

  - Petrov, La Malfa, Torr, Bibi (2023). Language Model Tokenizers Introduce Unfairness
    Between Languages. NeurIPS 2023, arXiv:2305.15425.
  - Sennrich, Haddow, Birch (2016). Neural Machine Translation of Rare Words with
    Subword Units. arXiv:1508.07909.
  - Kudo, Richardson (2018). SentencePiece: A simple and language independent subword
    tokenizer and detokenizer for NLP. arXiv:1808.06226.
  - OpenAI tiktoken github.com/openai/tiktoken (cl100k_base, o200k_base).
  - Anthropic glossary: "exact number can vary depending on the language used".
  - Bench principal: linguista-computacional-tokens, 2026-05-07.
    ~/.helix/memory/audit/linguista-bench-20260507.yaml
  - Bench v3: tiktoken 0.12.0, cl100k_base + o200k_base, N=14 lineas reales + 82
    secuencias de protocolo. Fecha: 2026-05-07.
  - Council authority: 20260507T215307Z-109qf (GO_WITH_PRECONDITIONS).
    ~/.helix/council/log/20260507T221107Z_20260507T215307Z-109qf.yaml (chmod 400).
  - Infoprimates. 5 pasos para crear un idioma. Video ~13 min, ES.
    Paso 1: anatomia del hablante determina todo lo demas.
