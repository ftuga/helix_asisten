# Helix install — soporte de OS

> Generado en sesión #22 (2026-05-04) como parte de FASE 6 OPCIÓN E.
> Extendido 2026-05-12: Windows nativo + Git Bash soportado (v2.1).
> Define qué OS están soportados por `check-prereqs.sh` y qué hacer en los no soportados.

---

## Matriz de soporte

| OS | Estado | Detección automática | Comandos copy-paste |
|---|---|---|---|
| Ubuntu (≥20.04) | ✅ Soportado | sí | sí (apt) |
| Debian (≥11) | ✅ Soportado | sí | sí (apt) |
| WSL2 (Ubuntu/Debian) | ✅ Soportado | sí (vía `/proc/version`) | sí (apt + notas Docker) |
| Linux Mint | ⚠ Compatible (apt) | sí (es apt) | sí |
| **Windows nativo + Git Bash** | ✅ Soportado (v2.1, 2026-05-12) | sí (`uname -s` ∈ `MINGW*`/`MSYS*`/`CYGWIN*`) | sí (winget) |
| macOS | ❌ No soportado | no | manual abajo |
| Fedora / RHEL / CentOS / Rocky | ❌ No soportado | no | manual abajo |
| Arch / Manjaro | ❌ No soportado | no | manual abajo |
| Alpine | ❌ No soportado | no | manual abajo |

---

## Por qué v1 solo cubría apt

OPCIÓN E del council #4 priorizó alcance ejecutable inmediato sobre cobertura. Las máquinas activas del creator son WSL Ubuntu. Cubrir dnf/brew/pacman en v1 multiplicaría la superficie de testing sin demanda real verificada. Roadmap v2 abre detección automática multi-OS cuando exista demanda documentada (≥3 reportes de fricción real).

Windows nativo (Git Bash) se incorporó en v2.1 por reporte de fricción real en equipo cliente (taltamar, 2026-05-12): la `install_on_windows.ps1` prometía Git Bash pero `check-prereqs.sh` cortaba en el gate `uname -s != Linux`.

---

## Windows nativo (Git Bash / MSYS2 / Cygwin) — v2.1

Soportado vía winget (Windows 10 ≥ 1809 y Windows 11). `install_on_windows.ps1` valida prerequisitos Windows (Git Bash, claude CLI, Python) y delega a `install_on_wsl.sh` corriendo dentro de Git Bash. `check-prereqs.sh` detecta `uname -s` ∈ {`MINGW*`, `MSYS*`, `CYGWIN*`} → `IS_WIN_NATIVE=1`, salta `dpkg`/`apt`, acepta `node.exe`/`python.exe`/`docker.exe` desde `/c/Program Files/...` sin pedir nativo Linux, y emite copy-paste `winget install` en vez de apt.

### Prerequisitos copy-paste (winget, desde PowerShell)

```powershell
winget install --id Git.Git              -e --source winget
winget install --id Python.Python.3.12   -e --source winget
winget install --id OpenJS.NodeJS.LTS    -e --source winget
winget install --id Docker.DockerDesktop -e --source winget
winget install --id Ollama.Ollama        -e --source winget
# Cerrar/reabrir PowerShell o Git Bash tras cada instalación para refrescar PATH.
npm install -g @anthropic-ai/claude-code
```

```bash
# Una vez Ollama esté corriendo (desde Git Bash o PowerShell):
ollama pull nomic-embed-text
```

### Instalación

```powershell
# PowerShell, en la raíz del repo:
cd $HOME\helix_asisten
.\install_on_windows.ps1
```

El instalador arranca Git Bash internamente y corre `install_on_wsl.sh` con `uname -s` Windows → `IS_WIN_NATIVE=1` activa los branches adaptados (mensajes Docker Desktop, `pip` además de `pip3`, paths Chrome/Edge para puppeteer).

### Limitaciones conocidas en Windows nativo

- **`helix-hwprobe.sh`** asume Linux (`/proc/cpuinfo`, `lscpu`, `free`). En Windows fallará → `capa0-policy` queda en estado degradado (`OFF`/`OPT_IN`). No bloquea instalación; deuda documentada para v2.2.
- **`~/.local/bin`** se crea pero no está en PATH por defecto en Git Bash. Los symlinks `hv` y `helix-project-index` quedan creados; hay que agregar `%USERPROFILE%\.local\bin` al PATH manualmente, o invocar con path completo.
- **Qdrant via Docker Desktop**: el daemon arranca cuando el usuario abre la app, no como servicio del sistema. Si Docker Desktop está cerrado, `qdrant` queda fuera de servicio. El bootstrap del índice vectorial detecta esto y salta sin error.

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
