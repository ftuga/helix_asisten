#!/usr/bin/env python3
"""
claude-ui.py — Helix Dashboard  ·  Visual Edition v3
"""
from __future__ import annotations
import datetime, random, subprocess
from typing import ClassVar
import psutil
from textual import on
from textual.app import App, ComposeResult
from textual.containers import Horizontal, Vertical
from textual.widgets import Input, RichLog, Static

# ── Catppuccin Mocha ──────────────────────────────────────────
BG      = "#1e1e2e"; SURFACE = "#181825"; OVERLAY = "#313244"
BLUE    = "#89b4fa"; PURPLE  = "#cba6f7"; GREEN   = "#a6e3a1"
YELLOW  = "#f9e2af"; RED     = "#f38ba8"; MUTED   = "#585b70"
TEXT    = "#cdd6f4"; SUB     = "#a6adc8"; TEAL    = "#94e2d5"
PEACH   = "#fab387"

SPINNER = ["⠋","⠙","⠹","⠸","⠼","⠴","⠦","⠧","⠇","⠏"]
BLOCKS  = " ▏▎▍▌▋▊▉█"

SLASH_COMMANDS = [
    "/compact        — comprime el contexto",
    "/helix-analiza  — diagnóstico del proyecto",
    "/helix-salud    — salud de helix",
    "/economia       — modo economía (sin subagentes)",
    "/helix-actualiza — actualizar análisis",
    "/clear          — limpiar contexto",
    "/help           — ayuda de Claude Code",
]

TOOL_LOG = [
    ("▶", BLUE,   "bash",       "git diff --stat HEAD~1"),
    ("✓", GREEN,  None,         "3 files changed, 47 ins, 12 del"),
    ("▶", BLUE,   "read_file",  "src/domain/evaluation.py"),
    ("·", MUTED,  None,         "Analizando bounded contexts..."),
    ("▶", BLUE,   "edit_file",  "src/domain/evaluation.py"),
    ("✓", GREEN,  None,         "método validate_score() agregado"),
    ("▶", BLUE,   "bash",       "python -m pytest tests/ -x -q"),
    ("✓", GREEN,  None,         "12 passed · 0 failed · 1.3s"),
    ("·", MUTED,  None,         "Revisando migrations pendientes..."),
    ("▶", BLUE,   "bash",       "alembic upgrade head"),
    ("✓", GREEN,  None,         "Running upgrade → 0012_add_plan_fields"),
    ("▲", YELLOW, None,         "CVDocument.score puede ser NULL"),
    ("▶", BLUE,   "write_file", "src/migrations/0013_fix_score.py"),
    ("✓", GREEN,  None,         "Migration creada correctamente"),
]

# ── Helpers ───────────────────────────────────────────────────

def git_branch() -> str:
    try:
        r = subprocess.run(["git","rev-parse","--abbrev-ref","HEAD"],
                           capture_output=True, text=True, timeout=2)
        return r.stdout.strip() or "—"
    except Exception: return "—"

def git_stat() -> str:
    try:
        r = subprocess.run(["git","diff","--stat"],
                           capture_output=True, text=True, timeout=2)
        if r.stdout.strip():
            lines = r.stdout.strip().split("\n")[:5]
            return "\n".join(lines)
        r2 = subprocess.run(
            ["git","log","--oneline","-5"],
            capture_output=True, text=True, timeout=2)
        return r2.stdout.strip() or "working tree clean"
    except Exception: return "no es repo git"

def smooth_bar(pct: int, width: int = 10) -> str:
    total_eighths = round(pct / 100 * width * 8)
    full  = total_eighths // 8
    frac  = total_eighths  % 8
    empty = width - full - (1 if frac else 0)
    c = GREEN if pct >= 75 else (YELLOW if pct >= 40 else RED)
    bar  = f"[{c}]{'█' * full}"
    if frac: bar += BLOCKS[frac]
    bar += f"[/][{MUTED}]{'▏' * empty}[/]"
    return bar

