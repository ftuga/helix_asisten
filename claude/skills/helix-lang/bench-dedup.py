#!/usr/bin/env python3
"""
Bench v4 dedup — extraer citations repetidas a manifest unico + reemplazar
con S:hash refs.

Mide ahorro real de la "regla rota": dejar que cada rol restablezca su contexto.
"""
import re
import sys
import hashlib
from pathlib import Path
from collections import Counter, defaultdict

import tiktoken


def extract_citations(text: str) -> list:
    """Extrae lineas/strings que parecen citations (paths, refs)."""
    cites = []
    # Patrones: "MATERIAL.md §N: ...", "round_N_role.field: ...", "CLAUDE.md ...", "evolution #N"
    # Capturamos cualquier linea YAML que sea una cita estructurada.
    lines = text.splitlines()
    for line in lines:
        stripped = line.strip()
        # Strings entre comillas con patrones de cita
        if re.search(r'"(MATERIAL\.md|CLAUDE\.md|round_\d+|evolution #\d+|context_pack|expert_summons)', stripped):
            cites.append(stripped)
        elif re.search(r'^- ".*\.md', stripped):
            cites.append(stripped)
    return cites


def normalize_citation(c: str) -> str:
    """Normaliza una cita para detectar duplicates con whitespace tolerance."""
    return re.sub(r"\s+", " ", c.strip().rstrip(','))


def hash_short(s: str) -> str:
    return hashlib.sha1(s.encode()).hexdigest()[:6]


def main():
    if len(sys.argv) < 2:
        print("Uso: bench-dedup.py <session_dir>", file=sys.stderr)
        sys.exit(1)

    session_dir = Path(sys.argv[1])
    outputs_dir = session_dir / "outputs"
    yaml_files = sorted(outputs_dir.glob("*.yaml"))
    if not yaml_files:
        print(f"ERROR: no outputs en {outputs_dir}", file=sys.stderr)
        sys.exit(1)

    cl = tiktoken.get_encoding("cl100k_base")

    # 1. Recolectar citations de todos los archivos
    cite_counter = Counter()
    cites_per_file = defaultdict(list)

    for yf in yaml_files:
        text = yf.read_text()
        cites = extract_citations(text)
        for c in cites:
            n = normalize_citation(c)
            cite_counter[n] += 1
            cites_per_file[yf.name].append(n)

    # 2. Identificar citations que aparecen en >=2 archivos (= candidates a dedup)
    repeated = {c: count for c, count in cite_counter.items() if count >= 2}

    # 3. Construir manifest compartido de las repeated
    manifest = {}
    for c in repeated:
        h = hash_short(c)
        manifest[c] = h

    # 4. Calcular ahorro: cada cita repetida >= 2 veces se transmite
    #    una vez en el manifest + N refs cortas (S:hash).
    #    Vs. v2.1: la cita se transmite N veces inline.
    total_orig = 0
    total_dedup = 0
    total_repeated_inline_tokens = 0

    for yf in yaml_files:
        text = yf.read_text()
        orig_t = len(cl.encode(text))
        total_orig += orig_t

        # Replace cada cita repetida con un S:hash ref
        deduped = text
        for c, h in manifest.items():
            # Solo reemplaza ocurrencias COMPLETAS de la cita en el archivo
            ref = f'"S:{h}"'
            count_in_file = deduped.count(c)
            if count_in_file > 0:
                deduped = deduped.replace(c, ref)

        dedup_t = len(cl.encode(deduped))
        total_dedup += dedup_t

    # Manifest header (transmitido una vez por sesion)
    manifest_text = "# manifest_session: cited references\n"
    for c, h in sorted(manifest.items()):
        manifest_text += f"S:{h}: {c}\n"
    manifest_t = len(cl.encode(manifest_text))

    # Total con dedup = manifest (1 vez) + outputs reescritos con refs
    total_dedup_with_manifest = total_dedup + manifest_t
    savings = total_orig - total_dedup_with_manifest
    pct = savings / total_orig * 100 if total_orig else 0

    print(f"# Bench v4 dedup — citations cross-rol")
    print(f"# Session: {session_dir.name}")
    print(f"# N files: {len(yaml_files)}")
    print()
    print(f"Citations encontradas (total):    {sum(cite_counter.values())}")
    print(f"Citations unicas:                 {len(cite_counter)}")
    print(f"Citations repetidas (>=2 files):  {len(repeated)}")
    print(f"  Top repeated frequency:")
    for c, n in sorted(repeated.items(), key=lambda x: -x[1])[:5]:
        c_short = c[:80] + "..." if len(c) > 80 else c
        print(f"    [{n}x] {c_short}")
    print()
    print(f"{'METRIC':<40} {'TOKENS':>10}")
    print("-" * 55)
    print(f"{'Original total':<40} {total_orig:>10}")
    print(f"{'Outputs deduped (sin manifest)':<40} {total_dedup:>10}")
    print(f"{'Manifest header (1 vez por sesion)':<40} {manifest_t:>10}")
    print(f"{'Total con manifest':<40} {total_dedup_with_manifest:>10}")
    print(f"{'AHORRO ABSOLUTO':<40} {savings:>+10}")
    print(f"{'AHORRO % SOBRE CORPUS FULL':<40} {pct:>+9.2f}%")
    print()
    print(f"# Comparacion vs otros benches:")
    print(f"  v3 lexical (handoff syntax):    +0.30%")
    print(f"  caveman-on-prose L3b (ES+EN):   +7.55%")
    print(f"  v4 dedup (este bench):          {pct:+.2f}%")
    print(f"  Caveman target Capa 1:          ~50-65%")


if __name__ == "__main__":
    main()
