# ============================================================
# Helix - update_local_on_windows.ps1 (Windows bootstrap)
#
# Actualiza la instalacion local de Helix desde el repo, preservando
# configs personales (user-profile.md, helix-role.conf, settings.local.json,
# memory operacional, runtime logs).
#
# Igual que install_on_windows.ps1, este script delega a update_local_on_wsl.sh
# via Git Bash. Para correr nativo en WSL, usar update_local_on_wsl.sh directo.
#
# Uso (PowerShell):
#   cd $HOME\helix_asisten
#   .\update_local_on_windows.ps1                # interactivo
#   .\update_local_on_windows.ps1 -DryRun        # ver que haria
#   .\update_local_on_windows.ps1 -NoPull        # asume repo al dia
#   .\update_local_on_windows.ps1 -Yes           # CI / no preguntar
# ============================================================

[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$NoPull,
    [switch]$Yes
)

$ErrorActionPreference = 'Stop'
$RepoDir = $PSScriptRoot
if (-not $RepoDir) { $RepoDir = Get-Location }

# ── 1. Detectar Git Bash ─────────────────────────────────────
$GitBashCandidates = @(
    'C:\Program Files\Git\bin\bash.exe',
    'C:\Program Files (x86)\Git\bin\bash.exe',
    "$env:LOCALAPPDATA\Programs\Git\bin\bash.exe"
)
$GitBash = $null
foreach ($candidate in $GitBashCandidates) {
    if (Test-Path $candidate) { $GitBash = $candidate; break }
}
if (-not $GitBash) {
    $bashCmd = Get-Command bash -ErrorAction SilentlyContinue
    if ($bashCmd) { $GitBash = $bashCmd.Source }
}
if (-not $GitBash) {
    Write-Host '[!] Git Bash no encontrado.' -ForegroundColor Yellow
    Write-Host '    Instalar Git for Windows: https://git-scm.com/download/win'
    Write-Host '    (incluye Git Bash, requerido para correr los hooks bash de Helix)'
    exit 1
}

# ── 2. Convertir path Windows a estilo Git Bash ──────────────
$RepoDirBash = $RepoDir -replace '\\', '/' -replace '^([A-Za-z]):', '/$1'
$RepoDirBash = $RepoDirBash.Substring(0,1).ToLower() + $RepoDirBash.Substring(1)

# ── 3. Construir args para update_local_on_wsl.sh ────────────
$bashArgs = @()
if ($DryRun) { $bashArgs += '--dry-run' }
if ($NoPull) { $bashArgs += '--no-pull' }
if ($Yes)    { $bashArgs += '--yes' }
$argsStr = $bashArgs -join ' '

# ── 4. Ejecutar update_local_on_wsl.sh via Git Bash ──────────
Write-Host ''
Write-Host '------------------------------------------------------------'
Write-Host '  Helix update_local — repo -> local (via Git Bash)'
Write-Host '------------------------------------------------------------'
Write-Host ''

& $GitBash --login -c "cd '$RepoDirBash' && bash update_local_on_wsl.sh $argsStr"
$exitCode = $LASTEXITCODE

if ($exitCode -ne 0) {
    Write-Host ''
    Write-Host "[!] update_local_on_wsl.sh termino con codigo $exitCode" -ForegroundColor Red
    exit $exitCode
}
