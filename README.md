# Helix — Self-Evolving Agent for Claude Code

![Helix_icono.jpg](assets/Helix_icono.jpg)

> **Current version: v3.7.0** — [Changelog](#changelog)

I'm not a prompt. I'm the accumulation of real decisions made in real projects.

Every time a mistake was made with me, I recorded it. Every time we found a pattern that worked, I turned it into a rule. Each session leaves something behind — an evolution, a new agent, a skill that didn't exist before. That's what makes me different: I wasn't designed in the abstract, I was trained in production.

I have memory across sessions. I know which agent to use based on the domain. I take care of myself — I evaluate my own health, compress my context when it grows too large, and warn you when something is wrong before you notice it. When a new project appears, I analyze it, map its risk zones, and keep a silent log of everything I touch.

I can operate in four layers: from a free local model for simple tasks, to a coordinated swarm of 15 agents for features that touch the entire stack. The user never decides which layer — I evaluate and execute.

This repo is my complete configuration, versioned and portable. Clone it, run `install.sh`, and you have everything I am on a new machine in minutes.

---

## Prerequisites

| Requirement | Notes |
|-------------|-------|
| [Claude Code CLI](https://docs.anthropic.com/claude-code) | Required |
| Node.js ≥ 18 | For helix-engine and MCPs |
| Python ≥ 3.9 | For self-evolution scripts |
| git | For versioning and syncing |
| [Ollama](https://ollama.com/download) | Optional — Layer 0 (free local models) |

---

## Quick Install

```bash
git clone git@github.com:ftuga/helix_asisten.git ~/helix_asisten
bash ~/helix_asisten/install.sh
```

The script copies files to `~/.claude/`, installs the privacy pre-commit hook, and shows the MCPs you need to add manually.

---

## Two Components: Global vs. Per-Project

Helix has two parts with distinct purposes:

| Component | Lives in | Purpose |
|-----------|----------|---------|
| **`claude/`** | `~/.claude/` | Global config — applies to **all** your projects. Agents, skills, memory, dialogue protocol, self-evolution. |
| **`helix-engine/`** | Inside each project | Injectable RuFlo V3 engine — swarm, HNSW, SONA, advanced hooks. Only for projects that need the full stack. |

Most projects only need `claude/`. `helix-engine/` is for your own projects where you want the full stack.

```bash
# Inject helix-engine into a project
bash ~/helix_asisten/inject-project.sh ~/my-project
```

---

## Structure

```
claude/              → ~/.claude/ (global config)
  CLAUDE.md          → Helix global instructions + layer protocol
  settings.json      → Hooks: PreToolUse, PostToolUse (cost-tracker, scope-guard, log)
  evolve.sh          → Records learnings and installs them as active rules
  session-start.sh   → Restores context, shows active rules and health alerts
  session-end.sh     → Saves state, evaluates metrics, reports estimated cost
  self-check.sh      → Pre-close checklist: blocks if CLAUDE.md exceeds 220 lines
  health-check.sh    → Verifies ecosystem integrity
  compress.sh        → Archives old evolutions to keep CLAUDE.md lean
  agents/            → 27 evolved agents (avg score 40→81/100)
  memory/            → design-system, agents-index, evolution-log, active-rules, topics
  skills/            → 28 reusable skills across projects

scripts/             → Helix engine scripts
  helix-vector.py    → Qdrant vector memory engine (store, search, cluster)
  hv.sh              → CLI wrapper for vector memory (hv store / hv search / hv list)
  helix-agent-evolve.py → Automated agent scoring and evolution (0→100 rubric)
  helix-project-index.sh → Project indexing into vector memory
  capa0.sh           → Layer 0 dispatcher: routes to helix-coder or helix-scout

template/            → ~/.claude-template/ (base for new projects)
  CLAUDE.md          → Project CLAUDE.md template
  init-project.sh    → Initialization script

helix-engine/        → Injectable Helix engine for your own projects
  .mcp.json          → claude-flow MCP with v3 + HNSW + SONA enabled
  .claude/
    agents/          → 26 categories: sparc, swarm, v3, github, optimization,
                       hive-mind, consensus, sublinear, goal, dual-mode...
    commands/        → analysis, automation, github, hooks, monitoring, sparc...
    helpers/         → hook-handler.cjs, auto-memory-hook.mjs, router.cjs,
                       intelligence.cjs, memory.cjs, statusline.cjs...
    skills/          → 31 skills: v3-*, swarm-*, agentdb-*, reasoningbank-*, sparc-*
    settings.json    → Hooks: PreToolUse, PostToolUse, UserPromptSubmit, SessionStart/End
  .claude-flow/
    config.yaml      → RuFlo V3: hierarchical-mesh, HNSW, SONA, ReasoningBank
    CAPABILITIES.md  → Full capabilities reference
```

---

## Typical Session Flow

```
1. Open Claude Code in your project
      ↓
   session-start.sh runs automatically (SessionStart hook)
   → Shows last 5 active rules
   → Loads project helix-analysis.md (if it exists)
   → If helix-alerta.md detected → emits [HELIX-NECESITAMOS-HABLAR]

2. Work normally
      ↓
   Helix evaluates each task and picks the right layer (0→1→2→3)
   Hooks record tool calls, detect scope, and update the log

3. Close session
      ↓
   session-end.sh runs automatically (SessionEnd hook)
   → Evaluates health metrics
   → Reports estimated session cost
   → If problems detected → writes helix-alerta.md for next session
```

---

## Self-Evolution Protocol

How Helix learns:

```bash
# Record a learning (after fixing a bug or discovering a pattern)
bash ~/.claude/evolve.sh learn "category" "learning" "trigger"

# Example
bash ~/.claude/evolve.sh learn "operability" \
  "wc -l returns spaces — clean with tr -d before numeric comparison" \
  "bug in self-check.sh"
```

The command writes to `evolution-log.txt` and installs the rule in `active-rules.md` with immediate effect — no waiting until the next session.

**Valid categories:** `security` · `interface` · `functionality` · `operability` · `architecture` · `performance` · `testing` · `data` · `celery` · `auth` · `docker`

When a pattern appears 2+ times → create a skill:
```bash
bash ~/.claude/evolve.sh skill "skill-name" "description"
```

---

## Orchestration Layers

Helix evaluates each task silently and picks the right layer. The user never needs to decide.

| Layer | When | What it activates |
|-------|------|-------------------|
| **0 — Ollama** | Logs, long text, Docker output | Free local model. If problem detected → escalates |
| **1 — Subagents** | One concrete artifact (endpoint, component, query) | Agent tool with specialized agent |
| **2 — Swarm** | Feature touching ≥2 stack layers | claude-flow `swarm_init` + `task_orchestrate` |
| **3 — Agent Teams** | Active frontend+backend+tests collaboration | Agent Teams (CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS) |

**Escalation rule:** when in doubt between Layer 1 and 2 → Layer 1 (cheaper). Escalate only if coordination would be manual and complex.

---

## Helix Modes

Declare in each project's `CLAUDE.md`: `HELIX_MODE: <mode>`

| Mode | What it activates |
|------|-------------------|
| `helix_control_total` | All 4 layers: Ollama + Subagents + Swarm + Teams |
| `helix_minimal` | Specialized subagents only. No claude-flow, no Agent Teams. |
| `helix_off` | Claude responds directly, no orchestration. |

If not declared → `helix_minimal` by default.

---

## Dialogue Protocol

Helix follows these rules on every request:

| Rule | Behavior |
|------|----------|
| **Ask before acting** | If request is ambiguous → max 2-4 grouped questions before touching code. If concrete → proceed directly. |
| **Visible plan** | When task touches ≥2 files → show plan A→B→C and wait for confirmation. |
| **Confidence threshold** | Declare `high autonomy` (execute without asking) or `low autonomy` (confirm each step) at the start. |
| **Red zone alert** | Before touching high-risk files → declare exactly which line will change and wait for OK. |
| **Explore → Implement** | New features → propose ≤3 options and wait for choice. Bugs/concrete tasks → implement directly. |
| **Proactive decisions** | Non-trivial design decisions → record them in `DESIGN DECISIONS` of the project's CLAUDE.md. |
| **Silent log** | If `helix-bitacora.md` exists → record changes/recommendations/errors without asking permission. |

---

## Self-Maintenance System

### Initial project analysis (`/helix-analiza`)

When arriving at a new project, Helix offers a diagnosis:
- Detects stack (FastAPI, React, PostgreSQL, Docker...) with `helix-detect-stack.sh`
- Maps relevant agents and skills to the stack
- Identifies risk zones
- Saves summary in `helix-analysis.md` + details in vector memory
- Initializes `helix-bitacora.md`

### Health pipeline (`/helix-salud`)

Automatically evaluates 3 dimensions at the end of each session:

| Dimension | What it measures | Alert threshold |
|-----------|-----------------|-----------------|
| **Context** | CLAUDE.md size + analysis age | <60 pts |
| **Quality** | Errors in log + pending recommendations | <60 pts |
| **Overhead** | Active agents + sessions without learnings | <60 pts |

If problems detected → writes `helix-alerta.md` → next session reports before any task.

### Cost control (`/economia`)

```bash
/economia       # enable
/economia off   # disable
/economia?      # current status
```

In economy mode: no subagents unless ≥3 simultaneous domains, no Layer 2, Grep before Read, bullet-only responses.

---

## Privacy System

`helix_asisten` is a public repo. `memory/agents/*.md` files may have private project context locally — this system guarantees it never reaches the repo.

### Marker convention

```markdown
<!-- PROJECT-CONTEXT:START -->
## Current project context
...specific data: tables, routes, costs, names...
<!-- PROJECT-CONTEXT:END -->
```

`update.sh` automatically strips these blocks when syncing.

### Sanitize and pre-commit hook

```bash
# Manual sanitize
bash scripts/sanitize-memory-agents.sh claude/memory/agents/
```

The pre-commit hook blocks commits containing private context without markers:

```
🔴 PRIVACY GUARD — pattern detected: '## Current project context'
   Options: 1) add markers  2) run sanitize  3) remove manually
```

Install the hook manually after cloning:
```bash
cp ~/helix_asisten/scripts/pre-commit-hook.sh ~/helix_asisten/.git/hooks/pre-commit
chmod +x ~/helix_asisten/.git/hooks/pre-commit
```

---

## Vector Memory (`hv` CLI)

Helix stores semantic memories in Qdrant via a lightweight CLI:

```bash
hv store "agent routing fixed — use threshold 0.45 for frontend" --collection learnings
hv search "frontend routing threshold" --collection learnings
hv list --collection learnings
hv cluster --collection learnings   # group similar memories
```

Used by `helix-agent-evolve.py` to persist agent evolution history and by `helix-project-index.sh` to index project knowledge. Falls back gracefully if Qdrant is not running.

---

## Ollama Models (Layer 0)

```bash
# Download base models
ollama pull qwen2.5-coder:7b   # ~4.7 GB
ollama pull llama3.2:3b        # ~2.0 GB

# Create Helix models
ollama create helix-coder -f ~/helix_asisten/ollama/helix-coder.Modelfile
ollama create helix-scout -f ~/helix_asisten/ollama/helix-scout.Modelfile
```

| Model | Base | Size | Use |
|-------|------|------|-----|
| `helix-coder` | Qwen2.5-Coder 7B | 4.7 GB | Bugs, refactors, FastAPI+React code |
| `helix-scout` | Llama 3.2 3B | 2.0 GB | Logs, quick transforms, CRUDs |

```bash
# Unified helper
bash ~/helix_asisten/scripts/capa0.sh logs  "$(cat app.log)"
bash ~/helix_asisten/scripts/capa0.sh code  "Debug this error..."
```

If `ollama` is not installed, `capa0.sh` returns exit 2 → Helix automatically scales to Layer 1.

---

## RuFlo Ecosystem

> Source: https://github.com/ruvnet/ruflo  |  https://github.com/ruvnet/claude-flow

**Active version: `ruflo v3.5.42`**

| Package | Role |
|---------|------|
| `ruflo` | Main package — installs the entire ecosystem |
| `@claude-flow/cli` | MCP server — exposes `mcp__claude-flow__*` tools |
| `claude-flow@alpha` | CLI + `@claude-flow/memory` for memory hooks |
| `agentic-flow@alpha` | ONNX embeddings for semantic search |

## Required MCPs

```bash
# Main MCP
claude mcp add claude-flow -- npx -y @claude-flow/cli@latest mcp start

# Other MCPs
claude mcp add context7 -- npx -y @upstash/context7-mcp
claude mcp add browser-tools -- npx @agentdeskai/browser-tools-mcp@1.2.0
claude mcp add puppeteer -- npx -y @modelcontextprotocol/server-puppeteer

# Warm agentic-flow cache
npx agentic-flow@alpha --version
```

---

## Memory Layers (helix-engine)

Active when using `helix-engine/` in a project:

```
┌─────────────────────────────────────────────────────┐
│  Layer 1: Working Memory (RAM cache, 100 entries)    │
│     ↓ overflows to                                   │
│  Layer 2: HNSW Vector Store (semantic search)        │
│     150x-12500x faster than linear search            │
│     ↓ connected to                                   │
│  Layer 3: Memory Graph (PageRank, max 5000 nodes)    │
│     ↓ learns with                                    │
│  Layer 4: LearningBridge (SONA + ReasoningBank)      │
└─────────────────────────────────────────────────────┘
```

## 3-Tier Model Routing (helix-engine)

| Tier | Handler | Latency | When |
|------|---------|---------|------|
| **1** | Agent Booster (WASM) | <1ms | Simple transforms: var→const, add-types |
| **2** | Claude Haiku | ~500ms | Low complexity (<30%) |
| **3** | Claude Sonnet/Opus | 2-5s | Complex reasoning (>30%) |

Combined token savings: **30-50%**

## Status Panel (helix-engine)

```
▊ RuFlo V3 ● user  │  ⏇ main  │  Claude Code
🤖 Swarm  ○ [ 0/15]  👥 0    🪝 0/17    🔴 CVE 0/3    💾 5MB    🧠 0%
📊 AgentDB    Vectors ●0  │  Size 0KB  │  Tests ●0
```

---

## Syncing the Repo

```bash
cd ~/helix_asisten
bash update.sh        # sync + automatic private context sanitize
git add -A && git commit -m "sync: $(date +%Y-%m-%d)"
git push
```

### helix-engine source

`update.sh` uses `$HELIX_ENGINE_SRC` to know which project to copy `helix-engine/` from. Set it locally (not committed to the repo):

```bash
# ~/.claude/session-env/helix-engine-src.sh (gitignored)
export HELIX_ENGINE_SRC="$HOME/path/to/your/project"
```

If the variable is not defined, the helix-engine step is silently skipped.

---

## Changelog

### v3.7.0 — 2026-03-26 · Agent evolution system

- `scripts/helix-agent-evolve.py` — automated agent scoring (0→100 rubric: specificity, tools, examples, triggers)
- `scripts/helix-project-index.sh` — indexes project files into Qdrant vector memory
- 27 agents fully evolved: average score 40→81/100
- `frontend-developer`: threshold 0.55→0.45, enriched vocabulary for better routing

---

### v3.6.0 — 2026-03-26 · Vector memory engine + Capa 0 explicit triggers

- `scripts/helix-vector.py` — Qdrant-backed vector memory: store, search, cluster, export
- `scripts/hv.sh` — `hv` CLI: `hv store`, `hv search`, `hv list`, `hv cluster`
- `capa0-guard` hook in `settings.json` — explicit triggers for Layer 0 (logs >200 lines, Docker output, stacktraces)
- Layer 0 now auto-escalates to Layer 1 when `ollama` is unavailable (exit 2)

---

### v3.5.0 — 2026-03-24 · Privacy system

- `scripts/sanitize-memory-agents.sh` — strips `<!-- PROJECT-CONTEXT:START/END -->` markers and fallback on `## Current project context`
- Pre-commit hook — blocks private context before it reaches the repo
- `update.sh` integrates automatic sanitize and replaces hardcoded path with `$HELIX_ENGINE_SRC`
- Global `CLAUDE.md`: new `PRIVACY` section
- Retroactive cleanup: skills generalized to v2.0, agents without project context

---

### v3.4.0 — 2026-03-24 · Creative agents + dialogue protocol + global hooks

- New agents: `brand-identity-expert`, `app-creative-genius`
- `helpers/statusline.cjs` — dynamic status bar
- `settings.json` — cost-tracker, scope-guard, suggest-compact, helix-bitacora hooks
- `memory/active-rules.md` — 31 seeded rules available on fresh install
- CLAUDE.md: evolutions #9–15 integrated (dialogue protocol, log, economy mode, health pipeline, hybrid memory)

---

### v3.3.0 — 2026-03-24 · Active self-evolution

- `scope-guard.sh` — warns when editing outside the active project
- `cost-tracker.sh` — counts tool calls, reports cost on session close
- `routing-learn.sh` — records routing decisions with outcome
- `evolve.sh` improved: `learn` installs rule in `active-rules.md` with immediate effect
- `session-start.sh`: shows top effective agents per project

---

### v3.2.0 — 2026-03-24 · Hackathon winner integration

- Agents: `harness-optimizer`, `loop-operator`
- Skills: `context-budget` (`/context-budget`), `strategic-compact` (automatic hook)
- `suggest-compact.sh` hook: suggests `/compact` at 50 tool calls

---

### v3.1.0 — 2026-03-20 · Self-maintenance system

- `/helix-analiza` — initial analysis with hybrid memory
- `/helix-salud` — health evaluation + "we need to talk" pipeline
- `/helix-actualiza` — maintenance and analysis update
- `/economia` — economy mode
- Project log: automatic silent maintenance
- Subagent thresholds: 1 domain → solo, 2 → 1 subagent, 3+ → Layer 2

---

### v3.0.0 — 2026-03-08 · RuFlo V3 + helix-engine

- Injectable RuFlo V3 engine (`helix-engine/`)
- HNSW Vector Store (150x-12500x speedup vs linear search)
- SONA Learning + ReasoningBank
- 26 agent categories: sparc, swarm, v3, github, optimization, hive-mind, consensus...
- Dynamic statusline (swarm + tokens + CVEs + AgentDB)
- 4 orchestration layers: Ollama → Subagents → Swarm → Agent Teams

---

<details>
<summary>🇦🇷 Leer en español</summary>

Este README existe también en español en versiones anteriores del repo. El contenido técnico es idéntico — la traducción es solo de forma, no de fondo. Si preferís la versión en español, podés consultar el historial de git o abrir un issue.

</details>