def spin(t: int) -> str:  return SPINNER[t % 10]
def pct_color(p: int) -> str:
    return f"bold {GREEN}" if p >= 75 else (f"bold {YELLOW}" if p >= 40 else f"bold {RED}")

def fmt_tool_line(icon: str, color: str, tool: str | None, msg: str) -> str:
    if tool:
        return (f" [{color}]{icon}[/] [{MUTED}]{tool:<12}[/] "
                f"[{TEAL}]{msg}[/]")
    return f" [{color}]{icon}[/] [{TEXT}]{msg}[/]"

# ── Widgets ───────────────────────────────────────────────────

class HeaderWidget(Static):
    _t: int = 0
    _branch: str = "—"

    def __init__(self, **kw):
        self._branch = git_branch()
        super().__init__(self._mk(), **kw)

    def on_mount(self) -> None:
        self.set_interval(1, self._tick)

    def _tick(self) -> None:
        self._t += 1
        self.update(self._mk())

    def _mk(self) -> str:
        now  = datetime.datetime.now().strftime("%H:%M:%S")
        cpu  = psutil.cpu_percent(interval=None)
        mem  = psutil.virtual_memory()
        ram  = mem.used // (1024**2)
        mpc  = int(mem.percent)
        cc   = GREEN if cpu < 50 else (YELLOW if cpu < 80 else RED)
        mc   = GREEN if mpc < 60 else (YELLOW if mpc < 80 else RED)
        sp   = spin(self._t)
        # barras suaves
        cb   = smooth_bar(int(cpu), 8)
        mb   = smooth_bar(mpc,      8)
        # estado de streaming animado
        dots = ["·  ", "·· ", "···"][self._t % 3]
        return (
            f" [bold {BLUE}]▊ HELIX[/]  [{MUTED}]│[/]  "
            f"[bold {TEXT}]claude-sonnet-4-6[/]  [{MUTED}]│[/]  "
            f"[{PURPLE}]◉ session[/]  [{MUTED}]⎇[/] [{TEAL}]{self._branch}[/]  "
            f"[{MUTED}]│[/]  [bold {BLUE}]{now}[/]\n"
            f" [{MUTED}]{'─' * 76}[/]\n"
            f" [{MUTED}]CPU[/] {cb} [{cc}]{cpu:4.0f}%[/]   "
            f"[{MUTED}]RAM[/] {mb} [{mc}]{ram}MB[/]   "
            f"[{MUTED}]│[/]  🏗 [{YELLOW}]DDD[/] [{BLUE}]❶❷○○○[/] [{SUB}]2/5[/]   "
            f"[{MUTED}]⚡[/] [{GREEN}]2.49x[/]   "
            f"[{MUTED}]◉[/] [{PURPLE}]2/15 agents[/]   "
            f"[{MUTED}]streaming{dots}[/]"
        )


class AgentPanel(Static):
    def __init__(self, name: str, role: str, tool: str,
                 pct: int, tokens: str, color: str,
                 err: str | None = None, **kw):
        self._name = name; self._role = role; self._tool = tool
        self._pct  = pct;  self._tok  = tokens; self._c = color
        self._err  = err;  self._t    = 0
        super().__init__(self._mk(), **kw)

    def on_mount(self) -> None:
        self.set_interval(0.6, self._tick)

    def _tick(self) -> None:
        self._t += 1
        if self._pct < 95:
            self._pct = min(95, self._pct + random.randint(0, 2))
        self.update(self._mk())

    def _mk(self) -> str:
        done = self._pct >= 95
        icon = "✓" if done else spin(self._t)
        ic   = GREEN if done else BLUE
        b    = smooth_bar(self._pct, 9)
        pc   = pct_color(self._pct)
        err  = f"\n [{RED}]▲ {self._err}[/]" if self._err else ""
        return (
            f" [bold {self._c}]{self._name}[/]  [{MUTED}]{self._role}[/]\n"
            f" [{MUTED}]─────────────────────[/]\n"
            f" [{ic}]{icon}[/] [{MUTED}]tool[/] [{TEAL}]{self._tool}[/]\n"
            f" {b} [{pc}]{self._pct}%[/]\n"
            f" [{MUTED}]tokens[/] [{SUB}]{self._tok}[/]{err}"
        )


