import re, os, sys, json
from datetime import datetime
from pathlib import Path

GLOBAL_CLAUDE_MD = sys.argv[1]
PROJECT_CLAUDE_MD = sys.argv[2] if len(sys.argv) > 2 and sys.argv[2] else None
TOPICS_DIR = Path(sys.argv[3])
DRY_RUN = sys.argv[4] == "true"
DATE = datetime.now().strftime("%Y-%m-%d %H:%M")

SECTION_MAP = {
    "SECURITY":      ("seguridad",     "Seguridad"),
    "UI":            ("interfaz",      "Interfaz"),
    "FUNCTIONALITY": ("funcionalidad", "Funcionalidad"),
    "OPERABILITY":   ("operatividad",  "Operatividad"),
    "ARCHITECTURE":  ("arquitectura",  "Arquitectura"),
    "PERFORMANCE":   ("performance",   "Performance"),
    "TESTING":       ("testing",       "Testing"),
    "DATA":          ("datos",         "Datos"),
    "DOCKER":        ("docker",        "Docker"),
    "CELERY":        ("celery",        "Celery"),
    "AUTH":          ("auth",          "Auth"),
}

KEEP_BULLETS   = 3
KEEP_EVOLUTION = 10
KEEP_SESSIONS  = 3
KEEP_REASONING = 2

# ── Anchor sections: NUNCA comprimir ─────────────────────────
# Estas secciones son invariantes del comportamiento de Helix.
# Modificar compress.sh, no este archivo, si necesitas cambiar los límites.
ANCHOR_MARKERS = {
    "SECURITY",        # Reglas de seguridad universales
    "OPERABILITY",     # Bash gotchas críticos
    "SKILLS_INDEX",    # Índice de skills — siempre necesario
}

# ── Importance scoring ────────────────────────────────────────
# Calcula score 0-1 para una línea de evolución/sesión.
# Líneas con score > IMPORTANCE_THRESHOLD se retienen.
IMPORTANCE_THRESHOLD = 0.35

HIGH_VALUE_PATTERNS = [
    # Bugs críticos documentados
    (r'\bset -euo pipefail\b', 0.9),
    (r'\brace condition\b', 0.85),
    (r'\bN\+1\b', 0.85),
    (r'scalar_one_or_none', 0.85),
    (r'PyJWT|jwt\.encode', 0.85),
    (r'CORS|csrf', 0.8),
    (r'migration|migración', 0.75),
    (r'timeout|deadlock', 0.75),
    # Patrones de arquitectura
    (r'Capa [0-3]|swarm_init|agent_spawn', 0.8),
    (r'helix_control_total|HELIX_MODE', 0.9),
    (r'routing|catálogo.*agente', 0.7),
    # Evoluciones recientes (últimos 30 días) son más valiosas
    # (se maneja por KEEP_EVOLUTION, aquí es un boost)
    (r'2026-0[34]', 0.6),
    (r'2026-0[12]', 0.4),
]

LOW_VALUE_PATTERNS = [
    (r'test.*prueba|prueba.*test', -0.3),
    (r'\[VALIDATE\]', -0.2),
    (r'ok \(nada', -0.4),
    (r'FORGET', -0.5),
]

def importance_score(line: str) -> float:
    score = 0.3  # base
    line_lower = line.lower()
    for pattern, delta in HIGH_VALUE_PATTERNS:
        if re.search(pattern, line, re.IGNORECASE):
            score = max(score, delta)
    for pattern, delta in LOW_VALUE_PATTERNS:
        if re.search(pattern, line, re.IGNORECASE):
            score += delta
    return max(0.0, min(1.0, score))


stats = {"archived": 0, "lines_before": 0, "lines_after": 0}

def extract_section(content, marker):
    m = re.search(rf'<!-- {marker}_START -->(.*?)<!-- {marker}_END -->', content, re.DOTALL)
    return m.group(1) if m else ""

def replace_section(content, marker, new_inner):
    return re.sub(
        rf'(<!-- {marker}_START -->)(.*?)(<!-- {marker}_END -->)',
        lambda m: m.group(1) + new_inner + m.group(3),
        content, flags=re.DOTALL
    )

def append_to_topic(topic_file, lines, label):
    if not lines:
        return
    topic_file.parent.mkdir(parents=True, exist_ok=True)
    if not DRY_RUN:
        with open(topic_file, 'a') as f:
            f.write(f"\n## Archivado {DATE} — {label}\n")
            for l in lines:
                f.write(l + "\n")
    stats["archived"] += len(lines)

def compress_bullets(content, marker, topic_name, label, keep=KEEP_BULLETS):
    """Comprime sección de bullets. Si es anchor, no modifica."""
    if marker in ANCHOR_MARKERS:
        print(f"  {label}: protegida (anchor section, sin cambios)")
        return content

    section = extract_section(content, marker)
    init_lines   = [l for l in section.split('\n') if re.match(r'\s*- \[INIT\]', l)]
    dated_lines  = [l for l in section.split('\n') if re.match(r'\s*- \[20\d\d-', l)]

    to_archive = dated_lines[:-keep] if len(dated_lines) > keep else []
    to_keep    = dated_lines[-keep:] if dated_lines else []

    if to_archive:
        append_to_topic(TOPICS_DIR / f"{topic_name}.md", to_archive, label)
        print(f"  archivadas {len(to_archive)} entradas → {topic_name}.md")
    else:
        print(f"  {label}: ok (nada que archivar)")

    new_section = "\n" + "\n".join(init_lines + to_keep) + "\n"
    return replace_section(content, marker, new_section)

