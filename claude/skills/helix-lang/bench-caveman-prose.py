#!/usr/bin/env python3
"""
Bench Fase 0 — caveman-style compression sobre prosa de council.

Aplica reglas de compresion lexica al estilo caveman a las lineas de prosa
(no HELIX-LANG) en el corpus del council. Mide ahorro maximo teorico antes
de invertir en test de comprension LLM.

Reglas progresivas L1, L2, L3:
  L1 — drop articulos (el/la/los/las/un/una/unos/unas/lo)
  L2 — L1 + drop conjunciones comunes (y/o/pero/que cuando es relativo)
  L3 — L2 + simplificar verbos auxiliares (es/son/era/sera/sea + drop)
        + drop preposiciones de rellenado (de/a/en cuando son repetitivas)
"""
import re
import sys
from pathlib import Path

import tiktoken
sys.path.insert(0, str(Path(__file__).parent))
from importlib import import_module

# Reuse helix-lang detector
spec = import_module("bench-isolated")
is_helix_lang_line = spec.is_helix_lang_line

# ============================================================
# REGLAS CAVEMAN-STYLE EN ESPAÑOL
# ============================================================

# Articulos: drop antes de sustantivo (heuristica: lowercase + alfa)
ART_RE = re.compile(
    r"\b(el|la|los|las|un|una|unos|unas|lo|del|al)\s+(?=[a-záéíóúñ])",
    re.IGNORECASE,
)

# Conjunciones y pronombres relativos (selectivo)
CONJ_RE = re.compile(
    r"\b(que|de|en|con|por|para|sobre|sin|a|y|o|pero|si|cuando|donde|como)\s+(?=[a-záéíóúñ])",
    re.IGNORECASE,
)

# Solo conjunciones suaves L2 (no quitamos "que", "de" que son casi siempre necesarias)
CONJ_L2_RE = re.compile(
    r"\b(y|e|o|u|pero|sino|aunque|cuando|si|porque|pues|asimismo|ademas|tambien)\s+",
    re.IGNORECASE,
)

# Verbos auxiliares y modales
VERB_AUX_RE = re.compile(
    r"\b(es|son|era|son|sera|seran|sea|sean|fue|fueron|fui|esta|estan|estaba|estaban|"
    r"esta|esten|sido|estado|ha|han|habia|habia|hay|hubo|haya|hayan|"
    r"puede|pueden|podia|podian|podra|podran|debe|deben|debia|debian|"
    r"se|le|les|me|te|nos|os)\s+",
    re.IGNORECASE,
)

# Preposiciones rellenadoras frecuentes (drop selectivo)
PREP_FILL_RE = re.compile(
    r"\b(de|a|en|con|por|para|sobre|al|del)\s+(?=(de|a|en|con|por|para|sobre|al|del)\s)",
    re.IGNORECASE,
)

# Frases redundantes comunes
PHRASE_REPLACE = [
    (r"\bes decir\b", ""),
    (r"\bo sea\b", ""),
    (r"\ben otras palabras\b", ""),
    (r"\bpor lo tanto\b", "->"),
    (r"\bademas de eso\b", "+"),
    (r"\bademas\b", "+"),
    (r"\bsi y solo si\b", "iff"),
    (r"\bse debe\b", "debe"),
    (r"\bes necesario que\b", "necesita"),
    (r"\bdado que\b", "ya que"),
    (r"\b(no obstante|sin embargo)\b", "but"),
    (r"\bpor ejemplo\b", "ej:"),
    (r"\bpor lo general\b", "usual"),
    (r"\ben general\b", "gral"),
    (r"\bdel mismo modo\b", "igual"),
]


def compress_l1(text: str) -> str:
    """L1: drop articulos solamente."""
    out = ART_RE.sub("", text)
    return re.sub(r"\s+", " ", out)


def compress_l2(text: str) -> str:
    """L2: L1 + frases redundantes + conjunciones suaves."""
    out = compress_l1(text)
    for pat, repl in PHRASE_REPLACE:
        out = re.sub(pat, repl, out, flags=re.IGNORECASE)
    out = CONJ_L2_RE.sub("", out)
    return re.sub(r"\s+", " ", out).strip()


