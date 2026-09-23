#Requires -Version 5.1
# setup.ps1 — Windows 11 base setup for the WSL dev environment.
#
# What this script does:
#   1. Enables WSL (feature only; distro is installed separately)
#   2. Installs winget packages defined in packages.csv
#   3. Places cloud-init user-data for the WSL distro, substituting the
#      values given by the options below
#   4. Prints next-step instructions
#
# Nerd Fonts are not installed here: install-nerd-font.ps1 handles them, and
# it must run as a regular user (see the next steps this script prints).
#
# Usage (run in PowerShell as a regular user — the script self-elevates):
#   powershell -ExecutionPolicy Bypass -File .\setup.ps1 [options]
#
# Options:
#   -Interactive          Ask which steps, packages and user-data files to use,
#                         and the user-data values below
#   -SkipWsl              Skip step 1
#   -SkipPackages         Skip step 2
#   -SkipUserData         Skip step 3
#   -Locale <locale>      LANG for the distro (default: ja_JP.UTF-8)
#   -Timezone <tz>        IANA timezone (default: Asia/Tokyo)
#   -UserName <name>      Linux user name (default: wsl-user)
#   -DotfilesRepo <url>   Repo cloned by cloud-init (default: derived from $RepoBase)
#   -Agents <list>        AI agent CLIs to install, comma-separated or "all":
#                         claude, codex, antigravity, copilot (default: none;
#                         only Ubuntu-26.04.user-data has the installers)
#
# Example:
#   powershell -ExecutionPolicy Bypass -File .\setup.ps1 -Locale en_US.UTF-8 -Timezone Europe/London
#
# To use with a fork, update $RepoBase below to point to your fork.

param(
    [switch]$Interactive,
    [switch]$SkipWsl,
    [switch]$SkipPackages,
    [switch]$SkipUserData,
    [string]$Locale,
    [string]$Timezone,
    [string]$UserName,
    [string]$DotfilesRepo,
    [string]$Agents
)

# --- Fork customisation point ---
$RepoBase   = 'https://raw.githubusercontent.com/yokarikeri/dotfiles/refs/heads/main'

$ErrorActionPreference = 'Stop'
# Windows PowerShell 5.1 redraws the progress bar per chunk, which makes
# Invoke-WebRequest / Expand-Archive many times slower.
$ProgressPreference = 'SilentlyContinue'

# Values written in windows/cloud-init/*.user-data; step 3 replaces them.
$TemplateValues = @{
    Locale       = 'ja_JP.UTF-8'
    Timezone     = 'Asia/Tokyo'
    UserName     = 'wsl-user'
    DotfilesRepo = 'https://github.com/yokarikeri/dotfiles.git'
}

$ValuePatterns = @{
    Locale       = '^(C|[a-z]{2,3}_[A-Z]{2})\.UTF-8$'
    Timezone     = '^[A-Za-z0-9_+-]+(/[A-Za-z0-9_+-]+)*$'
    UserName     = '^[a-z_][a-z0-9_-]{0,31}$'
    DotfilesRepo = '^[^\s''"$`\\]+$'
}

# Commented-out installer lines in the user-data; -Agents uncomments them.
$AgentInstallers = [ordered]@{
    claude      = @{ Name = 'Claude Code';        Url = 'https://claude.ai/install.sh' }
    codex       = @{ Name = 'Codex CLI';          Url = 'https://chatgpt.com/codex/install.sh' }
    antigravity = @{ Name = 'Antigravity CLI';    Url = 'https://antigravity.google/cli/install.sh' }
    copilot     = @{ Name = 'GitHub Copilot CLI'; Url = 'https://gh.io/copilot-install' }
}
$agentKeys = '(' + (@($AgentInstallers.Keys) -join '|') + ')'
$ValuePatterns.Agents = "^($agentKeys(,$agentKeys)*)?$"

$Agents = ($Agents -replace '\s', '').ToLower()
if ($Agents -eq 'all') { $Agents = @($AgentInstallers.Keys) -join ',' }

