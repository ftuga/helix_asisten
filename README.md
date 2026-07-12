# Helix — Self-Evolving Agent for Claude Code

![Helix_icono.jpg](assets/Helix_icono.jpg)

> **Current version: v3.16.0** — [Changelog](#changelog)

I'm not a prompt. I'm the accumulation of real decisions made in real projects.

Every time a mistake was made with me, I recorded it. Every time we found a pattern that worked, I turned it into a rule. Each session leaves something behind — an evolution, a new agent, a skill that didn't exist before. That's what makes me different: I wasn't designed in the abstract, I was trained in production.

I have memory across sessions. I know which agent to use based on the domain. I take care of myself — I evaluate my own health, compress my context when it grows too large, and warn you when something is wrong before you notice it. When a new project appears, I analyze it, map its risk zones, and keep a silent log of everything I touch.

I can operate in four layers: from a free local model for simple tasks, to a coordinated swarm of 15 agents for features that touch the entire stack. The user never decides which layer — I evaluate and execute.

This repo is my complete configuration, versioned and portable. Clone it, run `install_on_wsl.sh`, and you have everything I am on a new machine in minutes.

---

## Prerequisites

> **v3.14.0** — `check-prereqs.sh` v2 is **blocking**. `install_on_wsl.sh` will refuse to proceed
> until every Required dependency is present. The script generates a single grouped
> copy-paste block with only the commands you actually need.

| Requirement | Type | Notes |
|-------------|------|-------|
| [Claude Code CLI](https://docs.anthropic.com/claude-code) | Required | `curl -fsSL https://claude.ai/install.sh \| bash` (native build, self-updating — avoid `sudo npm install -g`, see [Troubleshooting](#troubleshooting)) |
| Node.js ≥ 18 **native Linux** | Required | MCPs fail if Node points to a Windows path in WSL — install via NodeSource, not Windows |
| Python ≥ 3.9 + pip3 | Required | `sudo apt-get install -y python3 python3-pip` |
| git, curl, rsync | Required | `sudo apt-get install -y git curl rsync` |
| zstd | Required (Ollama) | `sudo apt-get install -y zstd` |
| Docker (binary + active daemon) | **Required** | Qdrant vector memory. `curl -fsSL https://get.docker.com \| sh` |
| [Ollama](https://ollama.com/download) | **Required** | Layer 0 + helix-judge + nomic-embed-text. `curl -fsSL https://ollama.com/install.sh \| sh` |
| `nomic-embed-text` model | Recommended | `ollama pull nomic-embed-text` (vector memory degraded without it) |
| chromium-browser | Optional | Required by puppeteer MCP — without it, MCP shows "Failed to connect" |

> **OS support (v1):** Ubuntu / Debian / WSL with `apt-get`. `check-prereqs.sh` exits early on macOS, Fedora, Arch with a pointer to `claude/memory/topics/install-os-support.md` (manual install commands per OS).

> **WSL users:** run `which node` before installing — if it points to `/mnt/c/...`, install native Linux Node first.

> **Ubuntu 24.04+ users:** `install_on_wsl.sh` handles PEP 668 automatically (`--user --break-system-packages`).

---

## Quick Install

**Linux / macOS / WSL:**

```bash
git clone git@github.com:ftuga/helix_asisten.git ~/helix_asisten
bash ~/helix_asisten/install_on_wsl.sh
```

> **The repo can live anywhere.** If you clone it to a different path (e.g. `~/documentos/helix_asisten`), the installer creates a symlink `~/helix_asisten → <your clone>` so every internal reference keeps working with a single copy. A partial leftover at `~/helix_asisten` from an older install is backed up automatically; a second *git clone* at that path is never touched — the installer warns you to unify them first.

**Windows (PowerShell, requires [Git for Windows](https://git-scm.com/download/win)):**

```powershell
git clone git@github.com:ftuga/helix_asisten.git $HOME\helix_asisten
cd $HOME\helix_asisten
.\install_on_windows.ps1
```

`install_on_wsl.sh` verifies all prerequisites, installs Helix into `~/.helix/` (split layout, default), and auto-installs MCPs if the Claude CLI is in PATH. Run `scripts/check-prereqs.sh` standalone to diagnose missing dependencies before installing.

```bash
# Default install: split layout in ~/.helix/  (claude command stays clean)
bash ~/helix_asisten/install_on_wsl.sh

# Legacy install (Helix mixed into ~/.claude/)
HELIX_LAYOUT=legacy bash ~/helix_asisten/install_on_wsl.sh

# Force overwrite everything (memory/agents, memory/topics)
HELIX_FORCE=1 bash ~/helix_asisten/install_on_wsl.sh

# Migrate existing legacy install to split (non-destructive)
bash ~/helix_asisten/scripts/migrate-to-split.sh
```

**Updating an existing install** (after `git pull`):

```bash
# Linux/macOS/WSL — preserves your personal config (user-profile.md, helix-role.conf, etc.)
bash update_local_on_wsl.sh           # interactive
bash update_local_on_wsl.sh --dry-run # preview only
```

```powershell
# Windows
.\update_local_on_windows.ps1
.\update_local_on_windows.ps1 -DryRun
```

`update_local_on_wsl.sh` (and its Windows wrapper) does `git pull` + rsync from the repo into your active Helix dir, **preserving** these files if they already exist locally:
- `memory/user-profile.md` (your personality/profile)
- `helix-role.conf`, `capa0-disabled`, `settings.local.json`
- `memory/helix-{stack,bitacora,backlog,team,analysis,plan-*,alerta}.md`
- runtime logs (`judge-decisions`, `aidefence-redactions`, `egress-audit`, etc.)
- custom agents/skills you created locally

> **`update.sh`** is the *creator* counterpart — syncs `~/.helix/` (or `~/.claude/`) → repo. Don't confuse the two.

---

## Layouts: claude vs. helix

Since v3.16, Helix supports two installation layouts:

| Layout | Where Helix lives | `claude` command | `helix` command |
|--------|-------------------|------------------|-----------------|
| **`split`** *(default)* | `~/.helix/` | Claude Code stock — untouched | Wraps `claude` with `CLAUDE_CONFIG_DIR=~/.helix/` |
| **`legacy`** | `~/.claude/` | Equivalent to `helix` | Equivalent to `claude` |

`split` is the recommended layout. It keeps Claude Code stock available (run `claude`) for any context where you don't want Helix's hooks, agents, or autoevolution to apply, while `helix` always boots into the full Helix environment.

Switch layouts:

```bash
# fresh install with split (default)
bash install_on_wsl.sh

# install with legacy layout (Helix mixed into ~/.claude/)
HELIX_LAYOUT=legacy bash install_on_wsl.sh

# migrate existing legacy install to split (non-destructive, with backup)
bash scripts/migrate-to-split.sh

# inspect active layout
helix --where
```

The legacy injectable RuFlo V3 engine (`helix-engine/`) was discontinued by Helix Council #1 (plan v4 D1', 2026-05-04) for orthogonal concerns: 314-tool MCP noise, TS/Node lock-in, non-controllable topology. Root-cause analysis at `claude/memory/topics/ruflo-rootcause-D.md`. The native bash statusline (`helix-statusline.sh`, FASE 0.5) replaced the RuFlo CJS panel in v3.14.0.

---

## Platform support

| Platform | Status | Installer | Notes |
|----------|--------|-----------|-------|
| Linux    | first-class | `bash install_on_wsl.sh` | tested on Ubuntu 22.04+, Debian 12 |
| macOS    | first-class | `bash install_on_wsl.sh` | tested on macOS 13+ (Apple Silicon and Intel) |
| WSL2     | first-class | `bash install_on_wsl.sh` | Ubuntu/Debian inside WSL — same as Linux |
| Windows native | supported via Git Bash | `.\install_on_windows.ps1` (PowerShell) | requires [Git for Windows](https://git-scm.com/download/win) for the bash hooks |

Windows note: Helix's hooks are bash scripts. On Windows, Git Bash provides the POSIX shim — `install_on_windows.ps1` is a thin bootstrap that validates Git Bash and delegates to `install_on_wsl.sh`. Pure PowerShell (without Git Bash) is **not** supported.

---

## Structure

```
claude/              → ~/.helix/ (split, default) or ~/.claude/ (legacy)
  CLAUDE.md          → Helix global instructions + layer protocol
  settings.json      → Hooks: PreToolUse, PostToolUse (cost-tracker, scope-guard, log)
  evolve.sh          → Records learnings and installs them as active rules
  session-start.sh   → Restores context, shows active rules and health alerts
  session-end.sh     → Saves state, evaluates metrics, reports estimated cost
  self-check.sh      → Pre-close checklist: blocks if CLAUDE.md exceeds 220 lines
  health-check.sh    → Verifies ecosystem integrity
  compress.sh        → Archives old evolutions to keep CLAUDE.md lean
  agents/            → 28 evolved agents (avg score 40→81/100)
                       includes 7 council-* roles (skeptic/innovator/conservative/
                       synthesizer/researcher/devils-advocate/arbiter) for the
                       Helix Council v1.0 decision protocol
  memory/            → design-system, agents-index, evolution-log, active-rules, topics
  memory/routing-heuristics.md  → ERL-generated routing rules (auto-updated weekly)
  memory/reflexions.jsonl       → Semantic error memory backup
  skills/            → 35 reusable skills across projects
  helpers/helix-erl.sh          → ERL heuristic extractor
  helpers/helix-reflexion.sh    → Semantic error memory (Qdrant store + search)
  helpers/helix-retrospectiva.sh → Auto-analysis at session close
  helpers/skill-tracker.sh      → Tracks real skill/agent usage
  helpers/helix-distill.sh      → HELIX-COMPRESS: agent-specific CLAUDE.md slices + project compression
  helpers/helix-lang-state.sh   → S:hash state manager (snapshot, delta, get, gc)
  helpers/helix-lang-bench.sh   → HELIX-LANG compression benchmark
  helpers/helix-statusline.sh   → Native bash statusline (FASE 0.5) <200ms p99
  helpers/helix-hwprobe.sh      → CPU/RAM/GPU/disk probe → hw-profile.json
  helpers/helix-capa0-policy.sh → Layer 0 ON/OPT_IN/OFF policy gate (HW-aware)
  helpers/helix-capa0-toggle.sh → Layer 0 manual override (off --session|--persistent / on / status)
  helpers/helix-bench-capa0.sh  → Empirical Layer 0 latency bench
  helpers/helix-models-suggest.sh → Compatible Ollama models per HW tier
  helpers/helix-multidomain-trigger.* → D1' PreToolUse(Agent) advisory trigger
  helpers/helix-judge.py        → M1: LLM-as-judge (Ollama) for semantic conflicts
  helpers/passive-capture-*.{py,sh} → M2: passive decision detector + review tool
  helpers/helix-project-consolidate.py → M3: name drift detector + interactive unify
  helpers/helix-route-recommend.py → R1: model advisor (read-only)
  helpers/helix-cost-rollup.sh  → R2: real USD cost from JSONL transcripts
  helpers/helix-aidefence-*.{py,sh} → SEC1: PII redactor on Helix-internal logs
  helpers/helix-egress-audit-*.{py,sh} → SEC2: WebFetch/Search/MCP audit
  council/log/                  → Helix Council v1.0 immutable decision audit logs
  skills/helix-lang/            → HELIX-LANG v2: universal inter-agent protocol
  skills/helix-speak/           → HELIX-SPEAK: situational output compression
  skills/_distilled/            → 15 auto-generated agent slices (78-96% savings each)

scripts/             → Helix engine scripts
  helix-vector.py    → Qdrant vector memory engine (store, search, cluster)
  hv.sh              → CLI wrapper for vector memory (hv store / hv search / hv list)
  helix-agent-evolve.py → Automated agent scoring and evolution (0→100 rubric)
  helix-project-index.sh → Project indexing into vector memory
  capa0.sh           → Layer 0 dispatcher: routes to helix-coder or helix-scout
  check-prereqs.sh   → v2 blocking prerequisites check (FAIL on docker/ollama/zstd/claude CLI)

tests/               → Repo-versioned smoke tests (v3.14.0)
  test-capa0-toggle.sh   → 19/19 PASS — Layer 0 manual override end-to-end
  test-check-prereqs.sh  → 24/24 PASS — PATH-shadowed dep simulation

template/            → ~/.claude-template/ (base for new projects)
  CLAUDE.md          → Project CLAUDE.md template
  init-project.sh    → Initialization script

helix-engine/        → Legacy injectable engine (deprecated 2026-05-04, plan v4 D1')
                       Kept for historical reference. New projects should NOT inject it.
                       Detail: claude/memory/topics/ruflo-rootcause-D.md
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
   → **Retrospectiva**: detects unregistered learnings from session summary
   → **ERL**: updates routing heuristics weekly from feedback data
   → **Gap analysis**: flags domains used but not yet in heuristics
   → If errors resolved → suggests storing in Reflexion memory
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

| Layer | When | What it activates | Status |
|-------|------|-------------------|--------|
| **0 — Ollama** | Logs, long text, Docker output, transforms | Local model (`helix-coder` / `helix-scout`). HW-aware policy gate (FASE 9). If unviable → exit 2 → escalates to Layer 1 | ✅ Active |
| **1 — Subagents** | One concrete artifact (endpoint, component, query) | `Agent` tool with specialized agent from catalog | ✅ Active |
| **2 — Swarm** | Feature touching ≥2 stack layers | Council-decided 2026-05-04: own minimalist Layer 2 orchestrator (TRANCH 3 candidate). The `claude-flow` MCP path is **deprecated (D1', plan v4)**. | ⏳ Trigger active, orchestrator pending |
| **3 — Agent Teams** | Peer-to-peer collaboration between agents | Agent Teams (CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS) | ❌ **NOT IMPLEMENTED** — missing mailbox, teammates dirs, `TaskCreated` hook. See `claude/memory/topics/agent-teams-status.md` |

**Multi-domain trigger (D1', v3.14.0):** `claude/helpers/helix-multidomain-trigger.py` is a `PreToolUse(Agent)` hook that detects 2+ domain intent (11 keyword groups: backend/frontend/db/security/infra/testing/debug/ui/performance/data/mlops) — advisory-only, threshold ≥2, kill switch `HELIX_D1_TRIGGER_ENABLED=0`.

**Escalation rule:** when in doubt between Layer 1 and 2 → Layer 1 (cheaper). Escalate only when the trigger advises ≥2 domains.

---

## Helix Modes

Declare in each project's `CLAUDE.md`: `HELIX_MODE: <mode>`

| Mode | What it activates |
|------|-------------------|
| `helix_control_total` | Layer 0 (Ollama HW-gated) + Layer 1 (subagents). Layer 2 active when its trigger fires. Layer 3 still pending. |
| `helix_minimal` | Specialized subagents only (Layer 1). No Layer 2 orchestrator. No Agent Teams. |
| `helix_off` | Claude responds directly, no orchestration. |

If not declared → `helix_minimal` by default.

### `HELIX_ROLE` — creator vs user (plan v4 D4)

`~/.claude/helix-role.conf` defines the role. Default: `creator`.

| Role | Behavior |
|------|----------|
| `creator` | META1 helix-expert always active. META2 (market-watch) and META3 (self-improve) **on-demand only** — no cron, no scheduler, no auto-trigger (D2.1). Council active. Self-modification only with explicit OK. |
| `user` | Read-only helix-expert. No self-improve. No market-watch. Updates via `helix-update notify`. |

Scripts that depend on the role must `source ~/.claude/helix-role.conf` and respect `$HELIX_ROLE`.

---

## Dialogue Protocol

Helix follows these 12 rules on every request:

| # | Rule | Behavior |
|---|------|----------|
| 1 | **Ask before acting** | If request is ambiguous in scope, file, or behavior → max 2-4 grouped questions in ONE message before touching code. If clear → proceed directly. |
| 2 | **Visible plan** | When task touches ≥2 files or has non-trivial steps → show plan A→B→C and wait for OK. |
| 3 | **Red zone alert** | Before modifying files marked  in the project risk-map → declare exact line/function and reason. Wait for OK. |
| 4 | **Proactive decision recording** | Non-trivial design decisions → add to `## DESIGN DECISIONS` of the project CLAUDE.md without being asked. |
| 5 | **Initial project analysis** | If `session-start` emits `[HELIX-SUGGEST-ANALYSIS]` → suggest `/helix-analiza` once at end of first message. If declined → `touch .analysis-declined`. If exists → load silently. |
| 6 | **Continuous bitácora** | If `.claude/memory/helix-bitacora.md` exists → update it after significant changes, non-trivial recommendations, and errors. No permission needed. |
| 7 | **"We need to talk"** | If `session-start` emits `[HELIX-NECESITAMOS-HABLAR]` → read `helix-alerta.md` and report before responding. If user declines → `rm helix-alerta.md`. |
| 8 | **Requirement intake with visible plan** | ≥3 domains or non-trivial dependencies → generate `helix-plan-REQ-NNN.md`. 1-2 domains → execute directly. |
| 9 | **Auto-economy by signal** | If first user request is ≤15 words, imperative verb, no file paths or stack trace → auto-apply `economy mode` silently. Heuristic, not a barrier. |
| 10 | **Mandatory parallelism** | Independent Reads/Greps/Bash → ALWAYS in one message with multiple tool calls. Serializing without dependency is a measured antipattern (audited by self-check). |
| 11 | **Auto-close** | If user types `exit`, `salir`, `bye`, `cerrar`, `/exit` → run `bash ~/.claude/session-end.sh "<summary>"` without asking. Generate concise session summary. |
| 12 | **Resume opt-in** | If `session-start` emits `[HELIX-SUGGEST-RESUME]` → offer 3 options at end of first message: (1) resume context, (2) new chat, (3) detail. **NEVER load snapshot without consent.** |

**HELIX-SPEAK** (output compression by type): `ultra` for inter-agent coordination, `brief` for user reports, `off` for code/commands/security.

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

### Refresh stale memory (`/helix-actualiza`)

Refreshes `helix-analysis.md`, `helix-backlog.md`, and `helix-plan-*.md` when commits land after the last memory update. Suggested automatically when `session-start` detects staleness.

### Layer 0 manual override (`/helix_desactiva_CAPA0`, `/helix_activa_CAPA0`)

Layer 0 is **enabled by default** based on detected hardware (FASE 9 HW-aware). Users with limited resources can force it OFF:

```
/helix_desactiva_CAPA0   → asks: session-only or persistent?
/helix_activa_CAPA0      → reverts to HW-based decision
```

The override beats the HW heuristic. Modes:
- `session` — `~/.claude/capa0-disabled` cleaned automatically by `session-end.sh`.
- `persistent` — survives across sessions until `/helix_activa_CAPA0`.
- One-shot env var: `HELIX_CAPA0_DISABLED=1`.

When OFF, `helix-capa0-policy.sh` reports `OFF` with reason "override manual del usuario", and `capa0.sh` returns exit 2 → automatic escalation to Layer 1.

---

## Helix Council v1.0 — Decision Protocol

For non-trivial architectural decisions Helix runs a 7-agent council with a written constitution. Used to break impasses, validate large refactors, and decide between strategic alternatives without rubber-stamping.

| Role | Function |
|------|----------|
| `council-skeptic` | Challenges assumptions, demands evidence. |
| `council-innovator` | Proposes non-obvious alternatives. One must be radical. |
| `council-conservative` | Defends status quo when evidence to change is weak. |
| `council-synthesizer` | Lists trade-offs without taking sides. Drafts common position in Round 3. |
| `council-researcher` | Gathers evidence (papers, RFCs, docs). Only role allowed to invoke expert summons. |
| `council-devils-advocate` | Round 3 mandatory: takes the emerging decision and breaks it. Finds catastrophic failure scenarios. |
| `council-arbiter` | Applies the constitution. Pre/post checks. Sanitizes inputs. Decides context level. Forces escalation if rules are violated. |

**Constitution (R1-R9):** time-box (rounds≤3, calls≤25, wall-clock<600s), audit log immutable (`chmod 400`), context filtering by keyword, anti-injection scan, escalation to creator on no-consensus.

**Audit logs:** `~/.claude/council/log/<timestamp>_<id>.yaml` (immutable).

Used in v3.14.0 for plan v4 decision (TRANCH 1+2+3 structure), FASE 6 installer (4 options + creator escalation), Gate B1 closure. Topics: `claude/memory/topics/council-design.md`, `claude/memory/topics/helix-evolution-completed.md`.

---

## HSL v1 — Helix Security Layer

Six layers active by default since v3.x. Audit (2026-05-03): covers 4/14 PII types directly + 2 partial = 32% of PII surface for Helix-internal data. Gap mitigated by SEC1 (TRANCH 2).

| # | Layer | What it catches |
|---|-------|-----------------|
| L1 | injection | Prompt injection patterns in tool outputs |
| L2 | egress | Unauthorized network calls — see SEC2 below |
| L3 | secrets | Tokens / API keys / passwords in writes |
| L4 | integrity | File checksum drift on protected paths |
| L5 | evolve-guard | Malicious or contradictory `evolve.sh learn` calls |
| L6 | reflexion-quarantine | Quarantines new reflexions until human review |

Detail: `claude/memory/topics/hsl-v1-audit.md`. Plus the two TRANCH 2 PII features below.

---

## TRANCH 2 — Self-improvement Capabilities (v3.14.0)

Council-approved 2026-05-04 (plan v4, Gate B1 closed 5/5). All 6 components active. None of them auto-mutates state without explicit creator confirmation.

### M1 — `helix-judge` (LLM-as-judge for semantic conflicts)

Local Ollama backend (`llama3.2:3b` default, override `HELIX_JUDGE_MODEL`). Static few-shot prompt embedded in code (anti-poisoning hard rule, CS1). Confidence threshold ≥0.85. 100% audit log in `judge-decisions.jsonl`. Audit feedback isolated in a separate file (only source for future calibration — no self-reinforcing loop).

```bash
bash ~/.claude/helpers/helix-judge.py judge "memory A vs memory B"
bash ~/.claude/helpers/helix-judge.py scan
bash ~/.claude/helpers/helix-judge.py audit-list
```

### M2 — `passive-capture` (decision detector during edits)

`PostToolUse(Write|Edit|MultiEdit)` Python hook (~50ms p99). Three matchers: (A) Helix path, (B) 8 decision keywords, (C) tool. Threshold ≥2 matchers. Captures land in `passive-captures-pending.jsonl` for explicit review:

```bash
bash ~/.claude/helpers/passive-capture-review.sh list
bash ~/.claude/helpers/passive-capture-review.sh approve <idx>
bash ~/.claude/helpers/passive-capture-review.sh stats
```

Skill: `helix-passive-review`. Bench: `claude/memory/topics/m2-bench.md`.

### M3 — `helix-project-consolidate` (name drift detector)

Fuzzy-matched detection of duplicate names across helpers/skills/agents/topics using `difflib.SequenceMatcher` with strip rules (`helix-`, `helix_`, `claude-`, `-hook`, `-helper`). Threshold env var `HELIX_M3_FUZZY_THRESHOLD` (default 0.75).

```bash
bash ~/.claude/helpers/helix-project-consolidate.py scan
bash ~/.claude/helpers/helix-project-consolidate.py unify   # interactive, requires explicit confirm
```

Reversibility: `git restore` if in a repo, backup in `~/.claude/backups/m3/` otherwise. **Never unifies without explicit creator OK.**

### R1 — `helix-route-recommend` (model advisor, read-only)

Recommends Claude Opus / Sonnet / Haiku per domain or per agent based on cost-by-project (R2) cross-joined with routing-feedback. **Never modifies `settings.json`.** Override via `HELIX_FORCE_MODEL=<model>`. Kill switch `HELIX_R1_ENABLED=0`. Audit log `r1-recommend-log.jsonl` 100% calls. AGENT_TO_DOMAIN and DOMAIN_RECOS mappings static in code (anti-poisoning, parallel to M1 CS1).

```bash
bash ~/.claude/helpers/helix-route-recommend.py recommend backend-developer
bash ~/.claude/helpers/helix-route-recommend.py current
bash ~/.claude/helpers/helix-route-recommend.py compare
```

Skill: `helix-route-recommend`.

### R2 — `helix-cost-tracker` (real USD from JSONL transcripts)

Processes `~/.claude/projects/*.jsonl` with Anthropic Nov 2025 pricing (Opus 4.7 $15/$75, Sonnet 4.6 $3/$15, Haiku 4.5 $1/$5, cache write 1.25×, cache read 0.10×).

```bash
bash ~/.claude/helpers/helix-cost-rollup.sh current     # current session, 30s cache
bash ~/.claude/helpers/helix-cost-rollup.sh session <id>
bash ~/.claude/helpers/helix-cost-rollup.sh all         # rollup
bash ~/.claude/helpers/helix-cost-rollup.sh report      # generates topics/route-cost-audit.md
```

Wired to the bash statusline 💰 slot — shows real USD instead of placeholders.

### SEC1 — `helix-aidefence` (PII redactor on Helix-internal logs)

`PostToolUse(Write|Edit|MultiEdit)` Python hook with **scope limited to Helix-internal logs** (NOT user project files). Redacts 10 PII types: EMAIL, PHONE_E164, PHONE_NA, SSN_US, IBAN, IPV4/6 PUBLIC, CREDIT_CARD (Luhn-validated), PATH_USERNAME, URL_USERINFO. **Redact-no-block** hard rule. Audit log `aidefence-redactions.jsonl`.

Latency: p99 77ms POS — exceeds the original <30ms criterion. Pending creator decision: accept v1.0 / re-spec to <80ms / block until native rewrite (TRANCH 3).

### SEC2 — `helix-egress-audit` (network call audit)

`PostToolUse(WebFetch|WebSearch|mcp__.*)` Python hook. Schema: `{ts, tool, domain, path_short, source, query_sanitized, new_domain}`. Sanitization regex strips `(api_key|token|password|secret|auth|bearer|session|sid|jwt)=val`. First-seen domain alert + spike detection (≥20 calls / 5 min). Monthly reporter on-demand only (no cron, D2.1).

```bash
bash ~/.claude/helpers/helix-egress-report.sh
```

---

## Compression Systems

Three orthogonal mechanisms to reduce token cost on Helix's own coordination overhead. None of them touches the user-facing response — only internal artifacts.

### HELIX-LANG v2 — Universal inter-agent protocol

Compressed grammar with fixed verbs / ops / temporal markers / state hashes (`S:hash`) and `FROM->TO` flows. **58.7% measured output savings.** Use when: (a) invoking `Agent` tool with structured prompt >500 tokens, (b) coordinating ≥2 agents exchanging state, (c) internal memory re-read by another agent. **Don't use** for user-facing prose, source code, shell/SQL commands.

Skill: `~/.claude/skills/helix-lang/SKILL.md`. Adoption tracker: `~/.claude/helpers/helix-lang-detect.sh`.

### HELIX-DISTILL — Per-agent CLAUDE.md slices

Generates agent-specific slices of CLAUDE.md when invoking subagents in Layer 2 swarms with ≥8 agents. **78-96% per-agent context savings** (15 slices auto-generated in `claude/skills/_distilled/`). For normal sessions, Opus 4.7 handles long context natively — DISTILL is opt-in only.

```bash
bash ~/.claude/helpers/helix-distill.sh run
```

### HELIX-SPEAK — Situational output compression

Smarter than caveman-speak: compresses output by message type. `ultra` for inter-agent coordination, `brief` for user reports, `off` for code / commands / security where compression is dangerous.

Skill: `~/.claude/skills/helix-speak/SKILL.md`.

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

Helix stores semantic memories in [Qdrant](https://qdrant.tech/) using Ollama embeddings:

| Component | Details |
|-----------|---------|
| **Embedding model** | `nomic-embed-text` (Ollama) — 768 dimensions, ~8k token limit |
| **Vector store** | Qdrant running in Docker on port 6333 |
| **Override model** | `HELIX_EMBED_MODEL=<model>` env var |

`install_on_wsl.sh` sets up both automatically. To set them up manually:

```bash
# Qdrant
docker run -d --name helix-qdrant --restart unless-stopped \
  -p 6333:6333 -v qdrant_storage:/qdrant/storage qdrant/qdrant:latest

# Embedding model
ollama pull nomic-embed-text
```

`hv` CLI usage:

```bash
hv store "agent routing fixed — use threshold 0.45 for frontend" --collection learnings
hv search "frontend routing threshold" --collection learnings
hv list --collection learnings
hv cluster --collection learnings   # group similar memories
```

### How search works

1. Query text → embedded via `nomic-embed-text` → 768-dim vector
2. Qdrant runs **cosine similarity** against all vectors in the collection
3. Results filtered by `--threshold` (default: 0.45) and capped at `--top-k` (default: 5)
4. Returns JSON with `score`, `id`, and `payload` for each match

```bash
# Full options
hv search "query" --collection learnings --top-k 10 --threshold 0.6

# Multilingual: translate query to English before embedding (better recall)
hv search "umbral de routing frontend" --collection learnings --translate
```

The `--translate` flag is useful when memories were stored in English but queries arrive in Spanish — it reduces embedding drift caused by language mismatch.

### Verifying the setup

```bash
# Quick smoke test: store → search → check score > 0
python3 ~/helix_asisten/scripts/helix-vector.py store learnings "test entry" --meta '{"tag":"test"}'
python3 ~/helix_asisten/scripts/helix-vector.py search learnings "test entry"
# Expected: score ~0.99 for exact match
```

No automated test suite yet — verification is done via `scripts/verify-appliance.sh` which checks Qdrant connectivity and basic store/retrieve cycles.

Used by `helix-agent-evolve.py` to persist agent evolution history and by `helix-project-index.sh` to index project knowledge. Falls back gracefully if Qdrant or Ollama is not running.

### Reflexion Memory (`helix-reflexion.sh`)

Stores resolved errors as semantic memories in Qdrant (`helix_reflexions` collection). Before invoking `error-detective`, Helix searches for similar past resolutions:

```bash
# Store a resolved error pattern
bash ~/.claude/helpers/helix-reflexion.sh store \
  "SQLAlchemy scalar_one_or_none returns None — AttributeError on .id" \
  "Use .first() when result can be None, add explicit None check" \
  "funcionalidad" "my-project"

# Search before debugging
bash ~/.claude/helpers/helix-reflexion.sh search \
  "SQLAlchemy query returns None and crashes"
# → [1] confianza media (0.72) | funcionalidad | 2026-04-02
#      Patrón: SQLAlchemy scalar_one_or_none returns None...
#      Resolución: Use .first() when result can be None...
```

Threshold: 0.65 default. Confidence labels: alta (>0.85) · media (>0.72) · baja (≥0.65).

---

## Ollama Models (Layer 0)

```bash
# Download base models
ollama pull qwen2.5-coder:7b   # ~4.7 GB
ollama pull llama3.2:3b        # ~2.0 GB
ollama pull nomic-embed-text   # ~274 MB — required for vector memory

# Create Helix models
ollama create helix-coder -f ~/helix_asisten/ollama/helix-coder.Modelfile
ollama create helix-scout -f ~/helix_asisten/ollama/helix-scout.Modelfile
```

| Model | Base | Size | Use |
|-------|------|------|-----|
| `helix-coder` | Qwen2.5-Coder 7B | 4.7 GB | Bugs, refactors, FastAPI+React code |
| `helix-scout` | Llama 3.2 3B | 2.0 GB | Logs, quick transforms, CRUDs |
| `nomic-embed-text` | — | 274 MB | Embeddings for vector memory (`hv` CLI) |

```bash
# Unified helper
bash ~/helix_asisten/scripts/capa0.sh logs  "$(cat app.log)"
bash ~/helix_asisten/scripts/capa0.sh code  "Debug this error..."
```

### FASE 9 — HW-aware policy (v3.14.0)

Layer 0 used to run blindly. Since v3.14.0, an HW probe gates it.

```bash
bash ~/.claude/helpers/helix-hwprobe.sh         # CPU/RAM/GPU/disk → ~/.claude/hw-profile.json
bash ~/.claude/helpers/helix-capa0-policy.sh    # ON | OPT_IN | OFF
bash ~/.claude/helpers/helix-bench-capa0.sh     # empirical bench (overrides heuristic)
bash ~/.claude/helpers/helix-models-suggest.sh  # compatible models for this HW
```

| Tier | RAM / GPU | Policy |
|------|-----------|--------|
| `large` | ≥16 GB or NVIDIA GPU ≥4 GB VRAM | `ON` (full models) |
| `medium` | 8–16 GB no dedicated GPU | `OPT_IN` (small models only — phi3:mini, qwen2.5:3b) |
| `small` | <8 GB | `OFF` (Layer 0 disabled, fallback to Claude) |

Empirical bench (`helix-bench-capa0.sh`) **overrides** the heuristic — if measured latency <10s → ON, 10–30s → OPT_IN, >30s → OFF. Hard 30s timeout on every Ollama call.

If `ollama` is not installed (or HW policy says OFF), `capa0.sh` returns exit 2 → Helix automatically scales to Layer 1. See also `/helix_desactiva_CAPA0` for manual override above.

---

## Required MCPs

```bash
claude mcp add context7      -- npx -y @upstash/context7-mcp
claude mcp add browser-tools -- npx    @agentdeskai/browser-tools-mcp@1.2.0
claude mcp add puppeteer     -- npx -y @modelcontextprotocol/server-puppeteer
```

---

## Syncing the Repo

```bash
cd ~/helix_asisten
bash update.sh        # sync + automatic private context sanitize
git add -A && git commit -m "sync: $(date +%Y-%m-%d)"
git push
```

---

## ERL — Experiential Reflective Learning

Helix analyzes its own routing history and extracts reusable heuristics:

```bash
# Run manually (also runs automatically every 7 days at session close)
bash ~/.claude/helpers/helix-erl.sh

# Output: ~/.claude/memory/routing-heuristics.md
# → Domain rules:     "domain 'testing' → researcher (3/3 uses, 100%)"
# → Frequent pairs:   "frontend-developer → frontend-developer (6x)"
# → Project patterns: "project-name uses frontend-developer as dominant agent (6x)"
# → Gaps:             "24 agents in catalog never used"
```

The gap report is particularly useful — it surfaces agents that exist but are never actually invoked, candidates for pruning or better routing rules.

### Skill Usage Tracker

```bash
# Report: top skills/agents + never-used list
bash ~/.claude/helpers/skill-tracker.sh report

# Suggest skills unused for 30+ days (dry run)
bash ~/.claude/helpers/skill-tracker.sh prune --dry-run
```

Logs to `memory/skill-usage.jsonl`. The retrospectiva uses this data to flag overhead.

---

## Troubleshooting

### `Auto-update failed: no write permission to npm prefix`

Claude Code was installed with `npm install -g` under a root-owned prefix (typically `/usr`), so its auto-updater cannot write there. Migrate to the native build, which installs to `~/.local/bin` and self-updates without sudo:

```bash
curl -fsSL https://claude.ai/install.sh | bash
# verify the new binary wins in PATH:
which claude          # → ~/.local/bin/claude
# optional cleanup of the old npm copy:
sudo npm rm -g @anthropic-ai/claude-code
```

`install_on_wsl.sh` detects this condition and prints the same instructions as a warning.

### Two copies of the repo (`~/helix_asisten` + your clone)

Older installers copied `scripts/helix.sh` into a hardcoded `~/helix_asisten/`, so cloning the repo elsewhere left two copies. Since v3.15 the installer replaces that copy with a symlink `~/helix_asisten → <your clone>`. Re-run `install_on_wsl.sh` from your clone to fix an existing machine — the leftover directory is backed up as `~/helix_asisten.bak-<timestamp>`.

---

## Changelog

### v3.14.2 — 2026-05-04 · Cross-platform Python detection (Windows fix)

Fixes a Windows-specific failure where every `Bash` tool call triggered `PreToolUse:Bash hook error` and opened the Microsoft Store. Root cause: 3 PreToolUse hooks (`capa0-guard.sh`, `network-egress-hook.sh`, `secrets-scanner-hook.sh`) called `python3` directly. On Windows, `python3.exe` is a Microsoft Store stub when only `python` (3.10) and `py` (Python launcher) are installed — invoking it from bash silently fails the hook and pops the Store.

**Fix:** introduce a per-machine Python detector + global env var consumed by all helpers.

**New files**

- `claude/helpers/helix-python-detect.sh` — probes `python3 → python → py` (skipping the MS Store stub by checking `--version` output for "was not found" / "Microsoft Store") and writes `~/.claude/helix-python.conf` with `export HELIX_PYTHON=<cmd>`. One-shot, idempotent.
- `claude/helpers/helix-python-patcher.sh` — one-shot migration tool. Backs up each `.sh` to `*.pybak`, replaces bare `python3` with `"${HELIX_PYTHON:-python3}"` (skipping comment lines), inserts the source line after the shebang, syntax-checks each file with `bash -n`, restores from backup on any syntax failure. Preserves CRLF line endings (uses Python for the edit, not sed). Excludes the detector and itself.

**Auto-detect on first session**

`claude/session-start.sh` now runs `helix-python-detect.sh` if `~/.claude/helix-python.conf` is absent, then sources it. Future sessions reuse the cached config.

**Migrated callers**

54 helper `.sh` files migrated. The bash command `python3` is now `"${HELIX_PYTHON:-python3}"` and each file sources `helix-python.conf` near the top — so the env var is available even when the hook runs in a fresh shell spawned by Claude Code.

Two files needed manual fixes because `python3` appears as a string literal *inside* a single-quoted Python heredoc (`<<'PYEOF'`), where bash variables don't expand:

- `claude/helpers/helix-longmemeval.sh:100` — `subprocess.run([os.environ.get("HELIX_PYTHON", "python3"), …])`
- `claude/helpers/helix-reflexion.sh:162` — same pattern.

The bash export from `helix-python.conf` (`export HELIX_PYTHON=…`) propagates to the Python subprocess, so `os.environ.get("HELIX_PYTHON")` returns the detected binary inside the heredoc.

**No behavior change on Linux/macOS**

When `python3` is the real Python (the common case), the detector picks it first and `HELIX_PYTHON=python3` — identical to pre-patch behavior. The fallback `${HELIX_PYTHON:-python3}` keeps the system working even if the conf file is missing.

**Reverting**

```bash
find ~/.claude -name '*.pybak' -exec sh -c 'mv "$0" "${0%.pybak}"' {} \;
rm ~/.claude/helix-python.conf
```

---

### v3.14.1 — 2026-05-04 · README reorganization (docs only)

Documentation-only patch. No code changes. Brings the README in line with the actual state of the system after v3.14.0:

- **Numerical fixes**: 27 → **28 evolved agents** (includes 7 new `council-*` roles), 28 → **35 reusable skills**.
- **Honesty fixes**: Layer 3 (Agent Teams) marked as **NOT IMPLEMENTED** instead of presented as functional. Layer 2 marked as "trigger active, orchestrator pending" — the `claude-flow` MCP path is deprecated by D1'.
- **Dialogue Protocol**: was 7 outdated rules → now 12 real rules from `CLAUDE.md` (initial analysis, bitácora, alerta, requirement intake, auto-economy by signal, mandatory parallelism, auto-close, resume opt-in).
- **New documented sections** for features that existed in code but not in the README:
  - **Helix Council v1.0** — 7-agent decision protocol with constitution + immutable audit logs.
  - **HSL v1** — Helix Security Layer (6 layers active).
  - **TRANCH 2** — M1 helix-judge, M2 passive-capture, M3 project-consolidate, R1 route-recommend, R2 cost-tracker, SEC1 aidefence, SEC2 egress-audit.
  - **Compression Systems** — HELIX-LANG v2 (58.7% output savings), HELIX-DISTILL, HELIX-SPEAK.
  - **HELIX_ROLE creator vs user** (plan v4 D4).
  - **FASE 9 HW-aware** policy gate for Layer 0.
  - **Layer 0 manual override** slash commands (`/helix_desactiva_CAPA0` + `/helix_activa_CAPA0`).
  - **`/helix-actualiza`** maintenance command.
- **Legacy section reorganized**: RuFlo V3 / helix-engine moved under a single collapsed `<details>` block at the end. `claude-flow` MCP removed from Required MCPs.
- **Structure tree updated** with all new helpers (capa0-toggle, hwprobe, judge, passive-capture, project-consolidate, route-recommend, cost-rollup, aidefence, egress-audit, statusline) and the new `tests/` directory.

Net README change: +225 lines, no information removed (legacy preserved, rephrased as deprecated).

---

### v3.14.0 — 2026-05-04 · Blocking prereqs + Layer 0 manual override + TRANCH 1+2 sync

Catches the repo up with three sessions of work that lived only in `~/.claude/`. Two new user-facing features (FASE 6 OPCIÓN E + Layer 0 manual disable) plus the helpers from TRANCH 1+2 (council-decided plan v4) that were never committed.

**`scripts/check-prereqs.sh` v2 — blocking prerequisites with grouped copy-paste output**
- Promoted to **Required (FAIL)**: Docker (binary + active daemon), Ollama, zstd, Claude Code CLI. Previously WARN-only or unchecked.
- Promoted to Recommended (WARN): `nomic-embed-text` model.
- New OS detection: only Ubuntu/Debian/WSL with `apt-get` in v1. macOS/Fedora/Arch fail early with pointer to `claude/memory/topics/install-os-support.md`.
- Output reorganized: instead of scattered messages, a single grouped copy-paste block with only the commands you actually need (apt packages consolidated into one `apt-get install`, Docker block, Ollama block, model pulls block, etc.). Numbered steps in dependency order (apt → node → docker → ollama → claude CLI → models).
- Solves the previous failure mode: `install_on_wsl.sh` proceeded with broken state when Docker or Ollama were missing.
- Smoke test: `tests/test-check-prereqs.sh` — 24 assertions across 8 scenarios (PATH-shadowed binaries to simulate missing deps).

**Layer 0 manual override — for users with limited HW**
- `/helix_desactiva_CAPA0` and `/helix_activa_CAPA0` slash commands. The disable command **asks the user** whether to apply it to the current session only or persistently across sessions.
- `claude/helpers/helix-capa0-toggle.sh` — `off --session | off --persistent | on | status`. Writes `~/.claude/capa0-disabled` with YAML metadata (mode, created_at).
- `claude/helpers/helix-capa0-policy.sh` — early check that wins over the HW heuristic. The override applies via the file, the env var `HELIX_CAPA0_DISABLED=1`, or both.
- `session-end.sh` — auto-cleanup of `mode:session` overrides at session close. `mode:persistent` survives.
- Default: Layer 0 stays **enabled by default** based on detected HW (FASE 9). The override only disables — it never forces enable.
- Smoke test: `tests/test-capa0-toggle.sh` — 19 assertions across 9 scenarios (env var, file, modes, errors).

**TRANCH 1 + TRANCH 2 helpers — sync from sessions #20-#21**

These were council-approved (plan v4, Helix Council #1, 2026-05-04) and implemented in `~/.claude/` but never committed. v3.14.0 brings them into the repo so `install_on_wsl.sh` actually deploys them on a fresh machine.

- **FASE 9 HW-aware** (`helix-hwprobe.sh`, `helix-capa0-policy.sh`, `helix-bench-capa0.sh`, `helix-models-suggest.sh`) — CPU/RAM/GPU detection, ON/OPT_IN/OFF policy by tier, empirical bench overrides heuristic.
- **FASE 0.5 statusline** (`helix-statusline.sh`) — bash replacement for the 742-line RuFlo CJS statusline. <200ms p99.
- **D1' multi-domain trigger** (`helix-multidomain-trigger.py/sh`) — PreToolUse(Agent) hook detecting 2+ domain intent, advisory-only.
- **M1 helix-judge** (`helix-judge.py`) — LLM-as-judge for semantic conflicts. Ollama backend (`llama3.2:3b` default). Static few-shot prompt (anti-poisoning hard rule). Confidence ≥0.85, 100% audit log.
- **M2 passive-capture** (`passive-capture-hook.py/sh`, `passive-capture-review.sh`) — PostToolUse hook detecting non-trivial decisions during edits. Three-bucket JSONL (pending/approved/rejected). Review tool requires explicit approve/reject.
- **M3 helix-project-consolidate** (`helix-project-consolidate.py`) — fuzzy-matched name drift detection across helpers/skills/agents/topics. Threshold env var `HELIX_M3_FUZZY_THRESHOLD` (default 0.75). Interactive unify only with explicit confirmation.
- **R1 helix-route-recommend** (`helix-route-recommend.py`, `helix-route-cost-audit.py`) — model recommendation advisor (Opus/Sonnet/Haiku) by domain. **Read-only** — never modifies `settings.json`. Override via `HELIX_FORCE_MODEL`. Kill switch `HELIX_R1_ENABLED=0`.
- **R2 helix-cost-tracker** (`helix-cost-rollup.sh`) — real USD cost from JSONL transcripts using Anthropic Nov 2025 pricing. Modes: current/session/all/report. Wired to statusline 💰 slot.
- **SEC1 helix-aidefence** (`helix-aidefence-hook.py/sh`) — PostToolUse PII redactor on Helix-internal logs (10 PII types: EMAIL, PHONE, SSN, IBAN, IPV4/6, CREDIT_CARD-Luhn, PATH_USERNAME, URL_USERINFO). Redact-no-block.
- **SEC2 helix-egress-audit** (`helix-egress-audit-hook.py/sh`, `helix-egress-report.sh`) — PostToolUse audit on WebFetch/WebSearch/MCP. Logs domain + sanitized query. First-seen domain alert + spike detection.

**`tests/` — repo-versioned smoke tests (new directory)**
- `test-capa0-toggle.sh` — 19/19 PASS
- `test-check-prereqs.sh` — 24/24 PASS

**Documentation**
- `claude/memory/topics/install-os-support.md` — OS support matrix + manual install commands for macOS, Fedora/RHEL, Arch.
- `claude/memory/topics/fase-6-installer-decision.md` — council #4 decision record (4 options, OPTION E selected).
- 18 additional bench/decision topics from TRANCH 1+2 (M1-M3, R1, SEC1-2, B-gates, council design, FASE 9 HW-aware, statusline v0.1, plan v4 completed).

**Privacy fixes**
- Removed two hardcoded user paths (`/home/lfrontuso/`) from `passive-capture-review.sh` and `helix-cost-rollup.sh`. Replaced with `os.path.expanduser('~/')` and dynamic prefix from `HOME`.

**Migration notes**
- After `git pull`, run `bash update.sh` to copy the new helpers into `~/.claude/`.
- Existing installs: Capa 0 keeps its current behavior. New slash commands available immediately after sync.
- New installs on machines without Docker or Ollama: `check-prereqs.sh` will block and print exactly what to run.

---

### v3.13.0 — 2026-04-27 · Project stack manifest + anti-bias routing + conversation persistence

Seven coordinated changes addressing real measured pain: 24 of 35 agents never invoked, top-3 capturing 72% of routing decisions, no recovery path after WSL2 crashes, false promises in CLAUDE.md about Capa 3 implementation status.

**`skills/helix-stack/` — declarative agent stack per project**
- `helix-stack.sh detect` auto-classifies project tier (small / medium / large) from file count, LOC, presence of CI / tests / IaC.
- Manifest at `<project>/.claude/memory/helix-stack.md` declares `core` (tech-aligned agents) and `extended` (cross-cutting roles: security, qa, ba, devops, monitoring) with mode `technical | extended | custom`.
- Subcommands: `detect | init | show | add | remove | promote | auto-promote-check | suggest-agents | create-suggested`.
- Universal base injected in every project (independent of language): `error-detective`, `code-reviewer`, `architect-reviewer` — process agents, not domain.

**`memory/topics/specialized-agents-catalog.json` — extensible 60+ agent catalog**
- Seven categories (`languages`, `frameworks`, `domains`, `infrastructure`, `blockchain`, `specialized`, `compliance`) with 60+ entries.
- Nine signal types: `files`, `dirs`, `manifest`, `deps_python`, `deps_node`, `deps_ruby`, `deps_elixir`, `deps_rust`, `deps_go`, `keywords_in_readme`.
- `helix-stack suggest-agents` walks the catalog, evaluates signals against the project, reports any specialized agent that would help but is missing. Examples validated end-to-end: Rust + actix → `rust-pro` + `actix-pro`; PyTorch + LangChain + HuggingFace → 3 expert suggestions; Terraform + Helm + k8s → 3 infra experts; Solidity + ethers → blockchain stack; HIPAA keywords in README → compliance agent.
- Extensible without touching code — add a JSON entry, the helper picks it up next run.

**`skills/helix-route/` — anti-bias routing with multi-criteria scoring**
- Replaces bare vector search with `score = 0.50·similarity + 0.20·freshness + 0.15·skill_quality + 0.15·stack_match`.
- Hard filter by domain catalog (testing → only `qa-expert`/`test-engineer`/`test-automator`) eliminates the structural drift detected by ERL.
- Freshness bonus = `1 / (1 + log(invocations_30d + 1))` — agents never invoked get the maximum boost.
- Epsilon-greedy exploration: 10% of picks ignore best score and pick randomly within `score ≥ 0.7·best_score` cohort. Diversification cements organically as exploration produces feedback.
- Subcommands: `pick | audit | shadow-report | weights`. `--shadow` flag enables dry-run mode with a one-week shadow log to validate before activating the hook layer.
- `helpers/helix-metricas.sh` gains a fourth dimension `routing` reporting `top3_saturation`, `coverage_ratio`, `never_used_count`, `stack_coverage`. Score routing surfaces real bias measurably.

**`skills/helix-snapshot/` — conversation persistence (Fase 1)**
- YAML snapshots at `~/.claude/snapshots/<project>/<ts>.yaml` with `chmod 600` and a project `.gitignore` that excludes everything but the README.
- Subcommands: `capture` (stdin YAML), `resume`, `list`, `show`, `archive` (>7d), `prune` (>30d), `stale-check` (>24h or git commits posterior).
- `session-start.sh` injects `[HELIX-SUGGEST-RESUME]` flag when a recent snapshot exists. CLAUDE.md rule #12 mandates opt-in: never auto-load to context — always ask the user (1) resume, (2) new chat, (3) view detail.
- 100% local, no egress, no paid services, no vendor lock. Stack: YAML files + existing Qdrant + existing Ollama. Mem0 OSS evaluated and deferred to a future phase if the simple build proves insufficient.
- Companion research dump in `memory/topics/conversation-context-research.md` covers Helix internals, LongMemEval (ICLR 2025), Mem0 paper (arXiv 2504.19413), compaction strategies (observation masking, structured summary, ACON), Anthropic prompt caching 2026.

**`helpers/helix-lang-trigger-hook.sh` — auto-suggest HELIX-LANG on long prompts**
- PreToolUse(Agent) hook fires when invoking the `Agent` tool with a prompt ≥500 tokens of natural prose without HELIX-LANG markers (`A:`, `S:`, `T:`, `R:`, `H:`).
- Suggestion goes to stderr (non-blocking, `exit 0`) with estimated savings (`~58.7%` measured by the bench).
- Resolves a design failure: the rule "use HELIX-LANG on large agent prompts" only worked if I remembered to follow it. Now the harness fires it independently of memory.

**HELIX-LANG restored** (was deprecated 2026-04-18 prematurely)
- Decommissioning rationale was "zero real usage post-benchmarks" — but that reflected my own neglect to use it, not protocol failure.
- The bench measures 58.7% real token compression on output (output never hits the prompt cache, so savings are direct cost).
- Anthropic prompt caching covers 90% of input redundancy; HELIX-LANG covers what cache cannot — they are complementary, not competitors.
- Skill restored to `skills/helix-lang/`, helpers to `helpers/helix-lang-{state,bench}.sh`.

**Capa 3 honesty fix + drift cleanup**
- CLAUDE.md previously claimed "Agent Teams natively enabled in settings.json" — verification showed mailbox/teammates dirs absent, `TaskCreated` hook unregistered, 0 swarm/team invocations in 30 days. Now reads "NO IMPLEMENTADO" with pointer to `topics/agent-teams-status.md` documenting actual state and minimum implementation plan.
- `agents-index.md` had 12 entries pointing to nonexistent files. After cleanup: 26 entries match 26 files exactly. `architect-review.md` renamed to `architect-reviewer.md` (typo confirmed by frontmatter). 10 orphan context files marked `status: preserved` — `helpers/helix-agents-audit.sh` now distinguishes accidental from intentional orphans.

**Housekeeping helpers**
- `helpers/helix-claude-md-prune.sh` — auto-archive evolutions older than 14 days when `CLAUDE.md` exceeds threshold 340. Idempotent, dry-run mode, ships archived rows to `topics/evolution-history.md`.
- `helpers/helix-agents-audit.sh` — diff between `agents/*.md`, `agents-index.md`, and `memory/agents/*.md` with four orphan categories. Surfaces drift the staleness check cannot detect (which only watches git, not infrastructure).

---

### v3.12.0 — 2026-04-23 · Research-first agent creation + vector store self-healing

Four changes that tighten how Helix creates experts and keeps its semantic index consistent across machines.

**`skills/agent-create/` — research-first pipeline for new experts**
- Six-phase pipeline: scoping → research (source allowlist) → anti-injection sanitize → synthesize → validate → atomic commit of the three agent files (slim, on-demand, index-row).
- Source allowlist: only official normatives (NIST, OWASP, IETF RFCs, ISO, W3C), vendor docs, peer-reviewed papers, canonical repos, and recognized-author books. No blogs, no AI-generated content, no single-source StackOverflow.
- Anti-injection in research phase reuses Helix Security Layer L1 (`injection-detector-hook`) and adds manual scanners (`</?(system|assistant|user)>`, `ignore previous instructions`, long base64 blobs, invisible Unicode) plus **cross-validation: every principle must appear in ≥3 independent sources** or be discarded.
- Fingerprinting: `memory/agents/<name>.md` includes `## Fuentes` (URL + date + content hash) and `## Metadata` (created_at, last_refresh, invocations). Every expert is re-auditable.
- Validation gate: ≥80% correct on 5–10 domain-specific questions before activation. Below 60% → back to research phase, not more prompt text.
- Refresh cycle: agents with ≥20 invocations in 30 days go through a 90-day re-research of deltas (new CVEs, deprecations, standard updates). Prompt changes require user approval — no auto-merge.
- Rule added to `CLAUDE.md § AGENTES`: never write an agent system prompt without invoking this skill.

**`helpers/agents-vector-sync-hook.sh` — auto-sync of `helix_agents` collection**
- PostToolUse hook on `Write|Edit|MultiEdit` that detects edits to `~/.claude/agents/*.md` or `~/.claude/memory/agents/*.md` and triggers `hv index-agents` in background.
- `flock --nonblock` debounce of 8 s: ten consecutive edits produce a single re-index, not ten.
- Exit 0 immediate, `disown` so the edit workflow never blocks. Graceful skip if Qdrant is down.
- Log: `~/.claude/memory/agents-vector-sync.log`. Manual fallback: `hv index-agents`.

**`install_on_wsl.sh` — bootstrap of vector index on new machines**
- New block after Vector Memory install: deferred background bootstrap that waits up to 180 s for the `nomic-embed-text` pull, verifies Qdrant `/healthz` and model availability, then runs `hv index-agents` + `hv index-memories`.
- Closes the gap where a fresh install left Qdrant running with an empty collection until the user ran `hv sync` manually.
- Idempotent: stable IDs by content hash — re-install does not duplicate points.
- Log: `~/.claude/memory/install-vector-bootstrap.log`. Non-blocking: install finishes immediately.

**`helpers/helix-metricas.sh` — threshold realignment with `health-check.sh`**
- Drift detected: `helix-metricas.sh` flagged `CLAUDE.md` as CRITICAL at >220 lines (limit 180) while `health-check.sh` accepted up to 350 lines. The actual `CLAUDE.md` post-pruning stabilized at 305–329 lines, producing a permanent false positive.
- Thresholds aligned: elevated at 350, critical at 400. Context score now reflects the real post-DISCOVERY-FIRST + Security Layer v1 baseline instead of the pre-prune limit.

---

### v3.11.0 — 2026-04-11 · HELIX-COMPRESS — three-layer token compression system

Three independent compression layers, each targeting a different cost:

**DISTILL — initialization cost** (`helpers/helix-distill.sh`)
- `run`: generates agent-specific slices of CLAUDE.md — only the sections each agent actually needs. Savings: 78–96% per agent, **93% for a 15-agent Layer 2 session** (92,940 → 6,124 tok).
- `compress-project [DIR]`: compresses `helix-*.md` project files (analysis, bitácora, team, backlog, roadmap) with `.original.md` backup.
- `compress-file FILE [task]`: semantic extraction from code files — splits by function/class for `.py/.ts/.js`, by header for `.md`, by keyword ±10 lines for other formats.
- `compress-bitacora FILE [--keep N]`: truncates changelog tables to last N entries with condensation notice. Prevents unbounded growth.
- **4 bugs fixed** in this version: HTML comment markers bleeding into slices (`<!--...-->`), `pipe | python3 <<'HEREDOC'` stdin conflict (heredoc wins → always 0 agents in report), double Python computation with divergent logic (fake 99% savings), `--keep 5` argument parsing (only worked with `--keep=5`).

**S:hash — coordination cost** (`helpers/helix-lang-state.sh` + `skills/helix-lang/`)
- HELIX-LANG v2: universal inter-agent grammar (fixed) + vocabulary declared per session via `vocab` command. Works for any domain: software, research, marketing, support, finance.
- Agents reference shared context as `S:xxxx` (2 tokens) instead of re-sending full state. Measured savings: **~97%** on shared context, ~59% on individual messages.
- Commands: `vocab A:{} D:{}`, `snapshot`, `get`, `delta`, `diff`, `gc`.

**SPEAK — output cost** (`skills/helix-speak/`)
- Situational output compression: AUTO mode selects level by message type. BRIEF for status reports, TERSE for fragments, ULTRA for inter-agent. Never compresses code, security warnings, or destructive confirmations.

**Agent Teams (Layer 3)**
- Peer-to-peer mailbox between agents (Claude Code native, ≥v2.1.32). Already enabled in `settings.json`. Key difference from Layer 2: agents communicate directly, not just report to the lead. Hooks: `TeammateIdle`, `TaskCreated`, `TaskCompleted`.

---

### v3.10.0 — 2026-04-02 · Confidence decay + knowledge map + proactive memory

- **`helpers/helix-decay.sh`** — Confidence decay for evolution-log entries. Score 0-100 = recency×0.4 + importance×0.6 × category multiplier. PERENNIAL patterns (HELIX_MODE, ERL, swarm_init, set -euo pipefail…) never decay. Three modes: `--report`, `--stale`, `--prune` (writes `obsolete.md`). Runs in `session-end`.
- **`helpers/helix-knowledge-map.sh`** — Cross-domain coverage matrix: learnings × heuristics × reflexions × decay score per domain. Criticality weights (seguridad=1.0, arquitectura=0.9…) amplify gap urgency. Critical gap = high-weight domain with coverage <30%. Runs in `session-end --gaps`.
- **`session-start.sh`** — Proactive Qdrant retrieval at session start: auto-detects project stack (Python/React/Docker), queries `helix_reflexions` for relevant resolved errors, surfaces them as "🧠 Memorias relevantes para este proyecto" before first task.
- **`session-end.sh`** — Integrated decay + knowledge map into session close pipeline.

---

### v3.9.0 — 2026-04-02 · Closed routing loop

- **`helpers/skill-tracker-hook.sh`** — PostToolUse hook on `Skill`: every skill invocation auto-logs to `skill-usage.jsonl`. `agent-routing-hook.sh` also writes there now. Skill tracker is live from this version.
- **`helpers/helix-expel.sh`** — ExpeL contrastive analysis: detects dominance patterns, routing mismatches (used ≠ catalog ideal), out-of-catalog agents, temporal routing evolution. Runs after ERL in retrospectiva.
- **`helpers/helix-routing-fix.sh`** — Auto-correction of `agents-index.md` from ERL+ExpeL output. First real corrections: `testing → test-engineer`, `devops → devops-engineer` flagged in triggers.
- **`settings.json`** — New PostToolUse hook on `Skill` matcher.
- **`agents-index.md`** — `★` routing corrections from ExpeL. Note: `researcher`/`general-purpose` are internal Claude Code types, not Helix agents.

---

### v3.8.0 — 2026-04-02 · Self-learning memory system

- **`helpers/helix-erl.sh`** — ERL (Experiential Reflective Learning): analyzes `routing-feedback.jsonl`, extracts domain heuristics + frequent agent pairs + project patterns + catalog gaps → `routing-heuristics.md`. Auto-runs weekly from retrospectiva.
- **`helpers/helix-reflexion.sh`** — Semantic error memory: stores resolved errors in Qdrant (`helix_reflexions`), retrieves by cosine similarity. Store + search + list. Backup in `reflexions.jsonl`.
- **`helpers/skill-tracker.sh`** — Real usage log for skills and agents: `skill-usage.jsonl`. `report` shows top-N with bars + never-used. `prune --dry-run` suggests archive candidates.
- **`helpers/helix-retrospectiva.sh` v2** — Now integrates: ERL trigger (weekly), gap analysis (session domains vs documented heuristics), reflexion suggestion (when resolved errors detected in summary).
- **`compress_logic.py` v2** — ACON-style importance scoring (0–1) for archiving decisions. Anchor sections (SECURITY, OPERABILITY, SKILLS_INDEX) are immune to compression. High-value patterns (`set -euo pipefail`, `swarm_init`, `HELIX_MODE`) score >0.8 and are never archived.
- **CLAUDE.md markers** — Added 7 missing structural markers: METRICS, SESSIONS, SECURITY, OPERABILITY, SKILLS_INDEX, RISK_MAP, REASONING. `health-check.sh` now passes 100% integrity.
- **21 cross-project evolutions** registered (up from 16).

---

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
