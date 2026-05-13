# LIULIAN one-shot bootstrap — Windows (PowerShell + WSL2 backend).
# Requires: Windows 10/11 with WSL2 + virtualization enabled in BIOS.
#
# Usage (PowerShell as user, NOT admin):
#   irm https://raw.githubusercontent.com/liulian-ai/liulian-dev-env/main/scripts/bootstrap-windows.ps1 | iex
#   OR:
#   .\scripts\bootstrap-windows.ps1

$ErrorActionPreference = "Stop"

function Log($msg) { Write-Host "→ $msg" -ForegroundColor Green }
function Die($msg) { Write-Host "✗ $msg" -ForegroundColor Red; exit 1 }

# 0. Sanity
if ($PSVersionTable.PSVersion.Major -lt 5) {
    Die "PowerShell 5+ required. You have $($PSVersionTable.PSVersion)"
}

# 1. WSL2
$wslVer = wsl --status 2>$null
if (-not $wslVer) {
    Log "WSL not installed. Installing WSL2 + Ubuntu…"
    Log "(This requires a reboot. After reboot, re-run this script.)"
    wsl --install -d Ubuntu
    Die "Reboot required. Re-run after restart."
} else {
    Log "WSL detected."
}

# 2. winget for tool installs
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Die "winget not found. Install 'App Installer' from Microsoft Store, then re-run."
}

# 3. Docker Desktop (uses WSL2 backend by default)
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Log "Installing Docker Desktop via winget…"
    winget install --silent --id=Docker.DockerDesktop -e
    Log "Docker Desktop installed. Launch it from Start Menu once to finish setup, then re-run this script."
    Start-Process "Docker Desktop"
    Die "Open Docker Desktop, accept terms, wait for it to start, then re-run."
} else {
    Log "Docker already installed: $(docker --version)"
}

# 4. git + gh + make (chocolatey style via winget)
foreach ($pkg in @("Git.Git", "GitHub.cli")) {
    if (-not (winget list --id $pkg -e 2>$null | Select-String $pkg)) {
        Log "Installing $pkg…"
        winget install --silent --id=$pkg -e
    }
}

# make is most easily run inside WSL — instruct the user
Log "Note: GNU Make + bash are best run inside WSL Ubuntu."
Log "      wsl bash   # drops you into the Linux subsystem"

# 5. Clone the federation
$workspace = if ($env:LIULIAN_WORKSPACE) { $env:LIULIAN_WORKSPACE } else { "$HOME\liulian" }
New-Item -ItemType Directory -Force -Path $workspace | Out-Null
Set-Location $workspace
Log "Workspace: $workspace"

$repos = @("liulian-python","liulian-api","liulian-agent","liulian-ingest","liulian-web","liulian-ops","liulian-design-system","liulian-dev-env")
foreach ($r in $repos) {
    if (Test-Path "$r\.git") {
        Log "Updating $r…"
        git -C $r fetch --quiet origin
    } else {
        Log "Cloning $r…"
        git clone --quiet "https://github.com/liulian-ai/$r.git"
    }
}

Write-Host ""
Write-Host "✓ LIULIAN bootstrap complete." -ForegroundColor Green
Write-Host ""
Write-Host "Next (run these inside WSL for best UX):"
Write-Host "  wsl -d Ubuntu"
Write-Host "  cd $workspace/liulian-dev-env"
Write-Host "  cp .env.example .env"
Write-Host "  make dev && make install"
Write-Host "  make api & make web"
Write-Host ""
Write-Host "Open in browser:"
Write-Host "  http://localhost:8000/api/docs    ← Swagger"
Write-Host "  http://localhost:3000             ← Next.js dev"
Write-Host "  http://localhost:9001             ← MinIO console"
Write-Host ""