class EditorPanel(Static):
    def __init__(self, **kw):
        self._stat = git_stat(); self._t = 0
        super().__init__(self._mk(), **kw)

    def on_mount(self) -> None:
        self.set_interval(5, self._tick)

    def _tick(self) -> None:
        self._t += 1; self._stat = git_stat(); self.update(self._mk())

    def _mk(self) -> str:
        lines = self._stat.split("\n")[:6]
        rows = []
        for ln in lines:
            if not ln.strip(): continue
            if "+" in ln:
                rows.append(f" [{GREEN}]+ [{SUB}]{ln.strip()}[/][/]")
            elif "-" in ln and "|" in ln:
                rows.append(f" [{RED}]- [{SUB}]{ln.strip()}[/][/]")
            else:
                rows.append(f" [{MUTED}]{ln.strip()}[/]")
        body = "\n".join(rows) or f" [{MUTED}]working tree clean[/]"
        return (
            f" [bold {GREEN}]⬡ git diff[/]  [{MUTED}]· auto-refresh 5s[/]\n"
            f" [{MUTED}]─────────────────────[/]\n"
            f"{body}"
        )


class MonitorPanel(Static):
    def __init__(self, **kw):
        self._a = 70; self._b = 45; self._tok = 39000
        self._alert = "B: mock fallido"; self._t = 0
        super().__init__(self._mk(), **kw)

    def on_mount(self) -> None:
        self.set_interval(1.5, self._tick)

    def _tick(self) -> None:
        self._t += 1
        self._a   = min(99, self._a + random.randint(0, 2))
        self._b   = min(99, self._b + random.randint(0, 2))
        self._tok = min(200000, self._tok + random.randint(200, 700))
        if random.random() < 0.04:
            self._alert = "" if self._alert else "B: mock fallido"
        self.update(self._mk())

    def _procs(self) -> list[tuple[str, float]]:
        out = []
        for p in psutil.process_iter(["name","cmdline","cpu_percent"]):
            try:
                cmd = " ".join(p.info["cmdline"] or [])
                if "claude" in cmd.lower():
                    out.append((p.info["name"][:14], p.info["cpu_percent"]))
            except Exception: pass
        return out[:2]

    def _mk(self) -> str:
        tk = int(self._tok / 200000 * 100)
        procs = self._procs()
        live  = f"[{GREEN}]{spin(self._t)}[/] [bold {SUB}]live[/]"
        p_str = (
            "\n".join(f" [{MUTED}]▸[/] [{TEAL}]{n:<14}[/] [{BLUE}]{c:.1f}%[/]"
                      for n, c in procs)
            if procs else f" [{MUTED}]no claude procs[/]"
        )
        alt = f"\n [{RED}]▲ {self._alert}[/]" if self._alert else ""
        return (
            f" [bold {PURPLE}]⬡ monitor[/]  {live}\n"
            f" [{MUTED}]─────────────────────[/]\n"
            f" [{BLUE}]A backend [/]{smooth_bar(self._a,8)} [{pct_color(self._a)}]{self._a}%[/]\n"
            f" [{PURPLE}]B frontend[/]{smooth_bar(self._b,8)} [{pct_color(self._b)}]{self._b}%[/]\n"
            f" [{MUTED}]─────────────────────[/]\n"
            f" [{MUTED}]tokens [/][{SUB}]{self._tok//1000}k[/][{MUTED}]/200k[/] "
            f"{smooth_bar(tk,6)}\n"
            f"{p_str}{alt}"
        )


# ── App ───────────────────────────────────────────────────────

