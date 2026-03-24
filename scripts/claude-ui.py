#!/usr/bin/env python3
"""
claude-ui.py — TUI para Claude Flow V3  ·  Visual Edition
"""
from __future__ import annotations

import datetime
import random
import subprocess
from typing import ClassVar

import psutil
from textual import on
from textual.app import App, ComposeResult
from textual.containers import Horizontal, Vertical
from textual.widgets import Input, RichLog, Static

# ── Catppuccin Mocha ─────────────────────────────────────────
BG      = "#1e1e2e"
SURFACE = "#181825"
OVERLAY = "#313244"
BLUE    = "#89b4fa"
PURPLE  = "#cba6f7"
GREEN   = "#a6e3a1"
YELLOW  = "#f9e2af"
RED     = "#f38ba8"
MUTED   = "#585b70"
TEXT    = "#cdd6f4"
SUB     = "#a6adc8"
TEAL    = "#94e2d5"
PINK    = "#f5c2e7"

# ── Helpers ───────────────────────────────────────────────────

def git_branch() -> str:
    try:
        r = subprocess.run(
            ["git", "rev-parse", "--abbrev-ref", "HEAD"],
            capture_output=True, text=True, timeout=2,
        )
        return r.stdout.strip() or "—"
    except Exception:
        return "—"


def git_diff_stat() -> str:
    try:
        r = subprocess.run(["git", "diff", "--stat"],
                           capture_output=True, text=True, timeout=2)
        if r.stdout.strip():
            return r.stdout.strip()
        r2 = subprocess.run(
            ["git", "log", "--name-only", "--pretty=format:", "-n", "3"],
            capture_output=True, text=True, timeout=2,
        )
        lines = [ln for ln in r2.stdout.strip().split("\n") if ln.strip()]
        return "\n".join(lines[:5]) if lines else "sin cambios recientes"
    except Exception:
        return "no es repo git"


def bar(pct: int, width: int = 10) -> str:
    """Barra con degradado de color basado en porcentaje."""
    filled = round(pct / 100 * width)
    empty  = width - filled
    if pct >= 80:
        fill_char = f"[{GREEN}]█[/]"
    elif pct >= 50:
        fill_char = f"[{BLUE}]█[/]"
    else:
        fill_char = f"[{YELLOW}]█[/]"
    return fill_char * filled + f"[{MUTED}]░[/]" * empty


def spinner_frame(t: int) -> str:
    return ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"][t % 10]


def pulse_dot(t: int) -> str:
    return ["●", "◉", "○", "◉"][t % 4]


# ── Mensajes de ejemplo ───────────────────────────────────────

CLAUDE_MSGS = [
    ("tool",    "bash",       "git diff --stat HEAD~1"),
    ("result",  None,         "3 files changed, 47 insertions(+), 12 deletions(-)"),
    ("tool",    "read_file",  "src/domain/evaluation.py"),
    ("think",   None,         "Analizando bounded contexts del dominio..."),
    ("tool",    "edit_file",  "src/domain/evaluation.py"),
    ("result",  None,         "✓ Agregado método validate_score()"),
    ("tool",    "bash",       "python -m pytest tests/ -x -q"),
    ("result",  None,         "12 passed, 0 failed in 1.3s"),
    ("think",   None,         "Revisando schema de migrations pendientes..."),
    ("tool",    "bash",       "alembic upgrade head"),
    ("result",  None,         "Running upgrade → 0012_add_plan_fields"),
    ("warn",    None,         "CVDocument.score puede ser NULL en datos legacy"),
    ("tool",    "write_file", "src/migrations/0013_fix_score.py"),
    ("result",  None,         "✓ Migration creada correctamente"),
]


# ── Widgets ───────────────────────────────────────────────────

