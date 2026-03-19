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

def compress_table(content, marker, archive_name, label, keep, header=2):
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

def process(path, label):
    if not os.path.exists(path):
        print(f"  {label}: no encontrado, omitiendo")
        return
    print(f"\n{label}:")
    with open(path) as f:
        content = f.read()
    lines_before = content.count('\n')

    for marker, (topic_name, topic_label) in SECTION_MAP.items():
        content = compress_bullets(content, marker, topic_name, topic_label)
    content = compress_table(content, "EVOLUTION_LOG", "evolution-history", "Historial evoluciones", KEEP_EVOLUTION)
    content = compress_table(content, "SESSIONS",      "sessions-history",  "Historial sesiones",   KEEP_SESSIONS)
    content = compress_reasoning(content)

    lines_after = content.count('\n')
    saved = lines_before - lines_after
    stats["lines_before"] += lines_before
    stats["lines_after"]  += lines_after

    if not DRY_RUN:
        with open(path, 'w') as f:
            f.write(content)

    print(f"  lineas: {lines_before} → {lines_after}  (−{saved})")

process(GLOBAL_CLAUDE_MD, "Global")
if PROJECT_CLAUDE_MD:
    process(PROJECT_CLAUDE_MD, "Proyecto")

print(f"\n  Total archivadas: {stats['archived']} entradas")
print(f"  Reduccion total: {stats['lines_before']} → {stats['lines_after']} lineas")