class ClaudeUI(App):
    CSS = f"""
Screen {{ background: {BG}; }}

/* ── Header ── */
HeaderWidget {{
    height: 4;
    background: {SURFACE};
    border-bottom: heavy {OVERLAY};
    padding: 0 1;
}}

/* ── Main grid ── */
#grid {{
    layout: horizontal;
    height: 1fr;
}}

/* ── Columna izquierda ── */
#left {{
    width: 56%;
    layout: vertical;
    border-right: solid {OVERLAY};
}}
#tool-log {{
    height: 55%;
    background: {SURFACE};
    border-bottom: dashed {OVERLAY};
    border: double {BLUE};
    padding: 0 1;
    scrollbar-color: {OVERLAY} {SURFACE};
}}
#chat-area {{
    height: 45%;
    background: {BG};
    layout: vertical;
    border: double {PURPLE};
    padding: 0 0;
}}
#chat-log {{
    height: 1fr;
    background: {BG};
    padding: 0 1;
    scrollbar-color: {OVERLAY} {BG};
}}
#slash-menu {{
    height: auto;
    background: {OVERLAY};
    display: none;
    padding: 0 1;
}}
#input-row {{
    height: 3;
    layout: horizontal;
    background: {SURFACE};
    border-top: solid {OVERLAY};
    padding: 0 1;
}}
#prompt-lbl {{
    width: 4;
    content-align: left middle;
    color: {PURPLE};
    background: {SURFACE};
    padding: 0;
}}
#chat-input {{
    height: 1;
    background: {SURFACE};
    border: none;
    color: {TEXT};
    width: 1fr;
    margin: 1 0;
    padding: 0 1;
}}
#chat-input:focus {{ border: none; }}

/* ── Columna centro ── */
#center {{
    width: 22%;
    layout: vertical;
    border-right: solid {OVERLAY};
}}
AgentPanel {{
    height: 50%;
    background: {BG};
    padding: 0;
    border: round {MUTED};
}}
#agent-a {{ border: round {BLUE}; }}
#agent-b {{ border: round {PURPLE}; }}
EditorPanel {{
    height: 50%;
    background: {SURFACE};
    padding: 0;
    border: round {GREEN};
}}

/* ── Columna derecha ── */
#right {{
    width: 22%;
    layout: vertical;
}}
MonitorPanel {{
    height: 50%;
    background: {SURFACE};
    padding: 0;
    border: round {PURPLE};
}}
"""

    BINDINGS: ClassVar = [("ctrl+c","quit","Salir"),("escape","esc_input","Esc")]
    _hist: list[str] = []; _hi: int = -1; _show_slash: bool = False

    def compose(self) -> ComposeResult:
        yield HeaderWidget()
        with Horizontal(id="grid"):
            with Vertical(id="left"):
                yield RichLog(id="tool-log", markup=True, highlight=False, auto_scroll=True)
                with Vertical(id="chat-area"):
                    yield RichLog(id="chat-log", markup=True, highlight=False, auto_scroll=True)
                    yield Static("", id="slash-menu")
                    with Horizontal(id="input-row"):
                        yield Static(f"[bold {PURPLE}]▸[/]", id="prompt-lbl")
                        yield Input(placeholder="pregunta a helix · / para comandos", id="chat-input")
            with Vertical(id="center"):
                yield AgentPanel("agente-A","backend","bash",     70,"11.3k",BLUE,  id="agent-a")
                yield EditorPanel(id="editor")
            with Vertical(id="right"):
                yield AgentPanel("agente-B","frontend","edit_file",45,"8.7k", PURPLE,"retry 2/3",id="agent-b")
                yield MonitorPanel(id="monitor")

    def on_mount(self) -> None:
        # títulos de panel
        self.query_one("#tool-log").border_title    = f"  ⬡ claude output · tool calls  "
        self.query_one("#chat-area").border_title   = f"  ▸ helix chat  "
        self.query_one("#chat-area").border_subtitle = f"  / = comandos  "
        self.query_one("#agent-a").border_title     = f"  ⬡ agente-A · backend  "
        self.query_one("#agent-b").border_title     = f"  ⬡ agente-B · frontend  "
        self.query_one("#editor").border_title      = f"  ⬡ git diff  "
        self.query_one("#monitor").border_title     = f"  ⬡ monitor  "
        self._seed_tool_log()
        self._seed_chat_log()
        self.query_one("#chat-input", Input).focus()
        self.set_interval(4, self._auto_tool_msg)

    def _seed_tool_log(self) -> None:
        log = self.query_one("#tool-log", RichLog)
        log.write(f"[bold {BLUE}]Claude Flow V3[/]  [{PURPLE}]◉ session iniciada[/]  [{MUTED}]2 agents activos[/]")
        log.write(f"[{MUTED}]{'─' * 56}[/]")
        for icon, color, tool, msg in TOOL_LOG:
            log.write(fmt_tool_line(icon, color, tool, msg))
        log.write(f"[{MUTED}]{'─' * 56}[/]")
        log.write(f"[{MUTED}]{spin(0)} esperando siguiente tarea...[/]")

    def _seed_chat_log(self) -> None:
        chat = self.query_one("#chat-log", RichLog)
        chat.write(f"[{MUTED}]Helix listo · usá / para ver comandos disponibles[/]")

    def _auto_tool_msg(self) -> None:
        icon, color, tool, msg = random.choice(TOOL_LOG)
        self.query_one("#tool-log", RichLog).write(
            fmt_tool_line(icon, color, tool, msg)
        )

    @on(Input.Changed, "#chat-input")
    def _on_change(self, event: Input.Changed) -> None:
        val = event.value
        menu = self.query_one("#slash-menu", Static)
        if val == "/":
            lines = "\n".join(
                f" [{BLUE}]{cmd.split()[0]}[/][{MUTED}]{cmd[cmd.index(' '):]  if ' ' in cmd else ''}[/]"
                for cmd in SLASH_COMMANDS
            )
            menu.update(f"[{MUTED}]comandos disponibles:[/]\n{lines}")
            menu.display = True
            self._show_slash = True
        elif val.startswith("/") and len(val) > 1:
            # filtrar
            term = val[1:].lower()
            matches = [c for c in SLASH_COMMANDS if term in c]
            if matches:
                lines = "\n".join(
                    f" [{BLUE}]{c.split()[0]}[/][{MUTED}]{c[c.index(' '):] if ' ' in c else ''}[/]"
                    for c in matches
                )
                menu.update(f"[{MUTED}]comandos:[/]\n{lines}")
                menu.display = True
            else:
                menu.display = False
            self._show_slash = True
        else:
            menu.display = False
            self._show_slash = False

    @on(Input.Submitted, "#chat-input")
    def _on_submit(self, event: Input.Submitted) -> None:
        text = event.value.strip()
        if not text: return
        self.query_one("#slash-menu", Static).display = False
        self._hist.append(text); self._hi = len(self._hist)
        chat = self.query_one("#chat-log", RichLog)
        chat.write(f"[bold {PURPLE}]▸ vos[/]  [{TEXT}]{text}[/]")
        if text.startswith("/"):
            chat.write(f"[{MUTED}]  ╰─ ejecutá este comando en tu terminal con[/] [bold {TEAL}]helix[/]")
        else:
            chat.write(f"[{MUTED}]  ╰─[/] [{GREEN}]entendido, procesando...[/]")
        event.input.value = ""

    def on_key(self, event) -> None:
        inp = self.query_one("#chat-input", Input)
        if not inp.has_focus: return
        if event.key == "up" and self._hist and self._hi > 0:
            self._hi -= 1
            inp.value = self._hist[self._hi]
            inp.cursor_position = len(inp.value)
            event.prevent_default()
        elif event.key == "down":
            if self._hi < len(self._hist) - 1:
                self._hi += 1
                inp.value = self._hist[self._hi]
            else:
                self._hi = len(self._hist); inp.value = ""
            event.prevent_default()

    def action_esc_input(self) -> None:
        inp = self.query_one("#chat-input", Input)
        if inp.value:
            inp.value = ""
        else:
            self.query_one("#slash-menu", Static).display = False

    def action_quit(self) -> None:
        self.exit()


if __name__ == "__main__":
    ClaudeUI().run()