def compress_l3(text: str) -> str:
    """L3: L2 + verbos auxiliares + preposiciones rellenadoras."""
    out = compress_l2(text)
    out = VERB_AUX_RE.sub("", out)
    out = PREP_FILL_RE.sub("", out)
    # Cleanup
    out = re.sub(r"\s+", " ", out).strip()
    out = re.sub(r"\s+([.,;:!?])", r"\1", out)  # espacio antes de puntuacion
    return out


# ============================================================
# REGLAS CAVEMAN-STYLE EN INGLES (corpus es bilingue)
# ============================================================

EN_ART_RE = re.compile(r"\b(the|a|an)\s+(?=[a-z])", re.IGNORECASE)
EN_AUX_RE = re.compile(
    r"\b(is|are|was|were|be|been|being|am|s|has|have|had|having|do|does|did|"
    r"can|could|may|might|must|shall|should|will|would)\s+",
    re.IGNORECASE,
)
EN_CONJ_RE = re.compile(
    r"\b(and|or|but|so|because|however|moreover|furthermore|therefore|thus|"
    r"although|though|whereas|while|since|if|when|where|whose|whom|"
    r"that|which|who)\s+",
    re.IGNORECASE,
)
EN_PREP_RE = re.compile(
    r"\b(of|to|in|on|at|by|for|with|from|about|into|onto|upon|over|under|"
    r"between|among|across|through|via)\s+(?=(of|to|in|on|at|by|for|with|from|about)\s)",
    re.IGNORECASE,
)
EN_PHRASES = [
    (r"\bin order to\b", "to"),
    (r"\bdue to\b", "to"),
    (r"\bsuch as\b", "ej:"),
    (r"\bfor example\b", "e.g."),
    (r"\bfor instance\b", "e.g."),
    (r"\bas well as\b", "+"),
    (r"\bin addition to\b", "+"),
    (r"\bregardless of\b", "no-matter"),
    (r"\bwith respect to\b", "re:"),
    (r"\bwith regard to\b", "re:"),
    (r"\bin the case of\b", "if:"),
    (r"\bon the other hand\b", "but"),
    (r"\bat the same time\b", "+"),
    (r"\bit is important to note that\b", "note:"),
    (r"\bit should be noted that\b", "note:"),
    (r"\bnamely\b", "i.e."),
    (r"\bthat is to say\b", "i.e."),
    (r"\bin other words\b", "i.e."),
    (r"\bcan be considered as\b", "="),
    (r"\bis equivalent to\b", "="),
]


def compress_l3_bilingual(text: str) -> str:
    """L3 bilingue: aplica reglas ES Y EN."""
    out = compress_l2(text)  # ES rules
    out = VERB_AUX_RE.sub("", out)  # ES verbos aux
    out = PREP_FILL_RE.sub("", out)  # ES prep relleno
    # EN rules
    for pat, repl in EN_PHRASES:
        out = re.sub(pat, repl, out, flags=re.IGNORECASE)
    out = EN_ART_RE.sub("", out)
    out = EN_AUX_RE.sub("", out)
    out = EN_CONJ_RE.sub("", out)
    out = EN_PREP_RE.sub("", out)
    # Cleanup
    out = re.sub(r"\s+", " ", out).strip()
    out = re.sub(r"\s+([.,;:!?])", r"\1", out)
    return out


# ============================================================
# BENCH
# ============================================================

