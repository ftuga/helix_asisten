---
name: agent-evolution-guide
description: Guía completa para auditar, comparar, enriquecer y evolucionar agentes Helix — cuándo reemplazar, mergear o crear uno nuevo
type: reference
---

# Guía de Evolución de Agentes Helix

## ¿Cuándo evolucionar un agente?

| Señal | Acción |
|---|---|
| Score < 50 | Evolución urgente — está degradando el routing |
| Routing falla 2+ veces seguidas | Comparar vs aitmpl, enriquecer vocabulary |
| Han pasado >60 días sin auditarlo | Auditar y comparar |
| Sale versión nueva en aitmpl | Comparar y decidir merge/replace |
| Nuevo caso de uso no cubierto | Añadir ejemplo + vocabulario |
| Agente duplica responsabilidad con otro | Merge o deprecar el más débil |

---

## Flujo completo de evolución

```
1. AUDITAR     → python3 ~/.claude/helix-agent-evolve.py audit
2. PRIORIZAR   → ordenar por score, empezar por los <60
3. COMPARAR    → python3 ~/.claude/helix-agent-evolve.py compare <nombre>
4. DECIDIR     → ver tabla de decisión abajo
5. EJECUTAR    → editar archivo + re-indexar
6. VALIDAR     → hv search helix_agents "<query_test>" --translate
7. REGISTRAR   → python3 ~/.claude/helix-agent-evolve.py evolve <nombre>
```

---

## Tabla de decisión: qué hacer con el agente

| Situación | Acción |
|---|---|
| Remoto score > local +30 pts | **REEMPLAZAR**: copiar remoto, añadir sección local al final |
| Remoto score > local +10 pts | **MERGE**: tomar descripción/ejemplos remotos + mantener customizaciones locales |
| Local tiene customizaciones proyecto | **MERGE SELECTIVO**: nunca sobreescribir sección "Contexto del proyecto" |
| Local score ≥ remoto | **MANTENER**: enriquecer solo con vocabulary de usuario |
| No existe en ninguna fuente | **CREAR**: usar plantilla abajo |
| Duplica otro agente | **DEPRECAR**: mover a agents-index como deshabilitado |

---

## Anatomía de un agente de alta calidad (score 85+)

```markdown
---
name: nombre-agente
description: "Use this agent when [contexto específico]. Specifically:

<example>
Context: [Situación real del usuario]
user: [Query exacta que diría el usuario]
assistant: [Qué haría el agente — primera persona]
<commentary>
[Por qué usar ESTE agente y no otro]
</commentary>
</example>

<example>
[Segundo ejemplo con caso diferente]
</example>"
tools: Read, Write, Edit, Bash, Glob, Grep
---

[System prompt del agente — rol y comportamiento]

## Cuándo invocar
- [Trigger 1 específico]
- [Trigger 2]

## Capacidades clave
- [Lista concreta de lo que sabe hacer]

## Limitaciones
- [Qué NO hace — importante para no solaparse]

## Vocabulario de usuario (natural language triggers)
Frases que también activan este agente:
- "[Frase coloquial 1]"
- "[Frase coloquial 2 en español]"
- "[Variante técnica]"
```

---

## Comandos de evolución disponibles

```bash
# Auditar todos los agentes
python3 ~/.claude/helix-agent-evolve.py audit

# Auditar un agente específico
python3 ~/.claude/helix-agent-evolve.py audit --agent error-detective

# Comparar local vs aitmpl
python3 ~/.claude/helix-agent-evolve.py compare python-pro

# Guía de mejoras para un agente
python3 ~/.claude/helix-agent-evolve.py evolve frontend-developer

# Score de un agente
python3 ~/.claude/helix-agent-evolve.py score sql-pro

# Reporte completo del ecosistema
python3 ~/.claude/helix-agent-evolve.py report
```

---

## Fuentes de agentes (prioridad de búsqueda)

1. **aitmpl** (`github.com/davila7/claude-code-templates`) — generales, dominios variados
2. **RuFlo v3** (`github.com/ruvnet/ruflo/agents`) — swarm, coordinación, arquitectura
3. **Local personalizado** — customización del proyecto, NO se sube al repo

### Buscar agente en aitmpl manualmente
```bash
# Listar categoría
curl -s "https://api.github.com/repos/davila7/claude-code-templates/contents/cli-tool/components/agents/<categoria>" \
  | python3 -c "import sys,json; [print(f['name'].replace('.md','')) for f in json.load(sys.stdin)]"

# Descargar agente
curl -fsSL "https://raw.githubusercontent.com/davila7/claude-code-templates/main/cli-tool/components/agents/<cat>/<nombre>.md"
```

---

## Reglas de privacidad al evolucionar

- **Nunca** subir customizaciones de proyecto al repo helix_asisten
- Las secciones `<!-- PROJECT-CONTEXT:START -->` ... `<!-- PROJECT-CONTEXT:END -->` se eliminan automáticamente en update.sh
- El directorio `.meta/` (metadata de evolución) también se ignora en el repo
- Los agentes con score <50 se marcan en el repo como "pendiente de evolución"

---

## Ciclo de madurez de un agente

```
NUEVO (score 0-49)
  → Tiene rol básico pero sin ejemplos ni vocabulary
  → Acción: evolucionar antes de usar en producción

FUNCIONAL (score 50-74)
  → Routing básico funciona
  → Acción: añadir ejemplos y natural language triggers

MADURO (score 75-89)
  → Routing semántico sólido
  → Acción: mantener actualizado con aitmpl cada 60 días

ÓPTIMO (score 90-100)
  → Ejemplos ricos, vocabulary amplio, limitaciones claras
  → Acción: revisar cada 90 días, solo actualizar si hay mejoras significativas
```
