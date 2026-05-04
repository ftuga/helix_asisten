#!/usr/bin/env bash
# ============================================================
# Helix — inject-project.sh (DEPRECATED)
#
# El motor inyectable `helix-engine/` fue descontinuado por Helix Council #1
# (plan v4 D1', 2026-05-04). Helix ahora vive solo en ~/.claude/ (global).
# Para nuevos proyectos no es necesario inyectar nada.
#
# Si necesitás referenciar el motor histórico:
#   git checkout 9b4be73 -- helix-engine/
# ============================================================

cat <<'EOF'
[!] inject-project.sh está deprecated desde v3.15.0.

    helix-engine/ se eliminó del repo (plan v4 D1' — Helix Council #1, 2026-05-04).
    Helix ahora vive solo en ~/.claude/ y aplica a todos tus proyectos.

    Nuevos proyectos: no requieren inyección. Abrí Claude Code en el directorio
    y Helix se activa automáticamente desde ~/.claude/.

    Para recuperar el motor histórico (si tenés un proyecto que dependía de él):
      git -C ~/helix_asisten checkout 9b4be73 -- helix-engine/
EOF

exit 1
