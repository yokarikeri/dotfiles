#Requires -Version 5.1
# setup.ps1 — Windows 11 base setup for the WSL dev environment.
#
# What this script does:
#   1. Enables WSL (feature only; distro is installed separately)
#   2. Installs winget packages defined in packages.csv
#   3. Installs PlemolJP NF console font
#   4. Places cloud-init user-data for the WSL distro
#   5. Prints next-step instructions
#
# Usage (run in PowerShell as a regular user — the script self-elevates):
#   powershell -ExecutionPolicy Bypass -File .\setup.ps1
#
# To use with a fork, update $RepoBase below to point to your fork.

# --- Fork customisation point ---
$RepoBase   = 'https://raw.githubusercontent.com/yokarikeri/dotfiles/refs/heads/main'
$FontVersion = 'v3.0.0'

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Helpers

function Write-Step  ($n, $msg) { Write-Host "`n[$n] $msg" -ForegroundColor Yellow }
function Write-Ok    ($msg)     { Write-Host "  [OK] $msg" -ForegroundColor Green }
function Write-Skip  ($msg)     { Write-Host "  [--] $msg" -ForegroundColor DarkGray }
function Write-Warn  ($msg)     { Write-Host "  [!!] $msg" -ForegroundColor Cyan }
function Write-Fail  ($msg)     { Write-Host "  [EE] $msg" -ForegroundColor Red }

# ---------------------------------------------------------------------------
# Step 0: Self-elevate to administrator
#
# wsl --install and HKLM font registration both require admin rights.

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

Write-Step '1/4' 'Enabling WSL...'

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

Write-Step '2/4' 'Installing packages via winget...'

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
# Step 3: Install PlemolJP NF font

Write-Step '3/4' 'Installing PlemolJP NF font...'

$fontUrl     = "https://github.com/yuru7/PlemolJP/releases/download/$FontVersion/PlemolJP_NF_$FontVersion.zip"
$tempZip     = "$env:TEMP\PlemolJP_NF.zip"
$tempExtract = "$env:TEMP\PlemolJP_NF"
$fontsFolder = [Environment]::GetFolderPath('Fonts')
$fontRegPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'

Write-Host '  Downloading font archive...'
Invoke-WebRequest -Uri $fontUrl -OutFile $tempZip -UseBasicParsing

Write-Host '  Extracting...'
if (Test-Path $tempExtract) { Remove-Item $tempExtract -Recurse -Force }
Expand-Archive -Path $tempZip -DestinationPath $tempExtract -Force

# Remove existing PlemolJP entries so a clean re-install works.
Write-Host '  Removing existing PlemolJP fonts...'
$existing = Get-ItemProperty -Path $fontRegPath |
    Get-Member -MemberType NoteProperty |
    Where-Object { $_.Name -match 'PlemolJP' }

foreach ($entry in $existing) {
    $fileName = Get-ItemPropertyValue -Path $fontRegPath -Name $entry.Name
    Remove-ItemProperty -Path $fontRegPath -Name $entry.Name -Force -ErrorAction SilentlyContinue
    $filePath = Join-Path $fontsFolder $fileName
    if (Test-Path $filePath) {
        # Font files in use cannot be deleted; SilentlyContinue lets us proceed.
        Remove-Item $filePath -Force -ErrorAction SilentlyContinue
    }
}

Write-Host '  Installing new fonts...'
$fontDir   = Join-Path $tempExtract "PlemolJP_NF_$FontVersion"
$fontFiles = Get-ChildItem $fontDir -Recurse -Include '*.ttf', '*.otf'

$shell       = New-Object -ComObject Shell.Application
$shellFonts  = $shell.Namespace(0x14)   # 0x14 = special Fonts folder

foreach ($file in $fontFiles) {
    $dest = Join-Path $fontsFolder $file.Name
    if (Test-Path $dest) { Remove-Item $dest -Force -ErrorAction SilentlyContinue }
    $shellFonts.CopyHere($file.FullName, 16)   # 16 = "Yes to All"
}

Remove-Item $tempZip     -Force
Remove-Item $tempExtract -Recurse -Force

Write-Ok 'PlemolJP NF installed.'

# ---------------------------------------------------------------------------
# Step 4: Place cloud-init user-data

Write-Step '4/4' 'Placing cloud-init user-data...'

# Each filename must match the WSL instance name passed to --name.
$cloudInitDir   = Join-Path $env:USERPROFILE '.cloud-init'
$userDataNames  = @(
    'Ubuntu-26.04-devcli.user-data'
    'Ubuntu-26.04-systemd.user-data'
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
(Optional) Finish Windows settings manually:
  - Git Bash: git config --global user.name  "Your Name"
              git config --global user.email "you@example.com"
  - VS Code: install the "Remote Development" extension pack
  - Windows Terminal: set font to "PlemolJP Console NF" in profile settings

(Optional) Fork the dotfiles repo and replace the clone URL in
  $USERPROFILE\.cloud-init\Ubuntu-26.04-devcli.user-data (line ~185)
  with your fork's URL so the WSL distro pulls your own config.

Start a WSL distro (run in PowerShell or Windows Terminal):
  # systemd disabled (daily-use, fast startup)
  wsl --install -d Ubuntu-26.04 --name Ubuntu-26.04-devcli

  # systemd enabled (Docker CE, localectl)
  wsl --install -d Ubuntu-26.04 --name Ubuntu-26.04-systemd

A reboot is recommended to fully apply WSL and font changes.
'@
