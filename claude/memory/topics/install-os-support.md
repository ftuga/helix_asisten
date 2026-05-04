# Helix install — soporte de OS

> Generado en sesión #22 (2026-05-04) como parte de FASE 6 OPCIÓN E.
> Define qué OS están soportados por `check-prereqs.sh` v2 y qué hacer en los no soportados.

---

## Matriz de soporte

| OS | Estado v1 | Detección automática | Comandos copy-paste |
|---|---|---|---|
| Ubuntu (≥20.04) | ✅ Soportado | sí | sí |
| Debian (≥11) | ✅ Soportado | sí | sí |
| WSL2 (Ubuntu/Debian) | ✅ Soportado | sí (vía `/proc/version`) | sí (con notas WSL para Docker) |
| Linux Mint | ⚠ Compatible (apt) | sí (es apt) | sí |
| macOS | ❌ No soportado v1 | no | manual abajo |
| Fedora / RHEL / CentOS / Rocky | ❌ No soportado v1 | no | manual abajo |
| Arch / Manjaro | ❌ No soportado v1 | no | manual abajo |
| Alpine | ❌ No soportado v1 | no | manual abajo |

---

## Por qué v1 solo cubre apt

OPCIÓN E del council #4 priorizó alcance ejecutable inmediato sobre cobertura. Las máquinas activas del creator son WSL Ubuntu. Cubrir dnf/brew/pacman en v1 multiplicaría la superficie de testing sin demanda real verificada. Roadmap v2 abre detección automática multi-OS cuando exista demanda documentada (≥3 reportes de fricción real).

---

## macOS (manual hasta v2)

```bash
# Homebrew si no existe
[ -x "$(command -v brew)" ] || /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Deps base
brew install git curl rsync zstd python3 node

# Docker Desktop (manual, GUI):
#   https://docs.docker.com/desktop/install/mac-install/

# Ollama
brew install ollama
brew services start ollama

# Claude Code CLI
npm install -g @anthropic-ai/claude-code

# Modelos Ollama
ollama pull nomic-embed-text
```

Después correr `bash install.sh`. El check-prereqs.sh actual fallará con "OS no soportado" → editar el bloque `if [[ "$(uname -s)" != "Linux" ]]` o esperar v2.

---

## Fedora / RHEL / Rocky (dnf, manual)

```bash
sudo dnf install -y git curl rsync zstd python3 python3-pip nodejs npm

# Docker
sudo dnf install -y docker
sudo systemctl enable --now docker
sudo usermod -aG docker $USER

# Ollama
curl -fsSL https://ollama.com/install.sh | sh

# Claude CLI
sudo npm install -g @anthropic-ai/claude-code

# Modelos
ollama pull nomic-embed-text
```

---

## Arch / Manjaro (pacman, manual)

```bash
sudo pacman -S --noconfirm git curl rsync zstd python python-pip nodejs npm docker
sudo systemctl enable --now docker
sudo usermod -aG docker $USER

curl -fsSL https://ollama.com/install.sh | sh
sudo npm install -g @anthropic-ai/claude-code
ollama pull nomic-embed-text
```

---

## Roadmap v2 (cuando aplique)

Trigger para implementar v2:
- ≥3 reportes documentados de fricción de instalación en OS no-apt, **o**
- Decisión explícita del creator de expandir alcance.

Implementación v2:
- `detect_pkg_manager()` → apt | dnf | yum | pacman | brew | apk
- Tabla por gestor: paquete → comando install
- Comandos copy-paste se generan según gestor detectado
- macOS: detectar Homebrew, sugerir install si falta

Hasta entonces, OS no-apt obtienen FAIL temprano con puntero a este doc.