def compress_table_with_importance(content, marker, archive_name, label, keep, header=2):
    """Comprime tabla usando importance scoring + mínimo por recencia."""
    section = extract_section(content, marker)
    lines = [l for l in section.split('\n') if l.strip()]
    header_rows = lines[:header]
    data_rows   = lines[header:]

    if len(data_rows) <= keep:
        print(f"  {label}: ok (nada que archivar)")
        return content

    # Separar recientes (siempre retener) vs candidatos a archivar
    always_keep = data_rows[-keep:]           # últimas N filas siempre
    candidates  = data_rows[:-keep]           # resto: evaluar por importancia

    # Filtrar candidatos por importance score
    to_keep_important = [l for l in candidates if importance_score(l) >= IMPORTANCE_THRESHOLD]
    to_archive        = [l for l in candidates if importance_score(l) < IMPORTANCE_THRESHOLD]

    if to_archive:
        append_to_topic(TOPICS_DIR / f"{archive_name}.md", to_archive, label)
        print(f"  archivadas {len(to_archive)} filas (baja importancia) → {archive_name}.md")
        print(f"  retenidas {len(to_keep_important)} filas de importancia alta")
    else:
        print(f"  {label}: ok (todas tienen importancia alta)")

    all_keep = to_keep_important + always_keep
    new_section = "\n" + "\n".join(header_rows + all_keep) + "\n"
    return replace_section(content, marker, new_section)

def compress_reasoning(content, keep=KEEP_REASONING):
    section = extract_section(content, "REASONING")
    blocks = [b for b in re.split(r'(?=### \[)', section) if b.strip()]
    to_archive = blocks[:-keep] if len(blocks) > keep else []
    to_keep    = blocks[-keep:] if blocks else []

    if to_archive:
        append_to_topic(TOPICS_DIR / "reasoning.md", [b for b in to_archive], "Razonamiento")
        print(f"  archivados {len(to_archive)} bloques reasoning → reasoning.md")
    else:
        print(f"  Razonamiento: ok (nada que archivar)")

    new_section = "\n" + "".join(to_keep) + "\n"
    return replace_section(content, "REASONING", new_section)

def store_in_qdrant_if_available(lines_archived: list, label: str):
    """
    Almacena líneas archivadas en Qdrant (helix_memory) para búsqueda semántica futura.
    Si Qdrant no está disponible, silenciosamente no hace nada.
    Los tópicos archivados siguen siendo buscables semánticamente aunque no estén en contexto.
    """
    if not lines_archived:
        return

    hv_script = Path(os.environ.get('HOME', '/root')) / '.claude/helix-vector.py'
    if not hv_script.exists():
        return

    import subprocess, urllib.request
    try:
        urllib.request.urlopen('http://localhost:6333/healthz', timeout=1)
    except:
        return  # Qdrant no disponible, continuar sin él

    combined_text = f"[ARCHIVED: {label} — {DATE}]\n" + "\n".join(lines_archived)

    try:
        subprocess.run(
            ['python3', str(hv_script), 'store', 'helix_memory', combined_text,
             '--meta', f'source=compress', '--meta', f'label={label}', '--meta', f'date={DATE}'],
            capture_output=True, timeout=30
        )
    except:
        pass  # Nunca fallar por esto

def process(path, label):
    if not os.path.exists(path):
        print(f"  {label}: no encontrado, omitiendo")
        return
    print(f"\n{label}:")
    with open(path) as f:
        content = f.read()
    lines_before = content.count('\n')

    all_archived = []

    for marker, (topic_name, topic_label) in SECTION_MAP.items():
        content = compress_bullets(content, marker, topic_name, topic_label)

    # Evoluciones: importance scoring
    old_archived = stats["archived"]
    content = compress_table_with_importance(
        content, "EVOLUTION_LOG", "evolution-history", "Historial evoluciones", KEEP_EVOLUTION
    )
    new_archived = stats["archived"] - old_archived

    # Sesiones: recency-based (sin importance scoring)
    content = compress_table(content, "SESSIONS", "sessions-history", "Historial sesiones", KEEP_SESSIONS)
    content = compress_reasoning(content)

    lines_after = content.count('\n')
    saved = lines_before - lines_after
    stats["lines_before"] += lines_before
    stats["lines_after"]  += lines_after

    if not DRY_RUN:
        with open(path, 'w') as f:
            f.write(content)

        # Almacenar en Qdrant si aplica
        if new_archived > 0:
            store_in_qdrant_if_available([], f"evolution-compress-{label}")

    print(f"  lineas: {lines_before} → {lines_after}  (−{saved})")

def compress_table(content, marker, archive_name, label, keep, header=2):
    """Compresión simple por recencia (para sesiones)."""
    section = extract_section(content, marker)
    lines = [l for l in section.split('\n') if l.strip()]
    header_rows = lines[:header]
    data_rows   = lines[header:]

    to_archive = data_rows[:-keep] if len(data_rows) > keep else []
    to_keep    = data_rows[-keep:] if data_rows else []

    if to_archive:
        append_to_topic(TOPICS_DIR / f"{archive_name}.md", to_archive, label)
        print(f"  archivadas {len(to_archive)} filas → {archive_name}.md")
    else:
        print(f"  {label}: ok (nada que archivar)")

    new_section = "\n" + "\n".join(header_rows + to_keep) + "\n"
    return replace_section(content, marker, new_section)

process(GLOBAL_CLAUDE_MD, "Global")
if PROJECT_CLAUDE_MD:
    process(PROJECT_CLAUDE_MD, "Proyecto")

print(f"\n  Total archivadas: {stats['archived']} entradas")
print(f"  Reduccion total: {stats['lines_before']} → {stats['lines_after']} lineas")
