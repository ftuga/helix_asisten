#!/usr/bin/env python3
"""
Bench M1 (token efficiency) — v2.1 vs v3 sobre corpus real del council.

Lee outputs YAML de un council session que corrio en v2.1, aplica reglas de
traduccion a v3 (solo en patrones HELIX-LANG; deja prosa analitica intacta),
tokeniza ambas versiones con tiktoken cl100k_base + o200k_base.

Reporta: tokens v2.1, tokens v3, delta absoluto, delta %, por archivo y total.
"""
import re
import sys
from pathlib import Path

import tiktoken

# ============================================================
# TRANSLATION RULES v2.1 -> v3
# ============================================================

# Renombrado de IDs council (cambian a 2-char uppercase)
COUNCIL_ID_MAP = {
    "SKEPT": "SK",
    "INNOV": "IN",
    "CONS": "CO",
    "SYNTH": "SY",
    "RES": "RE",
    "DEV": "DV",
    "DEVIL": "DV",
    "ARB": "AB",
    "ORC": "OC",
    "TST": "TS",
    "INF": "IF",
    "DEVILS_ADVOCATE": "DV",
    "DEVILS-ADVOCATE": "DV",
}

# Verbos de v2.1: give/do/fix/chk se OMITEN en v3 (operador implica)
VERBS_DROP = ("give", "do", "fix", "chk")
# Verbos de v2.1: ask/need se traducen a prefijo ? en v3
VERBS_QUESTION = ("ask", "need")
# Verbos que sobreviven (los conservamos pero sin colon)
VERBS_KEEP_NOCOLON = ("done", "wait", "stop")

# Estados validos v2.1 (regex character class)
STATE_RE = r"(?:ok|er|~%[0-9]+|~[0-9]+|~|\?|#|![a-z][a-z_]*|%[0-9]+)"


def rename_council_ids(text: str) -> str:
    """SKEPT -> SK, INNOV -> IN, etc. Solo cuando aparecen como IDs (no en prosa)."""
    out = text
    for old, new in COUNCIL_ID_MAP.items():
        # Match en contextos: AGENT: o ->AGENT o AGENT-> o {AGENT o ,AGENT
        # Tambien standalone como "SKEPT" en YAML field references (round_1_skeptic ->
        # nope, esos son nombres de archivo en lowercase)
        # Patron: word boundary + ID + : / -> / espacio / { / , / final-de-linea
        out = re.sub(
            rf"\b{old}\b(?=[\s:.,>}}\]\|]|->|$)",
            new,
            out,
        )
    return out


def drop_colon_after_agent_state(text: str) -> str:
    """AGENT:STATE.domain -> AGENT STATE.domain (Forma 1 v2.1 -> v3)"""
    # Patron: 2-5 letras mayusculas + : + estado
    return re.sub(
        rf"\b([A-Z]{{2,5}}):({STATE_RE})",
        r"\1 \2",
        text,
    )


def drop_verb_in_message(text: str) -> str:
    """AGENT->AGENT give:obj -> AGENT->AGENT obj  (Forma 2 v2.1 verbos drop)"""
    out = text
    for verb in VERBS_DROP:
        # AGENT->AGENT verb:obj  ->  AGENT->AGENT obj
        out = re.sub(
            rf"(->[A-Z+*]+(?:\+[A-Z+*]+)*\s+){verb}:",
            r"\1",
            out,
        )
    return out


def question_prefix_for_ask_need(text: str) -> str:
    """AGENT->AGENT ask:obj -> AGENT->AGENT ?obj"""
    out = text
    for verb in VERBS_QUESTION:
        out = re.sub(
            rf"(->[A-Z+*]+(?:\+[A-Z+*]+)*\s+){verb}:([a-z])",
            r"\1?\2",
            out,
        )
    return out


def keep_verbs_drop_colon(text: str) -> str:
    """done:obj -> done obj, wait:obj -> wait obj, stop:obj -> stop obj"""
    out = text
    for verb in VERBS_KEEP_NOCOLON:
        out = re.sub(
            rf"(\s){verb}:([a-z])",
            rf"\1{verb} \2",
            out,
        )
    return out