class HeaderWidget(Static):
    _tick_count: int = 0

    def __init__(self, **kw):
        self._branch = git_branch()
        cpu = psutil.cpu_percent(interval=None)
        ram = psutil.virtual_memory().used // (1024 * 1024)
        super().__init__(self._mk(cpu, ram), **kw)

    def on_mount(self) -> None:
        self.set_interval(1, self._update)

    def _update(self) -> None:
        self._tick_count += 1
        cpu = psutil.cpu_percent(interval=None)
        ram = psutil.virtual_memory().used // (1024 * 1024)
        self.update(self._mk(cpu, ram))

    def _mk(self, cpu: float, ram: int) -> str:
        now    = datetime.datetime.now().strftime("%H:%M:%S")
        cpu_c  = GREEN if cpu < 50 else (YELLOW if cpu < 80 else RED)
        mem    = psutil.virtual_memory()
        mem_pct = int(mem.percent)
        mem_c  = GREEN if mem_pct < 60 else (YELLOW if mem_pct < 80 else RED)
        pdot   = pulse_dot(self._tick_count)
        spin   = spinner_frame(self._tick_count)

        return (
            f"[bold {BLUE}]▊[/] [bold {TEXT}]Claude Flow V3[/]  "
            f"[{PURPLE}]{pdot} session[/]  "
            f"[{MUTED}]⎇[/] [{TEAL}]{self._branch}[/]  "
            f"[{MUTED}]│[/]  [{SUB}]claude-sonnet-4-6[/]  "
            f"[bold {BLUE}]{now}[/]\n"
            f"[{MUTED}]{'━' * 72}[/]\n"
            f"  [{YELLOW}]🏗️  DDD[/] [{BLUE}]❶❷○○○[/] [bold {SUB}]2/5 domains[/]  "
            f"[{MUTED}]│[/]  [{MUTED}]⚡[/] [{GREEN}]1.0x[/] [{MUTED}]→[/] [bold {GREEN}]2.49x[/]  "
            f"[{MUTED}]│[/]  [{MUTED}]agents[/] [{PURPLE}]◉ 2/15[/]  "
            f"[{MUTED}]│[/]  [{RED}]🔴 CVE 0[/]\n"
            f"  [{MUTED}]CPU[/] [{cpu_c}]{'█' * int(cpu / 10)}{'░' * (10 - int(cpu / 10))}[/] [{cpu_c}]{cpu:4.1f}%[/]  "
            f"[{MUTED}]RAM[/] [{mem_c}]{'█' * int(mem_pct / 10)}{'░' * (10 - int(mem_pct / 10))}[/] [{mem_c}]{ram}MB[/]  "
            f"[{MUTED}]│[/]  "
            f"[{MUTED}]arch[/] [{GREEN}]●DDD[/]  [{MUTED}]sec[/] [{YELLOW}]●PENDING[/]  [{MUTED}]mem[/] [{BLUE}]●AgentDB[/]  "
            f"[{MUTED}]{spin}[/]"
        )


def _fmt_claude_line(kind: str, tool: str | None, msg: str, t: int) -> str:
    if kind == "tool":
        return (
            f"  [{BLUE}]▶[/] [{MUTED}]tool[/] [{TEAL}]{tool}[/] "
            f"[{OVERLAY}]▸[/] [{SUB}]{msg}[/]"
        )
    elif kind == "result":
        return f"  [{GREEN}]✓[/] [{TEXT}]{msg}[/]"
    elif kind == "think":
        return f"  [{YELLOW}]{spinner_frame(t)}[/] [{MUTED}]{msg}[/]"
    elif kind == "warn":
        return f"  [{YELLOW}]⚠[/] [{YELLOW}]{msg}[/]"
    else:
        return f"  [{MUTED}]{msg}[/]"