def main():
    if len(sys.argv) < 2:
        print("Uso: bench-caveman-prose.py <session_dir>", file=sys.stderr)
        sys.exit(1)

    session_dir = Path(sys.argv[1])
    outputs_dir = session_dir / "outputs"
    yaml_files = sorted(outputs_dir.glob("*.yaml"))

    cl = tiktoken.get_encoding("cl100k_base")

    total_orig = 0
    total_l1_prose = 0
    total_l2_prose = 0
    total_l3_prose = 0
    total_l3b_prose = 0  # L3 bilingue (ES + EN)
    total_protocol = 0
    total_prose_orig = 0

    sample_l3_lines = []

    for yf in yaml_files:
        text = yf.read_text()
        for line in text.splitlines():
            line_with_nl = line + "\n"
            orig_t = len(cl.encode(line_with_nl))
            total_orig += orig_t

            if is_helix_lang_line(line) or not line.strip():
                total_protocol += orig_t
                total_l1_prose += orig_t
                total_l2_prose += orig_t
                total_l3_prose += orig_t
                total_l3b_prose += orig_t
                continue

            total_prose_orig += orig_t
            total_l1_prose += len(cl.encode(compress_l1(line) + "\n"))
            total_l2_prose += len(cl.encode(compress_l2(line) + "\n"))
            l3 = compress_l3(line)
            total_l3_prose += len(cl.encode(l3 + "\n"))
            l3b = compress_l3_bilingual(line)
            total_l3b_prose += len(cl.encode(l3b + "\n"))

            if len(sample_l3_lines) < 8 and len(line.strip()) > 60:
                sample_l3_lines.append((line.strip(), l3b.strip()))

    def pct(orig, comp):
        return ((orig - comp) / orig * 100) if orig else 0

    print(f"# Bench Fase 0 — caveman-on-prose (cl100k_base, ES corpus)")
    print(f"# Session: {session_dir.name}")
    print(f"# N files: {len(yaml_files)}")
    print()
    print(f"Tokens original total:        {total_orig:>8}")
    print(f"  - en HELIX-LANG/blank:      {total_protocol:>8} ({total_protocol/total_orig*100:5.1f}%)")
    print(f"  - en prosa:                 {total_prose_orig:>8} ({total_prose_orig/total_orig*100:5.1f}%)")
    print()
    print(f"{'NIVEL':<14} {'TOKENS':>10} {'AHORRO':>10} {'% AHORRO':>10}")
    print("-" * 49)
    print(f"{'original':<14} {total_orig:>10} {0:>10} {0:>9.2f}%")
    print(f"{'L1 (ES art)':<14} {total_l1_prose:>10} {total_orig - total_l1_prose:>+10} {pct(total_orig, total_l1_prose):>+9.2f}%")
    print(f"{'L2 (ES suave)':<14} {total_l2_prose:>10} {total_orig - total_l2_prose:>+10} {pct(total_orig, total_l2_prose):>+9.2f}%")
    print(f"{'L3 (ES full)':<14} {total_l3_prose:>10} {total_orig - total_l3_prose:>+10} {pct(total_orig, total_l3_prose):>+9.2f}%")
    print(f"{'L3b (ES+EN)':<14} {total_l3b_prose:>10} {total_orig - total_l3b_prose:>+10} {pct(total_orig, total_l3b_prose):>+9.2f}%")
    print()
    print(f"# Ahorro SOLO sobre prosa (denominador prosa, no full):")
    l1p = ((total_prose_orig - (total_l1_prose - total_protocol)) / total_prose_orig * 100)
    l2p = ((total_prose_orig - (total_l2_prose - total_protocol)) / total_prose_orig * 100)
    l3p = ((total_prose_orig - (total_l3_prose - total_protocol)) / total_prose_orig * 100)
    l3bp = ((total_prose_orig - (total_l3b_prose - total_protocol)) / total_prose_orig * 100)
    print(f"  L1   sobre prosa: {l1p:+.2f}%")
    print(f"  L2   sobre prosa: {l2p:+.2f}%")
    print(f"  L3   sobre prosa: {l3p:+.2f}%")
    print(f"  L3b  sobre prosa: {l3bp:+.2f}%  <-- ES+EN bilingue, mas representativo del corpus real")
    print(f"  caveman-target: ~50-65% sobre prosa")
    print()
    print(f"# Muestras L3 (verbose -> compressed) — evaluar legibilidad:")
    for i, (orig, comp) in enumerate(sample_l3_lines[:5], 1):
        print(f"\n  [{i}] ORIG ({len(cl.encode(orig))}t):")
        print(f"      {orig[:200]}{'...' if len(orig) > 200 else ''}")
        print(f"      L3   ({len(cl.encode(comp))}t):")
        print(f"      {comp[:200]}{'...' if len(comp) > 200 else ''}")


if __name__ == "__main__":
    main()