def unwrap_delta(text: str) -> str:
    """D:{AGENT:STATE,AGENT:STATE} -> AGENT STATE AGENT STATE
    Solo si <=3 agentes (v3 usa [...] para 4+)"""
    def replace(match):
        inner = match.group(1)
        # Eliminar comas, las commas se vuelven espacios
        cleaned = inner.replace(",", " ").strip()
        # Contar agentes (estimacion: numero de :)
        agent_count = cleaned.count(":")
        if agent_count <= 3:
            # Reemplazar AGENT:STATE -> AGENT STATE en el contenido
            cleaned = re.sub(rf"\b([A-Z]{{2,5}}):({STATE_RE})", r"\1 \2", cleaned)
            # Limpiar dobles espacios
            cleaned = re.sub(r"\s+", " ", cleaned).strip()
            return cleaned
        else:
            # 4+ agentes: usar [...]
            cleaned = re.sub(rf"\b([A-Z]{{2,5}}):({STATE_RE})", r"\1 \2", cleaned)
            cleaned = re.sub(r"\s+", " ", cleaned).strip()
            return f"[{cleaned}]"

    return re.sub(r"D:\{([^}]+)\}", replace, text)


def translate_v2_to_v3(text: str) -> str:
    """Aplica todas las reglas en orden."""
    out = text
    out = unwrap_delta(out)  # primero, antes de rename (D:{SKEPT:ok} -> SKEPT ok)
    out = drop_colon_after_agent_state(out)
    out = drop_verb_in_message(out)
    out = question_prefix_for_ask_need(out)
    out = keep_verbs_drop_colon(out)
    out = rename_council_ids(out)
    return out


# ============================================================
# BENCH
# ============================================================

def main():
    if len(sys.argv) < 2:
        print("Uso: bench-v2-vs-v3.py <session_dir>", file=sys.stderr)
        sys.exit(1)

    session_dir = Path(sys.argv[1])
    outputs_dir = session_dir / "outputs"
    if not outputs_dir.is_dir():
        print(f"ERROR: no existe {outputs_dir}", file=sys.stderr)
        sys.exit(1)

    cl = tiktoken.get_encoding("cl100k_base")
    o2 = tiktoken.get_encoding("o200k_base")

    yaml_files = sorted(outputs_dir.glob("*.yaml"))
    if not yaml_files:
        print(f"ERROR: 0 yaml files en {outputs_dir}", file=sys.stderr)
        sys.exit(1)

    total_v2_cl = 0
    total_v3_cl = 0
    total_v2_o2 = 0
    total_v3_o2 = 0

    print(f"# Bench v2.1 vs v3 sobre {session_dir.name}")
    print(f"# Tokenizers: cl100k_base + o200k_base (tiktoken {tiktoken.__version__})")
    print(f"# N files: {len(yaml_files)}")
    print()
    print(f"{'FILE':<40} {'V2_CL':>8} {'V3_CL':>8} {'D_CL':>8} {'D%_CL':>7}  {'V2_O2':>8} {'V3_O2':>8} {'D_O2':>8} {'D%_O2':>7}")
    print("-" * 130)

    for yf in yaml_files:
        v2 = yf.read_text()
        v3 = translate_v2_to_v3(v2)

        v2_cl = len(cl.encode(v2))
        v3_cl = len(cl.encode(v3))
        v2_o2 = len(o2.encode(v2))
        v3_o2 = len(o2.encode(v3))

        d_cl = v2_cl - v3_cl
        dp_cl = (d_cl / v2_cl * 100) if v2_cl else 0
        d_o2 = v2_o2 - v3_o2
        dp_o2 = (d_o2 / v2_o2 * 100) if v2_o2 else 0

        total_v2_cl += v2_cl
        total_v3_cl += v3_cl
        total_v2_o2 += v2_o2
        total_v3_o2 += v3_o2

        name = yf.name
        if len(name) > 38:
            name = name[:35] + "..."
        print(f"{name:<40} {v2_cl:>8} {v3_cl:>8} {d_cl:>+8} {dp_cl:>+6.1f}%  {v2_o2:>8} {v3_o2:>8} {d_o2:>+8} {dp_o2:>+6.1f}%")

    print("-" * 130)
    td_cl = total_v2_cl - total_v3_cl
    tdp_cl = (td_cl / total_v2_cl * 100) if total_v2_cl else 0
    td_o2 = total_v2_o2 - total_v3_o2
    tdp_o2 = (td_o2 / total_v2_o2 * 100) if total_v2_o2 else 0
    print(f"{'TOTAL':<40} {total_v2_cl:>8} {total_v3_cl:>8} {td_cl:>+8} {tdp_cl:>+6.1f}%  {total_v2_o2:>8} {total_v3_o2:>8} {td_o2:>+8} {tdp_o2:>+6.1f}%")

    print()
    print(f"# RESULTADO M1 (council umbral >= 15%):")
    print(f"# cl100k_base: {tdp_cl:+.2f}%  {'PASS' if tdp_cl >= 15 else 'FAIL'} (umbral 15%)")
    print(f"# o200k_base:  {tdp_o2:+.2f}%  {'PASS' if tdp_o2 >= 15 else 'FAIL'} (umbral 15%)")


if __name__ == "__main__":
    main()