class AgentPanel(Static):
    def __init__(self, label: str, tool: str, pct_init: int,
                 tokens: str, role: str, error: str | None = None, **kw):
        self._label  = label
        self._tool   = tool
        self._pct    = pct_init
        self._tokens = tokens
        self._role   = role
        self._error  = error
        self._color  = BLUE if "A" in label else PURPLE
        self._t      = 0
        super().__init__(self._mk(), **kw)

    def on_mount(self) -> None:
        self.set_interval(0.8, self._tick)

    def _tick(self) -> None:
        self._t += 1
        if self._pct < 95:
            self._pct = min(95, self._pct + random.randint(0, 2))
        self.update(self._mk())

    def _mk(self) -> str:
        c   = self._color
        b   = bar(self._pct)
        sp  = spinner_frame(self._t) if self._pct < 95 else "✓"
        sp_c = YELLOW if self._pct < 95 else GREEN
        err = f"\n  [{RED}]╰─ ! {self._error}[/]" if self._error else ""
        return (
            f"[bold {c}]⬡ {self._label}[/]  [{MUTED}]{self._role}[/]\n"
            f"  [{sp_c}]{sp}[/] [{MUTED}]tool[/] [{TEAL}]{self._tool}[/]\n"
            f"  {b} [{bold_pct_color(self._pct)}]{self._pct}%[/]\n"
            f"  [{MUTED}]tokens[/] [{SUB}]{self._tokens}[/]"
            f"{err}"
        )


def bold_pct_color(pct: int) -> str:
    if pct >= 80: return f"bold {GREEN}"
    if pct >= 50: return f"bold {BLUE}"
    return f"bold {YELLOW}"


class EditorPanel(Static):
    def __init__(self, **kw):
        self._diff = git_diff_stat()
        self._t    = 0
        super().__init__(self._mk(), **kw)

    def on_mount(self) -> None:
        self.set_interval(5, self._tick)

    def _tick(self) -> None:
        self._t   += 1
        self._diff = git_diff_stat()
        self.update(self._mk())

    def _mk(self) -> str:
        lines = self._diff.split("\n")[:6]
        rows  = []
        for ln in lines:
            if "+" in ln and "|" in ln:
                rows.append(f"  [{GREEN}]+[/] [{SUB}]{ln.strip()}[/]")
            elif "-" in ln and "|" in ln:
                rows.append(f"  [{RED}]-[/] [{SUB}]{ln.strip()}[/]")
            else:
                rows.append(f"  [{MUTED}]{ln.strip()}[/]")
        body = "\n".join(rows) or f"  [{MUTED}]working tree clean[/]"
        return (
            f"[bold {GREEN}]⬡ editor[/]  [{MUTED}]nvim · git diff[/]\n"
            f"[{MUTED}]  ─────────────────────[/]\n"
            f"{body}"
        )


class MonitorPanel(Static):
    def __init__(self, **kw):
        self._a     = 70
        self._b     = 45
        self._tok   = 39000
        self._alert = "B: mock fallido"
        self._t     = 0
        super().__init__(self._mk(), **kw)

    def on_mount(self) -> None:
        self.set_interval(1.5, self._tick)

    def _tick(self) -> None:
        self._t  += 1
        self._a   = min(99, self._a + random.randint(0, 2))
        self._b   = min(99, self._b + random.randint(0, 2))
        self._tok = min(200000, self._tok + random.randint(200, 800))
        if random.random() < 0.04:
            self._alert = "" if self._alert else "B: mock fallido"
        self.update(self._mk())

    def _procs(self) -> list[str]:
        out = []
        for p in psutil.process_iter(["name", "cmdline", "cpu_percent"]):
            try:
                cmd = " ".join(p.info["cmdline"] or [])
                if "claude" in cmd.lower():
                    out.append((p.info["name"][:12], p.info["cpu_percent"]))
            except Exception:
                pass
        return out[:2]

    def _mk(self) -> str:
        tk_pct  = int(self._tok / 200000 * 100)
        procs   = self._procs()
        sp      = pulse_dot(self._t)
        sp_c    = GREEN if not self._alert else YELLOW
        proc_lines = (
            "\n".join(
                f"  [{MUTED}]proc[/] [{TEAL}]{n:<12}[/] [{BLUE}]{c:.1f}%[/]"
                for n, c in procs
            ) if procs else f"  [{MUTED}]no claude procs[/]"
        )
        alert = (
            f"\n  [{RED}]╰─ ⚠ {self._alert}[/]" if self._alert else ""
        )
        return (
            f"[bold {PURPLE}]⬡ monitor[/]  [{sp_c}]{sp}[/] [bold {SUB}]live[/]\n"
            f"[{MUTED}]  ─────────────────────[/]\n"
            f"  [{BLUE}]A backend [/] {bar(self._a, 8)} [{bold_pct_color(self._a)}]{self._a}%[/]\n"
            f"  [{PURPLE}]B frontend[/] {bar(self._b, 8)} [{bold_pct_color(self._b)}]{self._b}%[/]\n"
            f"[{MUTED}]  ─────────────────────[/]\n"
            f"  [{MUTED}]tokens[/] [{SUB}]{self._tok // 1000}k[/][{MUTED}]/200k[/] "
            f"{bar(tk_pct, 6)}\n"
            f"{proc_lines}{alert}"
        )


