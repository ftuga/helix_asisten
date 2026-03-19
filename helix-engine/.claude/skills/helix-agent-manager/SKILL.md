---
name: helix-agent-manager
description: Busca, compara e instala agentes desde aitmpl.com (davila7/claude-code-templates). Usar cuando Helix no tenga un agente para una tarea, o para validar si un agente local está desactualizado.
triggers:
  - "no tengo un agente para"
  - "¿existe un agente que"
  - "busca agente para"
  - "actualizar agente"
  - "validar agente"
  - "mejorar agente"
---

# Helix Agent Manager

Skill para gestionar agentes dinámicamente desde el registro de aitmpl.com.

## Fuentes de agentes

| Fuente | URL | Cuándo usar |
|--------|-----|-------------|
| **aitmpl.com** (comunidad) | `github.com/davila7/claude-code-templates` | Agentes generales, dominios variados |
| **RuFlo** (motor) | `github.com/ruvnet/ruflo` | Agentes de swarm, consenso, v3 |
| **Local** (proyecto) | `.claude/agents/` | Agentes personalizados del proyecto |

## Estructura del registro aitmpl

Los agentes están en `cli-tool/components/agents/` organizados por categoría:

| Categoría | Agentes |
|-----------|---------|
| `ai-specialists/` | prompt-engineer, llm-architect, model-evaluator, search-specialist |
| `api-graphql/` | api-architect, graphql-architect, shopify-expert |
| `blockchain-web3/` | smart-contract-auditor, web3-integration-specialist |
| `business-marketing/` | legal-advisor, product-strategist, scrum-master, ux-researcher |
| `data-ai/` | data-scientist, ml-engineer, computer-vision-engineer, mlops-engineer |
| `database/` | supabase-schema-architect, postgres-pro, nosql-specialist |
| `deep-research-team/` | research-coordinator, research-synthesizer, fact-checker |
| `development-team/` | backend-architect, fullstack-developer, ios-developer |
| `development-tools/` | error-detective, debugger, qa-expert, chaos-engineer, performance-profiler |
| `devops-infrastructure/` | kubernetes-specialist, terraform-engineer, azure-infra-engineer, sre-engineer |
| `documentation/` | diagram-architect, changelog-generator, technical-writer |
| `expert-advisors/` | critical-thinking, custom-agent-foundry, dependency-manager |

## Protocolo de uso (cómo ejecutar este skill)

### 1. BUSCAR un agente que no tengo

```
Necesito un agente para [tarea]. Busca en aitmpl.com.
```

**Helix ejecuta:**
1. Buscar en `https://raw.githubusercontent.com/davila7/claude-code-templates/main/cli-tool/components/agents/<categoria>/<nombre>.md`
2. Evaluar si el agente cubre la tarea
3. Mostrar el contenido y preguntar si instalar

### 2. COMPARAR agente local vs aitmpl

```
Compara mi agente [nombre] con la versión de aitmpl.com
```

**Helix ejecuta:**
1. Leer agente local: `cat .claude/agents/**/<nombre>.md` o `~/.claude/agents/<nombre>.md`
2. Fetch del agente remoto en aitmpl
3. Comparar: capacidades nuevas, diferencias de system prompt, triggers
4. Recomendar actualizar o no, con justificación

### 3. INSTALAR agente desde aitmpl

```
Instala el agente [nombre] de aitmpl en este proyecto / en global
```

**Helix ejecuta:**
```bash
# Fetch del contenido
AGENT_URL="https://raw.githubusercontent.com/davila7/claude-code-templates/main/cli-tool/components/agents/<categoria>/<nombre>.md"
AGENT_CONTENT=$(curl -fsSL "$AGENT_URL")

# Instalar en proyecto (por defecto) o global
DEST="${PROJECT}/.claude/agents/custom/<nombre>.md"  # proyecto
# DEST="$HOME/.claude/agents/<nombre>.md"            # global con --global

echo "$AGENT_CONTENT" > "$DEST"
```

### 4. LISTAR agentes disponibles por categoría

```
Lista los agentes de aitmpl en la categoría devops-infrastructure
```

**Helix ejecuta:**
```bash
# API de GitHub para listar archivos de una categoría
curl -s "https://api.github.com/repos/davila7/claude-code-templates/contents/cli-tool/components/agents/<categoria>" \
  | python3 -c "import sys,json; [print(f['name'].replace('.md','')) for f in json.load(sys.stdin) if f['name'].endswith('.md')]"
```

## Criterios de comparación agente local vs remoto

Al comparar, evaluar estos aspectos:

1. **Cobertura** — ¿El remoto cubre casos que el local no maneja?
2. **Instrucciones** — ¿Tiene un system prompt más específico o mejor estructurado?
3. **Herramientas** — ¿Referencia herramientas/MCPs que el local no usa?
4. **Actualización** — ¿La fecha del remoto es más reciente?
5. **Especialización** — ¿El local está personalizado para este proyecto? → Preferir local si es mejor

**Regla de decisión:**
- Remoto tiene +30% más capacidades → Actualizar (mergear, no reemplazar)
- Remoto igual o inferior → Mantener local
- Local tiene customización del proyecto → Merge selectivo, no sobreescribir

## Instalación permanente del skill

Este skill ya está activo en cualquier proyecto con helix-engine inyectado.
Para usarlo en global: está en `~/.claude/skills/helix-agent-manager/SKILL.md`
