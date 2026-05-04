# ============================================================
# Helix - install_on_windows.ps1 (Windows bootstrap)
#
# Helix usa hooks bash que requieren un entorno POSIX. En Windows hay 2
# opciones soportadas:
#   1. Git Bash (incluido en Git for Windows) - RECOMENDADO
#   2. WSL2 (Ubuntu/Debian)
#
# Este script valida prerequisitos Windows y delega a install_on_wsl.sh via Git Bash.
# Si el usuario esta en WSL, debe correr install_on_wsl.sh nativo (no este .ps1).
#
# Uso (PowerShell):
#   cd $HOME\helix_asisten
#   .\install_on_windows.ps1                # layout split (default v3.16+)
#   $env:HELIX_LAYOUT='legacy'; .\install_on_windows.ps1
# ============================================================

[CmdletBinding()]
param(
    [string]$Layout = $env:HELIX_LAYOUT
)

if (-not $Layout) { $Layout = 'split' }

$ErrorActionPreference = 'Stop'
$RepoDir = $PSScriptRoot
if (-not $RepoDir) { $RepoDir = Get-Location }

Write-Host ''
Write-Host '============================================================'
Write-Host '  Helix - Windows installer (PowerShell bootstrap)'
Write-Host '============================================================'
Write-Host ''
Write-Host "Repo: $RepoDir"
Write-Host "Layout: $Layout"
Write-Host ''

# ── 1. Detectar Git Bash ─────────────────────────────────────
$GitBashCandidates = @(
    'C:\Program Files\Git\bin\bash.exe',
    'C:\Program Files (x86)\Git\bin\bash.exe',
    "$env:LOCALAPPDATA\Programs\Git\bin\bash.exe"
)

$GitBash = $null
foreach ($candidate in $GitBashCandidates) {
    if (Test-Path $candidate) {
        $GitBash = $candidate
        break
    }
}

if (-not $GitBash) {
    # Buscar en PATH como fallback
    $bashCmd = Get-Command bash -ErrorAction SilentlyContinue
    if ($bashCmd) { $GitBash = $bashCmd.Source }
}

if (-not $GitBash) {
    Write-Host '[!] Git Bash no encontrado.' -ForegroundColor Yellow
    Write-Host ''
    Write-Host '    Helix requiere un entorno POSIX para sus hooks bash.'
    Write-Host '    Opciones:'
    Write-Host ''
    Write-Host '    1. Git for Windows (incluye Git Bash, recomendado):'
    Write-Host '       https://git-scm.com/download/win'
    Write-Host ''
    Write-Host '    2. WSL2 (Ubuntu / Debian):'
    Write-Host '       wsl --install -d Ubuntu'
    Write-Host '       Luego ejecutar install_on_wsl.sh dentro de WSL.'
    Write-Host ''
    exit 1
}

Write-Host "[OK] Git Bash detectado: $GitBash" -ForegroundColor Green

# ── 2. Validar Claude Code disponible ────────────────────────
$claudeCmd = Get-Command claude -ErrorAction SilentlyContinue
if (-not $claudeCmd) {
    Write-Host ''
    Write-Host '[!] claude CLI no esta en el PATH de Windows.' -ForegroundColor Yellow
    Write-Host '    Instalar Claude Code: https://docs.claude.com/en/docs/claude-code'
    Write-Host '    (Helix se instalara igual; el wrapper helix avisara al ejecutarlo si falta claude)'
    Write-Host ''
}
else {
    Write-Host "[OK] claude CLI: $($claudeCmd.Source)" -ForegroundColor Green
}

# ── 3. Validar Python (para hooks que usan python) ───────────
$pythonCmd = Get-Command python -ErrorAction SilentlyContinue
if (-not $pythonCmd) { $pythonCmd = Get-Command python3 -ErrorAction SilentlyContinue }
if ($pythonCmd) {
    $pyVer = & $pythonCmd.Source --version 2>&1
    Write-Host "[OK] Python: $pyVer" -ForegroundColor Green
}
else {
    Write-Host '[!] Python no encontrado en PATH.' -ForegroundColor Yellow
    Write-Host '    Algunos hooks Helix lo requieren. Instalar: https://www.python.org/downloads/'
}

Write-Host ''
Write-Host '------------------------------------------------------------'
Write-Host '  Delegando a install_on_wsl.sh via Git Bash...'
Write-Host '------------------------------------------------------------'
Write-Host ''

# ── 4. Convertir path Windows a estilo Git Bash ──────────────
$RepoDirBash = $RepoDir -replace '\\', '/' -replace '^([A-Za-z]):', '/$1'
$RepoDirBash = $RepoDirBash.Substring(0,1).ToLower() + $RepoDirBash.Substring(1)

# ── 5. Ejecutar install_on_wsl.sh ───────────────────────────────────
$env:HELIX_LAYOUT = $Layout
& $GitBash --login -c "cd '$RepoDirBash' && bash install_on_wsl.sh"
$exitCode = $LASTEXITCODE

if ($exitCode -ne 0) {
    Write-Host ''
    Write-Host "[!] install_on_wsl.sh termino con codigo $exitCode" -ForegroundColor Red
    exit $exitCode
}

Write-Host ''
Write-Host '============================================================'
Write-Host '  Helix instalado en Windows (layout=' -NoNewline
Write-Host $Layout -NoNewline -ForegroundColor Green
Write-Host ')'
Write-Host '============================================================'
Write-Host ''
Write-Host '  Como usar Helix en Windows:'
Write-Host ''
Write-Host '    Git Bash:'
Write-Host '      helix              # arranca Helix (CLAUDE_CONFIG_DIR aislado)'
Write-Host '      claude             # Claude Code stock'
Write-Host ''
Write-Host '    PowerShell / cmd:'
Write-Host '      bash -c helix      # delega a Git Bash'
Write-Host ''
Write-Host '  El alias 'helix' fue agregado al ~/.bashrc de Git Bash.'
Write-Host ''