# ── App ───────────────────────────────────────────────────────

CSS = f"""
Screen {{
    background: {BG};
    layers: base;
}}

/* ── Header ── */
HeaderWidget {{
    height: 5;
    background: {SURFACE};
    border-bottom: heavy {OVERLAY};
    padding: 0 2;
    color: {TEXT};
}}

/* ── Layout ── */
#main-grid {{
    layout: horizontal;
    height: 1fr;
}}

#left-col {{
    width: 58%;
    layout: vertical;
    border-right: solid {OVERLAY};
}}

#center-col {{
    width: 21%;
    layout: vertical;
    border-right: solid {OVERLAY};
}}

#right-col {{
    width: 21%;
    layout: vertical;
}}

/* ── Columna izquierda: 2 secciones ── */
#claude-output {{
    height: 65%;
    background: {BG};
    border-bottom: dashed {OVERLAY};
    padding: 0 1;
}}

#chat-section {{
    height: 35%;
    background: {SURFACE};
    layout: vertical;
    padding: 0 1;
}}

#chat-log {{
    height: 1fr;
    background: {SURFACE};
    padding: 0;
}}

#chat-input-row {{
    height: 3;
    layout: horizontal;
    background: {SURFACE};
}}

#chat-prefix {{
    width: 5;
    height: 3;
    content-align: left middle;
    color: {PURPLE};
    background: {SURFACE};
    padding: 1 0 0 0;
}}

#chat-input {{
    height: 1;
    background: {BG};
    border: round {PURPLE};
    color: {TEXT};
    width: 1fr;
    margin: 1 0;
    padding: 0 1;
}}

#chat-input:focus {{
    border: round {BLUE};
}}

/* ── Paneles derecha ── */
AgentPanel {{
    height: 50%;
    background: {BG};
    border: round {OVERLAY};
    padding: 0 1;
    margin: 0;
}}

#agent-a {{
    border: round {BLUE};
}}

#agent-b {{
    border: round {PURPLE};
}}

EditorPanel {{
    height: 50%;
    background: {SURFACE};
    border: round {GREEN};
    padding: 0 1;
}}

MonitorPanel {{
    height: 50%;
    background: {SURFACE};
    border: round {PURPLE};
    padding: 0 1;
}}
"""


