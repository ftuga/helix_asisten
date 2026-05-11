#!/usr/bin/env python3
"""
Bench aislado: cuanto del corpus es HELIX-LANG vs prose, y cuanto ahorra v3
SOLO en las lineas HELIX-LANG.

Reporta: % del corpus que es HELIX-LANG, ahorro v3 en esas lineas, ROI total.
"""
import re
import sys
from pathlib import Path

import tiktoken
sys.path.insert(0, str(Path(__file__).parent))
from importlib import import_module

# Reuse translation rules
spec = import_module("bench-v2-vs-v3")
translate_v2_to_v3 = spec.translate_v2_to_v3


# Heuristica: una linea es "HELIX-LANG" si contiene patrones del protocolo v2.1
HELIX_LANG_PATTERNS = [
    r"\b[A-Z]{2,5}:(ok|er|~%[0-9]+|~|\?|#|![a-z])",  # AGENT:STATE
    r"->[A-Z]",  # mensaje
    r"\bD:\{",  # delta
    r"\bS:[a-zA-Z0-9]{4,}\b",  # hash ref
    r"@(now|next|done|blk)\b",  # temporal
    r"(give|need|ask|do|fix|chk|done|wait|stop):",  # verbo+colon
]
HL_RE = re.compile("|".join(HELIX_LANG_PATTERNS))


def is_helix_lang_line(line: str) -> bool:
    return bool(HL_RE.search(line))


def main():
    if len(sys.argv) < 2:
        print("Uso: bench-isolated.py <session_dir>", file=sys.stderr)
        sys.exit(1)

    session_dir = Path(sys.argv[1])
    outputs_dir = session_dir / "outputs"
    yaml_files = sorted(outputs_dir.glob("*.yaml"))

    cl = tiktoken.get_encoding("cl100k_base")

    total_corpus_tokens = 0
    total_hl_tokens_v2 = 0
    total_hl_tokens_v3 = 0
    total_prose_tokens = 0
    total_hl_lines = 0
    total_lines = 0

    for yf in yaml_files:
        text = yf.read_text()
        for line in text.splitlines():
            total_lines += 1
            line_tokens = len(cl.encode(line + "\n"))
            total_corpus_tokens += line_tokens
            if is_helix_lang_line(line):
                total_hl_lines += 1
                total_hl_tokens_v2 += line_tokens
                # traducir esta linea a v3 y tokenizar
                line_v3 = translate_v2_to_v3(line)
                total_hl_tokens_v3 += len(cl.encode(line_v3 + "\n"))
            else:
                total_prose_tokens += line_tokens

    hl_pct_lines = (total_hl_lines / total_lines * 100) if total_lines else 0
    hl_pct_tokens = (total_hl_tokens_v2 / total_corpus_tokens * 100) if total_corpus_tokens else 0
    prose_pct_tokens = (total_prose_tokens / total_corpus_tokens * 100) if total_corpus_tokens else 0

    hl_savings = total_hl_tokens_v2 - total_hl_tokens_v3
    hl_savings_pct = (hl_savings / total_hl_tokens_v2 * 100) if total_hl_tokens_v2 else 0
    total_savings_pct = (hl_savings / total_corpus_tokens * 100) if total_corpus_tokens else 0

    print(f"# Bench isolated: HELIX-LANG vs prose en {session_dir.name}")
    print(f"# Tokenizer: cl100k_base. N files: {len(yaml_files)}")
    print()
    print(f"Lineas total:                {total_lines:>8}")
    print(f"Lineas HELIX-LANG:           {total_hl_lines:>8}  ({hl_pct_lines:5.1f}%)")
    print(f"Lineas prose:                {total_lines - total_hl_lines:>8}  ({100-hl_pct_lines:5.1f}%)")
    print()
    print(f"Tokens total corpus (v2.1):  {total_corpus_tokens:>8}")
    print(f"Tokens HELIX-LANG (v2.1):    {total_hl_tokens_v2:>8}  ({hl_pct_tokens:5.1f}% del corpus)")
    print(f"Tokens prose:                {total_prose_tokens:>8}  ({prose_pct_tokens:5.1f}% del corpus)")
    print()
    print(f"Tokens HELIX-LANG (v3):      {total_hl_tokens_v3:>8}")
    print(f"Ahorro en HELIX-LANG:        {hl_savings:>+8}  ({hl_savings_pct:+5.2f}% sobre HELIX-LANG)")
    print(f"Ahorro total sobre corpus:   {hl_savings:>+8}  ({total_savings_pct:+5.2f}% sobre corpus full)")
    print()
    print(f"# Geometria: ROI total = (HELIX-LANG fraction) x (HELIX-LANG savings)")
    print(f"# = {hl_pct_tokens:.1f}% x {hl_savings_pct:.1f}% = {(hl_pct_tokens*hl_savings_pct/100):.2f}% (matematica)")
    print(f"# Reportado: {total_savings_pct:.2f}% (medido empiricamente)")


if __name__ == "__main__":
    main()
