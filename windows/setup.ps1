#Requires -Version 5.1
# setup.ps1 — Windows 11 base setup for the WSL dev environment.
#
# What this script does:
#   1. Enables WSL (feature only; distro is installed separately)
#   2. Installs winget packages defined in packages.csv
#   3. Places cloud-init user-data for the WSL distro
#   4. Prints next-step instructions
#
# Nerd Fonts are not installed here: install-nerd-font.ps1 handles them, and
# it must run as a regular user (see the next steps this script prints).
#
# Usage (run in PowerShell as a regular user — the script self-elevates):
#   powershell -ExecutionPolicy Bypass -File .\setup.ps1
#
# To use with a fork, update $RepoBase below to point to your fork.

# --- Fork customisation point ---
$RepoBase   = 'https://raw.githubusercontent.com/yokarikeri/dotfiles/refs/heads/main'

$ErrorActionPreference = 'Stop'
# Windows PowerShell 5.1 redraws the progress bar per chunk, which makes
# Invoke-WebRequest / Expand-Archive many times slower.
$ProgressPreference = 'SilentlyContinue'

# ---------------------------------------------------------------------------
# Helpers

function Write-Step  ($n, $msg) { Write-Host "`n[$n] $msg" -ForegroundColor Yellow }
function Write-Ok    ($msg)     { Write-Host "  [OK] $msg" -ForegroundColor Green }
function Write-Skip  ($msg)     { Write-Host "  [--] $msg" -ForegroundColor DarkGray }
function Write-Warn  ($msg)     { Write-Host "  [!!] $msg" -ForegroundColor Cyan }
function Write-Fail  ($msg)     { Write-Host "  [EE] $msg" -ForegroundColor Red }
function Wait-Enter { Read-Host "`nPress Enter to close this window" | Out-Null }

# The elevated window closes on exit, so keep it open on errors too.
trap {
    Write-Fail $_
    Wait-Enter
    exit 1
}

# ---------------------------------------------------------------------------
# Step 0: Self-elevate to administrator
#
# wsl --install requires admin rights.

$identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)

if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host 'Restarting as administrator...' -ForegroundColor Cyan
    $args = @('-ExecutionPolicy', 'Bypass', '-File', $MyInvocation.MyCommand.Path)
    Start-Process powershell -ArgumentList $args -Verb RunAs
    exit
}

Write-Host 'Windows 11 base setup' -ForegroundColor Cyan
Write-Host "  Repo: $RepoBase"

# ---------------------------------------------------------------------------
# Step 1: Enable WSL

Write-Step '1/3' 'Enabling WSL...'

# --no-distribution installs the WSL feature only; the distro is started
# manually in the last step so the user can choose a name.
wsl --install --no-distribution 2>&1 | ForEach-Object { Write-Host "  $_" }
if ($LASTEXITCODE -eq 0) {
    Write-Ok 'WSL enabled (or was already enabled).'
} else {
    Write-Warn "wsl --install exited with code $LASTEXITCODE — WSL may already be installed."
}

# ---------------------------------------------------------------------------
# Step 2: Install winget packages

Write-Step '2/3' 'Installing packages via winget...'

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Warn 'winget not found — skipping package installation.'
    Write-Warn 'Install the App Installer from the Microsoft Store and re-run.'
} else {
    # Load packages.csv from the local directory, or fetch it from the repo.
    $csvPath = Join-Path $PSScriptRoot 'packages.csv'
    if (Test-Path $csvPath) {
        $rawCsv = Get-Content $csvPath -Raw
    } else {
        Write-Warn 'packages.csv not found locally — downloading from repo...'
        $rawCsv = (Invoke-WebRequest -Uri "$RepoBase/windows/packages.csv" -UseBasicParsing).Content
    }

    # Strip comment lines (lines starting with optional spaces then #).
    $filteredLines = $rawCsv -split "`n" | Where-Object { $_ -notmatch '^\s*#' }
    $packages = $filteredLines -join "`n" | ConvertFrom-Csv

    $wingetCommon = @(
        '--accept-package-agreements',
        '--accept-source-agreements',
        '--silent'
    )

    foreach ($pkg in $packages) {
        $name   = $pkg.Name.Trim()
        $id     = $pkg.Id.Trim()
        $source = $pkg.Source.Trim()

        Write-Host "  $name ($id)..."

        # Check whether the package is already installed to avoid breaking it.
        winget list --id $id -e --source $source *>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Skip "$name is already installed."
            continue
        }

        $installArgs = @('install', '--id', $id, '--source', $source) + $wingetCommon

        $override = $pkg.Override.Trim()
        if ($override -ne '') {
            $installArgs += '--override'
            $installArgs += $override
        }

        winget @installArgs
        if ($LASTEXITCODE -eq 0) {
            Write-Ok "$name installed."
        } else {
            Write-Fail "$name install failed (exit $LASTEXITCODE) — continuing."
        }
    }
}

# ---------------------------------------------------------------------------
# Step 3: Place cloud-init user-data

Write-Step '3/3' 'Placing cloud-init user-data...'

# Each filename must match the WSL instance name passed to --name.
$cloudInitDir   = Join-Path $env:USERPROFILE '.cloud-init'
$userDataNames  = @(
    'Ubuntu-26.04.user-data'
    'Ubuntu-26.04-devcli.user-data'
)

if (-not (Test-Path $cloudInitDir)) { New-Item $cloudInitDir -ItemType Directory | Out-Null }

foreach ($userDataName in $userDataNames) {
    $userDataDest = Join-Path $cloudInitDir $userDataName
    $userDataUrl  = "$RepoBase/windows/cloud-init/$userDataName"

    if (Test-Path $userDataDest) {
        Write-Warn "$userDataDest already exists and will be overwritten."
    }

    Invoke-WebRequest -Uri $userDataUrl -OutFile $userDataDest -UseBasicParsing
    Write-Ok "User-data saved to $userDataDest"
}

# ---------------------------------------------------------------------------
# Done — print next steps

Write-Host "`nSetup complete!" -ForegroundColor Green
Write-Host @'

Next steps
----------
Install a Nerd Font (required)
  The prompt and CLI tools in this environment draw glyphs that only a
  Nerd Font provides, so pick one of:
  - install PlemolJP Console NF with the bundled script, as a REGULAR user
    (not elevated, so it installs for your account only):
      powershell -ExecutionPolicy Bypass -File .\install-nerd-font.ps1
      powershell -ExecutionPolicy Bypass -File .\install-nerd-font.ps1 -List
    (not next to setup.ps1? get it from windows/install-nerd-font.ps1 in the repo)
  - or install any Nerd Font of your choice yourself.
  Then set it as the font in your Windows Terminal / VS Code profile.

(Optional) Finish Windows settings manually:
  - Git Bash: git config --global user.name  "Your Name"
              git config --global user.email "you@example.com"
  - VS Code: install the "Remote Development" extension pack

(Optional) Fork the dotfiles repo and replace the clone URL in
  $USERPROFILE\.cloud-init\Ubuntu-26.04.user-data (line ~182)
  and Ubuntu-26.04-devcli.user-data (line ~188)
  with your fork's URL so the WSL distro pulls your own config.

Start a WSL distro (run in PowerShell or Windows Terminal):
  # main (systemd enabled, Docker CE, localectl)
  wsl --install Ubuntu-26.04

  # optional secondary instance (systemd disabled, daily-use, fast startup)
  wsl --install -d Ubuntu-26.04 --name Ubuntu-26.04-devcli

A reboot is recommended to fully apply the WSL changes.
'@

Wait-Enter