class ClaudeUI(App):
    CSS = CSS
    BINDINGS: ClassVar = [
        ("ctrl+c", "quit", "Salir"),
        ("escape", "clear_input", "Cancelar"),
    ]

    _history: list[str] = []
    _hist_idx: int      = -1
    _claude_t: int      = 0

    def compose(self) -> ComposeResult:
        yield HeaderWidget()
        with Horizontal(id="main-grid"):
            # ── Columna izquierda ──────────────────────────────
            with Vertical(id="left-col"):
                # 65%: output de Claude Code (read-only)
                yield RichLog(id="claude-output", markup=True,
                              highlight=False, auto_scroll=True)
                # 35%: chat con Helix
                with Vertical(id="chat-section"):
                    yield RichLog(id="chat-log", markup=True,
                                  highlight=False, auto_scroll=True)
                    with Horizontal(id="chat-input-row"):
                        yield Static(f"[{PURPLE}]▌[/]", id="chat-prefix")
                        yield Input(placeholder="mensaje a helix...",
                                    id="chat-input")
            # ── Columna centro ────────────────────────────────
            with Vertical(id="center-col"):
                yield AgentPanel("agente A", "bash",      70, "11.3k",
                                 "backend", id="agent-a")
                yield EditorPanel(id="editor")
            # ── Columna derecha ───────────────────────────────
            with Vertical(id="right-col"):
                yield AgentPanel("agente B", "edit_file", 45, "8.7k",
                                 "frontend", error="retry 2/3", id="agent-b")
                yield MonitorPanel(id="monitor")

    def on_mount(self) -> None:
        self._seed_claude_log()
        self._seed_chat_log()
        self.query_one("#chat-input", Input).focus()
        self.set_interval(3, self._auto_claude_msg)

        # Títulos de borde
        self.query_one("#claude-output").border_title = (
            f"  ⬡ claude output  ·  tool calls  "
        )
        self.query_one("#chat-section").border_title = (
            "  💬 chat  "
        )
        self.query_one("#agent-a").border_title = "  ⬡ agente A [backend]  "
        self.query_one("#agent-b").border_title = "  ⬡ agente B [frontend]  "
        self.query_one("#editor").border_title  = "  ⬡ nvim · diff  "
        self.query_one("#monitor").border_title = "  ⬡ monitor · live  "

    def _seed_claude_log(self) -> None:
        log = self.query_one("#claude-output", RichLog)
        log.write(
            f"[bold {BLUE}]Claude Flow V3[/]  "
            f"[{MUTED}]session iniciada[/]  "
            f"[{PURPLE}]◉ 2 agents activos[/]"
        )
        log.write(f"[{MUTED}]{'━' * 52}[/]")
        for i, (kind, tool, msg) in enumerate(CLAUDE_MSGS):
            log.write(_fmt_claude_line(kind, tool, msg, i))
        log.write(f"[{MUTED}]{'━' * 52}[/]")
        log.write(f"[{YELLOW}]⠋[/] [{MUTED}]esperando siguiente tarea...[/]")

    def _seed_chat_log(self) -> None:
        log = self.query_one("#chat-log", RichLog)
        log.write(f"[{MUTED}]Helix listo. Escribí tu instrucción abajo.[/]")

    def _auto_claude_msg(self) -> None:
        self._claude_t += 1
        kind, tool, msg = random.choice(CLAUDE_MSGS)
        self.query_one("#claude-output", RichLog).write(
            _fmt_claude_line(kind, tool, msg, self._claude_t)
        )

    @on(Input.Submitted, "#chat-input")
    def handle_submit(self, event: Input.Submitted) -> None:
        text = event.value.strip()
        if not text:
            return
        self._history.append(text)
        self._hist_idx = len(self._history)

        chat = self.query_one("#chat-log", RichLog)
        chat.write(f"[bold {PURPLE}]▌ vos[/]  [{TEXT}]{text}[/]")
        # Respuesta simulada de Helix
        chat.write(
            f"[{MUTED}]  ╰─[/] [{GREEN}]entendido, procesando...[/]"
        )
        event.input.value = ""

    def on_key(self, event) -> None:
        inp = self.query_one("#chat-input", Input)
        if event.key == "up" and self._history and self._hist_idx > 0:
            self._hist_idx -= 1
            inp.value = self._history[self._hist_idx]
            inp.cursor_position = len(inp.value)
        elif event.key == "down":
            if self._hist_idx < len(self._history) - 1:
                self._hist_idx += 1
                inp.value = self._history[self._hist_idx]
                inp.cursor_position = len(inp.value)
            else:
                self._hist_idx = len(self._history)
                inp.value = ""

    def action_clear_input(self) -> None:
        self.query_one("#chat-input", Input).value = ""

    def action_quit(self) -> None:
        self.exit()


if __name__ == "__main__":
    ClaudeUI().run()