if (-not $Locale)   { $Locale   = $TemplateValues.Locale }
if (-not $Timezone) { $Timezone = $TemplateValues.Timezone }
if (-not $UserName) { $UserName = $TemplateValues.UserName }
if (-not $DotfilesRepo) {
    if ($RepoBase -match '^https://raw\.githubusercontent\.com/([^/]+)/([^/]+)/') {
        $DotfilesRepo = "https://github.com/$($Matches[1])/$($Matches[2]).git"
    } else {
        $DotfilesRepo = $TemplateValues.DotfilesRepo
    }
}

# Each filename must match the WSL instance name passed to --name.
$userDataNames = @(
    'Ubuntu-26.04.user-data'
    'Ubuntu-26.04-devcli.user-data'
)

# ---------------------------------------------------------------------------
# Helpers

function Write-Step  ($n, $msg) { Write-Host "`n[$n] $msg" -ForegroundColor Yellow }
function Write-Ok    ($msg)     { Write-Host "  [OK] $msg" -ForegroundColor Green }
function Write-Skip  ($msg)     { Write-Host "  [--] $msg" -ForegroundColor DarkGray }
function Write-Warn  ($msg)     { Write-Host "  [!!] $msg" -ForegroundColor Cyan }
function Write-Fail  ($msg)     { Write-Host "  [EE] $msg" -ForegroundColor Red }
function Wait-Enter { Read-Host "`nPress Enter to close this window" | Out-Null }

function Read-YesNo ([string]$prompt, [bool]$default = $true) {
    $hint = if ($default) { '[Y/n]' } else { '[y/N]' }
    while ($true) {
        $answer = (Read-Host "  $prompt $hint").Trim()
        if ($answer -eq '')              { return $default }
        if ($answer -match '^(y|yes)$')  { return $true }
        if ($answer -match '^(n|no)$')   { return $false }
    }
}

function Read-Value ([string]$prompt, [string]$default, [string]$pattern) {
    while ($true) {
        $answer = (Read-Host "  $prompt [$default]").Trim()
        if ($answer -eq '') { return $default }
        if ($answer -cmatch $pattern) { return $answer }
        Write-Warn "Invalid value: $answer"
    }
}

function Assert-Values {
    foreach ($name in $ValuePatterns.Keys) {
        $value = Get-Variable $name -ValueOnly
        if ($value -cnotmatch $ValuePatterns[$name]) {
            throw "Invalid -${name}: $value"
        }
    }
    if ($UserName -eq 'root') { throw 'Invalid -UserName: root' }
}

function Get-Packages {
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
    return @($filteredLines -join "`n" | ConvertFrom-Csv)
}

function Set-TemplateValue ([string]$text, [string]$pattern, [string]$value, [string]$label) {
    # Warn instead of failing so a template change doesn't block the rest.
    if ($text -cnotmatch $pattern) {
        Write-Warn "$label not found in the template — left unchanged."
        return $text
    }
    return [regex]::Replace($text, $pattern, $value.Replace('$', '$$'))
}

function Edit-UserData ([string]$text) {
    if ($Timezone -cne $TemplateValues.Timezone) {
        $text = Set-TemplateValue $text '(?m)^timezone: .*$' "timezone: $Timezone" 'timezone'
    }
    if ($Locale -cne $TemplateValues.Locale) {
        $text = Set-TemplateValue $text ([regex]::Escape($TemplateValues.Locale)) $Locale 'locale'
        if ($Locale -notlike 'ja_*') {
            # Japanese language/man page packages are not needed for other locales.
            $text = [regex]::Replace($text, '(?m)^(\s*)- ((?:language-pack|manpages)-ja\b)', '$1# - $2')
        }
    }
    if ($UserName -cne $TemplateValues.UserName) {
        $pattern = '(?<![\w-])' + [regex]::Escape($TemplateValues.UserName) + '(?![\w-])'
        $text = Set-TemplateValue $text $pattern $UserName 'user name'
    }
    if ($DotfilesRepo -cne $TemplateValues.DotfilesRepo) {
        $text = Set-TemplateValue $text ([regex]::Escape($TemplateValues.DotfilesRepo)) $DotfilesRepo 'dotfiles repo URL'
    }
    foreach ($key in ($Agents -split ',' | Where-Object { $_ })) {
        $agent   = $AgentInstallers[$key]
        $pattern = '(?m)^(\s*)#\s*-\s*(\S.*' + [regex]::Escape($agent.Url) + '.*)$'
        if ($text -cmatch $pattern) {
            $text = [regex]::Replace($text, $pattern, '$1- $2')
        } else {
            Write-Skip "$($agent.Name) installer is not in this template."
        }
    }
    return $text
}

