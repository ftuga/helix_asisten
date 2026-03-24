#!/usr/bin/env python3
"""
claude-ui.py — TUI para Claude Flow V3
Layout: header + 3 columnas + input fijo
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
        return "\n".join(lines[:6]) if lines else "sin cambios recientes"
    except Exception:
        return "no es repo git"


def bar(pct: int, width: int = 8) -> str:
    filled = round(pct / 100 * width)
    return "█" * filled + "░" * (width - filled)


# ── Mensajes de ejemplo ───────────────────────────────────────

MSGS = [
    ("✓", GREEN,  "Analizando arquitectura DDD del proyecto..."),
    ("⠸", YELLOW, "Cargando contexto de bounded contexts..."),
    ("✓", GREEN,  "Dominio: evaluador_cv identificado"),
    ("✓", GREEN,  "Entidades: Evaluation, CVDocument, Client"),
    ("⠸", YELLOW, "Generando plan de implementación..."),
    ("✓", GREEN,  "Plan listo: 5 fases, 15 tareas"),
    ("⠸", YELLOW, "agente-A: analizando schemas PostgreSQL..."),
    ("⠸", YELLOW, "agente-B: preparando componentes frontend..."),
    ("✓", GREEN,  "Schema PostgreSQL validado"),
    ("✗", RED,    "agente-B: lint error en EvaluationCard.tsx"),
    ("⠸", YELLOW, "agente-B: aplicando fix automático..."),
    ("✓", GREEN,  "agente-B: fix aplicado, retry 2/3"),
    ("⠸", YELLOW, "Ejecutando migraciones pendientes..."),
    ("✓", GREEN,  "Migration 0012_add_plan_fields completada"),
]


# ── Widgets ───────────────────────────────────────────────────

def _header_markup(branch: str, cpu: float, ram: int) -> str:
    now   = datetime.datetime.now().strftime("%H:%M")
    cpu_c = GREEN if cpu < 60 else (YELLOW if cpu < 85 else RED)
    return (
        f"[bold {BLUE}]▊ Claude Flow V3[/]  "
        f"[{PURPLE}]● session[/]  "
        f"[{MUTED}]⎇[/] [{SUB}]{branch}[/]  "
        f"[{MUTED}]│[/]  [{SUB}]Sonnet 4[/]  [{MUTED}]{now}[/]\n"
        f"[{MUTED}]{'─' * 64}[/]\n"
        f"🏗️ [{YELLOW}]DDD Domains[/] [{BLUE}][●●○○○][/] [{SUB}]2/5[/]  "
        f"[{MUTED}]⚡[/] [{GREEN}]1.0x → 2.49x[/]\n"
        f"🤖 [{PURPLE}]◉ [1/15][/]  👥 [{SUB}]1[/]  [{RED}]🔴 CVE 0/3[/]  "
        f"💾 [{SUB}]{ram}MB[/]  🧠 [{cpu_c}]{cpu:.0f}%[/]\n"
        f"[{MUTED}]🔧 Architecture DDD [{GREEN}]●[/] 40% "
        f"│ Security [{YELLOW}]●PENDING[/] "
        f"│ Memory [{BLUE}]●AgentDB[/][/]"
    )


def _agent_markup(label: str, tool: str, pct: int, tokens: str,
                  error: str | None, color: str) -> str:
    b   = bar(pct)
    err = f"\n  [{YELLOW}]! {error}[/]" if error else ""
    return (
        f"[bold {color}]⬡ {label}[/]\n"
        f"  [{MUTED}]tool:[/] [{SUB}]{tool}[/]\n"
        f"  [{color}]{b}[/] [{TEXT}]{pct}%[/]\n"
        f"  [{MUTED}]{tokens} tokens[/]{err}"
    )


def _editor_markup(diff: str) -> str:
    lines = diff.split("\n")[:7]
    body  = "\n".join(f"  [{MUTED}]{ln}[/]" for ln in lines)
    return f"[bold {GREEN}]⬡ nvim [editor][/]\n{body}"


def _monitor_markup(a: int, b: int, tok: int,
                    procs: list[str], alert: str) -> str:
    tk_pct   = int(tok / 200000 * 100)
    proc_str = (
        "\n".join(f"  [{MUTED}]{p}[/]" for p in procs)
        if procs else f"  [{MUTED}]ninguno corriendo[/]"
    )
    alt = f"\n  [{RED}]{alert}[/]" if alert else ""
    return (
        f"[bold {PURPLE}]⬡ monitor[/]\n"
        f"  [{BLUE}]A backend  {bar(a)} {a}%[/]\n"
        f"  [{PURPLE}]B frontend {bar(b)} {b}%[/]\n"
        f"  [{MUTED}]tokens: {tok // 1000}k/200k {bar(tk_pct, 6)}[/]\n"
        f"{proc_str}{alt}"
    )


class HeaderWidget(Static):
    def __init__(self, **kw):
        self._branch = git_branch()
        cpu = psutil.cpu_percent(interval=None)
        ram = psutil.virtual_memory().used // (1024 * 1024)
        super().__init__(_header_markup(self._branch, cpu, ram), **kw)

    def on_mount(self) -> None:
        self.set_interval(2, self._tick)

    def _tick(self) -> None:
        cpu = psutil.cpu_percent(interval=None)
        ram = psutil.virtual_memory().used // (1024 * 1024)
        self.update(_header_markup(self._branch, cpu, ram))


class AgentPanel(Static):
    def __init__(self, label: str, tool: str, pct_init: int,
                 tokens: str, error: str | None = None, **kw):
        self._label  = label
        self._tool   = tool
        self._pct    = pct_init
        self._tokens = tokens
        self._error  = error
        self._color  = BLUE if "A" in label else PURPLE
        super().__init__(
            _agent_markup(label, tool, pct_init, tokens, error, self._color),
            **kw,
        )

    def on_mount(self) -> None:
        self.set_interval(1.5, self._tick)

    def _tick(self) -> None:
        if self._pct < 95:
            self._pct = min(95, self._pct + random.randint(0, 3))
        self.update(_agent_markup(
            self._label, self._tool, self._pct,
            self._tokens, self._error, self._color,
        ))


class EditorPanel(Static):
    def __init__(self, **kw):
        diff = git_diff_stat()
        super().__init__(_editor_markup(diff), **kw)
        self._diff = diff

    def on_mount(self) -> None:
        self.set_interval(5, self._tick)

    def _tick(self) -> None:
        self._diff = git_diff_stat()
        self.update(_editor_markup(self._diff))


class MonitorPanel(Static):
    def __init__(self, **kw):
        self._a     = 70
        self._b     = 45
        self._tok   = 39000
        self._alert = "! B: mock fallido"
        super().__init__(
            _monitor_markup(self._a, self._b, self._tok, [], self._alert),
            **kw,
        )

    def on_mount(self) -> None:
        self.set_interval(2, self._tick)

    def _procs(self) -> list[str]:
        out = []
        for p in psutil.process_iter(["name", "cmdline", "cpu_percent"]):
            try:
                cmd = " ".join(p.info["cmdline"] or [])
                if "claude" in cmd.lower():
                    out.append(f"{p.info['name'][:14]:<14} {p.info['cpu_percent']:.1f}%")
            except Exception:
                pass
        return out[:2]

    def _tick(self) -> None:
        self._a   = min(99, self._a + random.randint(0, 2))
        self._b   = min(99, self._b + random.randint(0, 2))
        self._tok = min(200000, self._tok + random.randint(100, 500))
        if random.random() < 0.05:
            self._alert = "" if self._alert else "! B: mock fallido"
        self.update(_monitor_markup(
            self._a, self._b, self._tok, self._procs(), self._alert,
        ))


# ── App ───────────────────────────────────────────────────────

class ClaudeUI(App):
    CSS = f"""
    Screen {{
        background: {BG};
    }}
    HeaderWidget {{
        height: 6;
        background: {SURFACE};
        border-bottom: solid {OVERLAY};
        padding: 0 2;
        color: {TEXT};
    }}
    #main-grid {{
        layout: horizontal;
        height: 1fr;
    }}
    #left-col {{
        width: 60%;
        layout: vertical;
        border-right: solid {OVERLAY};
    }}
    #center-col {{
        width: 20%;
        layout: vertical;
        border-right: solid {OVERLAY};
    }}
    #right-col {{
        width: 20%;
        layout: vertical;
    }}
    #orch-log {{
        height: 1fr;
        background: {BG};
        padding: 0 1;
    }}
    AgentPanel {{
        height: 50%;
        background: {BG};
        padding: 0 1;
        border-bottom: solid {OVERLAY};
    }}
    EditorPanel, MonitorPanel {{
        height: 50%;
        background: {SURFACE};
        padding: 0 1;
    }}
    #input-bar {{
        height: 4;
        background: {SURFACE};
        border: solid {PURPLE};
        layout: vertical;
        padding: 0 1;
    }}
    #cmd-input {{
        background: {BG};
        border: none;
        color: {TEXT};
        height: 1;
        padding: 0;
    }}
    #cmd-input:focus {{
        border: none;
    }}
    #input-hints {{
        color: {MUTED};
        height: 1;
    }}
    """

    BINDINGS: ClassVar = [
        ("ctrl+c", "quit", "Salir"),
        ("escape", "clear_input", "Cancelar"),
    ]

    _history: list[str] = []
    _hist_idx: int = -1

    def compose(self) -> ComposeResult:
        yield HeaderWidget()
        with Horizontal(id="main-grid"):
            with Vertical(id="left-col"):
                yield RichLog(id="orch-log", markup=True, highlight=False,
                              auto_scroll=True)
            with Vertical(id="center-col"):
                yield AgentPanel("agente A [backend]",  "bash",      70, "11.3k",
                                 id="agent-a")
                yield EditorPanel(id="editor")
            with Vertical(id="right-col"):
                yield AgentPanel("agente B [frontend]", "edit_file", 45, "8.7k",
                                 error="retry 2/3", id="agent-b")
                yield MonitorPanel(id="monitor")
        with Vertical(id="input-bar"):
            yield Input(placeholder="escribe aquí...", id="cmd-input")
            yield Static(
                f"[{MUTED}]↑↓ historial  esc: cancelar  enter: enviar  ctrl+c: stop[/]",
                id="input-hints",
            )

    def on_mount(self) -> None:
        self._seed_log()
        self.query_one("#cmd-input", Input).focus()

    def _seed_log(self) -> None:
        log = self.query_one("#orch-log", RichLog)
        log.write(f"[bold {BLUE}]⬡ claude code [orquestador][/]")
        log.write(f"[{MUTED}]{'─' * 48}[/]")
        for icon, color, msg in MSGS:
            log.write(f"[{color}]{icon}[/] [{TEXT}]{msg}[/]")
        log.write(f"[{MUTED}]{'─' * 48}[/]")
        log.write(f"[{MUTED}]esperando input...[/]")
        self.set_interval(7, self._auto_msg)

    def _auto_msg(self) -> None:
        icon, color, msg = random.choice(MSGS)
        self.query_one("#orch-log", RichLog).write(
            f"[{color}]{icon}[/] [{TEXT}]{msg}[/]"
        )

    @on(Input.Submitted, "#cmd-input")
    def handle_submit(self, event: Input.Submitted) -> None:
        text = event.value.strip()
        if not text:
            return
        self._history.append(text)
        self._hist_idx = len(self._history)
        self.query_one("#orch-log", RichLog).write(
            f"[bold {PURPLE}]▌[/] [{TEXT}]{text}[/]"
        )
        event.input.value = ""

    def on_key(self, event) -> None:
        inp = self.query_one("#cmd-input", Input)
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
        self.query_one("#cmd-input", Input).value = ""

    def action_quit(self) -> None:
        self.exit()


if __name__ == "__main__":
    ClaudeUI().run()