# The elevated window closes on exit, so keep it open on errors too.
trap {
    Write-Fail $_
    Wait-Enter
    exit 1
}

Assert-Values

# ---------------------------------------------------------------------------
# Step 0: Self-elevate to administrator
#
# wsl --install requires admin rights.

$identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)

if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host 'Restarting as administrator...' -ForegroundColor Cyan
    # Start-Process joins the list with spaces, so quote each value.
    $elevateArgs = @('-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"")
    foreach ($param in $PSBoundParameters.GetEnumerator()) {
        if ($param.Value -is [switch]) {
            if ($param.Value) { $elevateArgs += "-$($param.Key)" }
        } else {
            $elevateArgs += "-$($param.Key)", "`"$($param.Value)`""
        }
    }
    Start-Process powershell -ArgumentList $elevateArgs -Verb RunAs
    exit
}

Write-Host 'Windows 11 base setup' -ForegroundColor Cyan
Write-Host "  Repo: $RepoBase"

$hasWinget = [bool](Get-Command winget -ErrorAction SilentlyContinue)
$packages  = $null

# ---------------------------------------------------------------------------
# Interactive mode: collect every answer up front so the rest runs unattended.

if ($Interactive) {
    Write-Host "`nChoose what to run (press Enter to accept the default)." -ForegroundColor Cyan

    $SkipWsl = -not (Read-YesNo '1. Enable WSL?' (-not $SkipWsl))

    $SkipPackages = -not (Read-YesNo '2. Install winget packages?' (-not $SkipPackages))
    if (-not $SkipPackages -and $hasWinget) {
        $packages = Get-Packages
        if (Read-YesNo '   Choose packages one by one?' $false) {
            $packages = @($packages | Where-Object { Read-YesNo "   - $($_.Name.Trim())?" })
        }
    }

    $SkipUserData = -not (Read-YesNo '3. Place cloud-init user-data?' (-not $SkipUserData))
    if (-not $SkipUserData) {
        $userDataNames = @($userDataNames | Where-Object { Read-YesNo "   - ${_}?" })
        if ($userDataNames.Count -eq 0) { $SkipUserData = $true }
    }
    if (-not $SkipUserData) {
        Write-Host "`n  User-data values:" -ForegroundColor Cyan
        $Locale       = Read-Value 'Locale (e.g. en_US.UTF-8)'      $Locale       $ValuePatterns.Locale
        $Timezone     = Read-Value 'Timezone (e.g. Europe/London)'  $Timezone     $ValuePatterns.Timezone
        $UserName     = Read-Value 'Linux user name'                $UserName     $ValuePatterns.UserName
        $DotfilesRepo = Read-Value 'Dotfiles repo URL'              $DotfilesRepo $ValuePatterns.DotfilesRepo

        Write-Host "`n  AI agents to install (Ubuntu-26.04 only):" -ForegroundColor Cyan
        $current = $Agents -split ','
        $Agents = @(foreach ($key in $AgentInstallers.Keys) {
            if (Read-YesNo "   - $($AgentInstallers[$key].Name)?" ($current -contains $key)) { $key }
        }) -join ','
        Assert-Values
    }

    Write-Host "`n  Summary:" -ForegroundColor Cyan
    Write-Host "    1. Enable WSL:        $(if ($SkipWsl) { 'skip' } else { 'yes' })"
    if ($SkipPackages) {
        Write-Host '    2. winget packages:   skip'
    } elseif ($null -ne $packages) {
        Write-Host "    2. winget packages:   $(($packages | ForEach-Object { $_.Name.Trim() }) -join ', ')"
    } else {
        Write-Host '    2. winget packages:   all'
    }
    if ($SkipUserData) {
        Write-Host '    3. user-data:         skip'
    } else {
        Write-Host "    3. user-data:         $($userDataNames -join ', ')"
        Write-Host "       locale=$Locale timezone=$Timezone user=$UserName"
        Write-Host "       repo=$DotfilesRepo"
        Write-Host "       agents=$(if ($Agents) { $Agents } else { 'none' })"
    }
    Write-Host ''
    if (-not (Read-YesNo 'Proceed?')) {
        Write-Host 'Cancelled.'
        exit
    }
}

# ---------------------------------------------------------------------------
# Step 1: Enable WSL

Write-Step '1/3' 'Enabling WSL...'

if ($SkipWsl) {
    Write-Skip 'Skipped.'
} else {
    # --no-distribution installs the WSL feature only; the distro is started
    # manually in the last step so the user can choose a name.
    wsl --install --no-distribution 2>&1 | ForEach-Object { Write-Host "  $_" }
    if ($LASTEXITCODE -eq 0) {
        Write-Ok 'WSL enabled (or was already enabled).'
    } else {
        Write-Warn "wsl --install exited with code $LASTEXITCODE — WSL may already be installed."
    }
}

# ---------------------------------------------------------------------------
# Step 2: Install winget packages

Write-Step '2/3' 'Installing packages via winget...'

if ($SkipPackages) {
    Write-Skip 'Skipped.'
} elseif (-not $hasWinget) {
    Write-Warn 'winget not found — skipping package installation.'
    Write-Warn 'Install the App Installer from the Microsoft Store and re-run.'
} else {
    if ($null -eq $packages) { $packages = Get-Packages }

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

if ($SkipUserData) {
    Write-Skip 'Skipped.'
} else {
    $cloudInitDir = Join-Path $env:USERPROFILE '.cloud-init'
    if (-not (Test-Path $cloudInitDir)) { New-Item $cloudInitDir -ItemType Directory | Out-Null }

    # cloud-init does not recognise "#cloud-config" behind a BOM.
    $utf8NoBom = New-Object Text.UTF8Encoding $false

    foreach ($userDataName in $userDataNames) {
        $userDataDest = Join-Path $cloudInitDir $userDataName
        $userDataUrl  = "$RepoBase/windows/cloud-init/$userDataName"

        if (Test-Path $userDataDest) {
            Write-Warn "$userDataDest already exists and will be overwritten."
        }

        Invoke-WebRequest -Uri $userDataUrl -OutFile $userDataDest -UseBasicParsing
        $text = [IO.File]::ReadAllText($userDataDest, $utf8NoBom)
        [IO.File]::WriteAllText($userDataDest, (Edit-UserData $text), $utf8NoBom)
        Write-Ok "User-data saved to $userDataDest"
    }

    $changed = @(foreach ($name in 'Locale', 'Timezone', 'UserName', 'DotfilesRepo') {
        $value = Get-Variable $name -ValueOnly
        if ($value -cne $TemplateValues[$name]) { "$name=$value" }
    })
    if ($Agents) { $changed += "Agents=$Agents" }
    if ($changed) { Write-Ok "Customised: $($changed -join ', ')" }
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
  - install one with the bundled script, as a REGULAR user (not elevated, so
    it installs for your account only). Defaults to JetBrainsMono NL; -List
    shows the full catalogue, including Nerd Fonts for Japanese, Korean, and
    Chinese:
      powershell -ExecutionPolicy Bypass -File .\install-nerd-font.ps1
      powershell -ExecutionPolicy Bypass -File .\install-nerd-font.ps1 -List
    (not next to setup.ps1? get it from windows/install-nerd-font.ps1 in the repo)
  - or install any Nerd Font of your choice yourself.
  Then set it as the font in your Windows Terminal / VS Code profile.

(Optional) Finish Windows settings manually:
  - Git Bash: git config --global user.name  "Your Name"
              git config --global user.email "you@example.com"
  - VS Code: install the "Remote Development" extension pack

(Optional) Using a fork of the dotfiles repo? Re-run this script with
  -DotfilesRepo <your fork's clone URL> (or set $RepoBase to your fork)
  so the WSL distro pulls your own config.

Start a WSL distro (run in PowerShell or Windows Terminal):
  # main (systemd enabled, Docker CE, localectl)
  wsl --install Ubuntu-26.04

  # optional secondary instance (systemd disabled, daily-use, fast startup)
  wsl --install -d Ubuntu-26.04 --name Ubuntu-26.04-devcli

A reboot is recommended to fully apply the WSL changes.
'@

Wait-Enter
