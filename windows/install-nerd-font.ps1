#Requires -Version 5.1
# install-nerd-font.ps1 — installs Nerd Fonts for the current user.
#
# This environment expects a Nerd Font in the terminal. Run this script to get
# one, or install a Nerd Font of your choice yourself.
#
# Usage (run in PowerShell as a regular user — do NOT elevate):
#   powershell -ExecutionPolicy Bypass -File .\install-nerd-font.ps1
#   powershell -ExecutionPolicy Bypass -File .\install-nerd-font.ps1 -List
#   powershell -ExecutionPolicy Bypass -File .\install-nerd-font.ps1 -Font PlemolJP -Force

[CmdletBinding()]
param(
    # Font keys from the catalogue below; defaults to $DefaultFonts.
    [string[]]$Font,
    # Install every font in the catalogue.
    [switch]$All,
    # Print the catalogue and exit.
    [switch]$List,
    # Reinstall even when the font is already present.
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
# Windows PowerShell 5.1 redraws the progress bar per chunk, which makes
# Invoke-WebRequest / Expand-Archive many times slower.
$ProgressPreference = 'SilentlyContinue'

# ---------------------------------------------------------------------------
# Font catalogue
#
# To add a font, append one entry here; nothing else needs to change.
#   Repo          GitHub repository publishing the release
#   AssetPattern  regex matching the release asset to download
#   SourcePattern regex matching the files to install inside the archive
#   InstalledGlob wildcard matching the installed files in the fonts folder

$FontCatalog = [ordered]@{
    'JetBrainsMono' = @{
        DisplayName   = 'JetBrainsMono NL Nerd Font'
        Repo          = 'JetBrains/JetBrainsMono'
        AssetPattern  = '^JetBrainsMono-.*\.zip$'
        # The archive also ships the non-NL variant and variable-weight fonts.
        SourcePattern = '\\fonts\\ttf\\JetBrainsMonoNL-[^\\]+\.ttf$'
        InstalledGlob = 'JetBrainsMonoNL-*.ttf'
    }
    'PlemolJP' = @{
        DisplayName   = 'PlemolJP Console NF'
        Repo          = 'yuru7/PlemolJP'
        AssetPattern  = '^PlemolJP_NF_.*\.zip$'
        # The archive also ships PlemolJP35Console_NF and proportional variants.
        SourcePattern = '\\PlemolJPConsole_NF\\[^\\]+\.(ttf|otf)$'
        # "_0" suffixed files are leftovers from a failed overwrite.
        InstalledGlob = 'PlemolJPConsoleNF-*.tt?'
    }
    # Sarasa Gothic ships one archive per script/region; each is a separate
    # catalogue entry so they can be installed independently.
    'SarasaCL' = @{
        DisplayName   = 'Sarasa Term CL Nerd Font'
        Repo          = 'jonz94/Sarasa-Gothic-Nerd-Fonts'
        AssetPattern  = '^sarasa-term-cl-nerd-font\.zip$'
        SourcePattern = '\\sarasa-term-cl-[^\\]+-nerd-font\.ttf$'
        InstalledGlob = 'sarasa-term-cl-*-nerd-font.ttf'
    }
    'SarasaHC' = @{
        DisplayName   = 'Sarasa Term HC Nerd Font'
        Repo          = 'jonz94/Sarasa-Gothic-Nerd-Fonts'
        AssetPattern  = '^sarasa-term-hc-nerd-font\.zip$'
        SourcePattern = '\\sarasa-term-hc-[^\\]+-nerd-font\.ttf$'
        InstalledGlob = 'sarasa-term-hc-*-nerd-font.ttf'
    }
    'SarasaJ' = @{
        DisplayName   = 'Sarasa Term J Nerd Font'
        Repo          = 'jonz94/Sarasa-Gothic-Nerd-Fonts'
        AssetPattern  = '^sarasa-term-j-nerd-font\.zip$'
        SourcePattern = '\\sarasa-term-j-[^\\]+-nerd-font\.ttf$'
        InstalledGlob = 'sarasa-term-j-*-nerd-font.ttf'
    }
    'SarasaK' = @{
        DisplayName   = 'Sarasa Term K Nerd Font'
        Repo          = 'jonz94/Sarasa-Gothic-Nerd-Fonts'
        AssetPattern  = '^sarasa-term-k-nerd-font\.zip$'
        SourcePattern = '\\sarasa-term-k-[^\\]+-nerd-font\.ttf$'
        InstalledGlob = 'sarasa-term-k-*-nerd-font.ttf'
    }
    'SarasaSC' = @{
        DisplayName   = 'Sarasa Term SC Nerd Font'
        Repo          = 'jonz94/Sarasa-Gothic-Nerd-Fonts'
        AssetPattern  = '^sarasa-term-sc-nerd-font\.zip$'
        SourcePattern = '\\sarasa-term-sc-[^\\]+-nerd-font\.ttf$'
        InstalledGlob = 'sarasa-term-sc-*-nerd-font.ttf'
    }
    'SarasaTC' = @{
        DisplayName   = 'Sarasa Term TC Nerd Font'
        Repo          = 'jonz94/Sarasa-Gothic-Nerd-Fonts'
        AssetPattern  = '^sarasa-term-tc-nerd-font\.zip$'
        SourcePattern = '\\sarasa-term-tc-[^\\]+-nerd-font\.ttf$'
        InstalledGlob = 'sarasa-term-tc-*-nerd-font.ttf'
    }
}

$DefaultFonts = @('JetBrainsMono')

# ---------------------------------------------------------------------------
# Helpers

function Write-Step  ($msg) { Write-Host "`n$msg" -ForegroundColor Yellow }
function Write-Ok    ($msg) { Write-Host "  [OK] $msg" -ForegroundColor Green }
function Write-Skip  ($msg) { Write-Host "  [--] $msg" -ForegroundColor DarkGray }
function Write-Warn  ($msg) { Write-Host "  [!!] $msg" -ForegroundColor Cyan }
function Write-Fail  ($msg) { Write-Host "  [EE] $msg" -ForegroundColor Red }

trap {
    Write-Fail $_
    exit 1
}

$UserFontDir  = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
$UserFontReg  = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
$SystemFontDir = Join-Path $env:SystemRoot 'Fonts'

function Get-InstalledFont ($glob) {
    @(Get-ChildItem -Path $UserFontDir -Filter $glob -File -ErrorAction SilentlyContinue)
}

function Get-SystemFont ($glob) {
    @(Get-ChildItem -Path $SystemFontDir -Filter $glob -File -ErrorAction SilentlyContinue)
}

# Drops the registrations pointing at $files so a failed install cannot leave
# entries behind that reference a deleted file.
function Remove-FontRegistration ($files) {
    $paths = @($files | ForEach-Object { $_.FullName })
    if (-not (Test-Path $UserFontReg)) { return }

    $props = (Get-ItemProperty -Path $UserFontReg).PSObject.Properties
    foreach ($prop in $props) {
        if ($prop.Value -is [string] -and $paths -contains $prop.Value) {
            Remove-ItemProperty -Path $UserFontReg -Name $prop.Name -Force -ErrorAction SilentlyContinue
        }
    }
}

# Returns the files that survived deletion. A font open by a running app cannot
# be deleted: Remove-Item fails with a sharing violation, and a file already
# marked for deletion stays visible until the last handle closes. Re-testing the
# path after the delete covers both cases, so a survivor is always reported.
function Remove-InstalledFont ($files) {
    $survivors = @()
    foreach ($file in $files) {
        Remove-Item -LiteralPath $file.FullName -Force -ErrorAction SilentlyContinue
        if (Test-Path -LiteralPath $file.FullName) { $survivors += $file }
    }
    $survivors
}

function Get-ReleaseAsset ($entry) {
    # Windows PowerShell 5.1 may default to TLS versions GitHub rejects.
    [Net.ServicePointManager]::SecurityProtocol =
        [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

    $release = Invoke-RestMethod -UseBasicParsing `
        -Uri "https://api.github.com/repos/$($entry.Repo)/releases/latest"
    $asset = $release.assets |
        Where-Object { $_.name -match $entry.AssetPattern } |
        Select-Object -First 1
    if (-not $asset) { throw "No asset matching $($entry.AssetPattern) in $($entry.Repo) $($release.tag_name)." }

    [pscustomobject]@{ Tag = $release.tag_name; Url = $asset.browser_download_url }
}

# CopyHere is asynchronous and reports nothing, so wait for the files to appear.
function Wait-FontInstall ($names, $timeoutSeconds = 120) {
    $deadline = (Get-Date).AddSeconds($timeoutSeconds)
    do {
        $missing = @($names | Where-Object { -not (Test-Path -LiteralPath (Join-Path $UserFontDir $_)) })
        if ($missing.Count -eq 0) { return @() }
        Start-Sleep -Milliseconds 500
    } while ((Get-Date) -lt $deadline)
    $missing
}

function Install-Font ($key) {
    $entry = $FontCatalog[$key]
    Write-Step "$key — $($entry.DisplayName)"

    $installed = Get-InstalledFont $entry.InstalledGlob
    if ($installed.Count -gt 0 -and -not $Force) {
        Write-Skip "$($entry.DisplayName) is already installed ($($installed.Count) files). Use -Force to reinstall."
        return
    }

    # A system-wide copy would shadow the per-user one and cannot be removed here.
    $systemCopies = Get-SystemFont $entry.InstalledGlob
    if ($systemCopies.Count -gt 0) {
        Write-Fail "$($entry.DisplayName) is installed system-wide in $SystemFontDir."
        Write-Warn 'Remove it from an elevated "shell:fonts" window first, then re-run this script.'
        return
    }

    Write-Host '  Resolving latest release...'
    $asset = Get-ReleaseAsset $entry
    Write-Host "  Version: $($asset.Tag)"

    $tempZip     = Join-Path $env:TEMP "$key-nf.zip"
    $tempExtract = Join-Path $env:TEMP "$key-nf"

    Write-Host '  Downloading...'
    Invoke-WebRequest -Uri $asset.Url -OutFile $tempZip -UseBasicParsing

    Write-Host '  Extracting...'
    if (Test-Path $tempExtract) { Remove-Item $tempExtract -Recurse -Force }
    Expand-Archive -Path $tempZip -DestinationPath $tempExtract -Force

    $fontFiles = @(Get-ChildItem $tempExtract -Recurse -File |
        Where-Object { $_.FullName -match $entry.SourcePattern })
    if ($fontFiles.Count -eq 0) { throw "No font files matching $($entry.SourcePattern) in the archive." }

    if ($installed.Count -gt 0) {
        Write-Host '  Removing the installed copy...'
        Remove-FontRegistration $installed
        $survivors = Remove-InstalledFont $installed
        if ($survivors.Count -gt 0) {
            # Installing over files in use makes Windows prompt to overwrite and
            # silently fall back to "<name>_0.ttf", leaving a broken mix of versions.
            Write-Fail "These font files are in use and could not be removed: $(($survivors | ForEach-Object Name) -join ', ')"
            Write-Warn 'Close the apps using the font (terminals, editors, browsers), sign out and back in'
            Write-Warn 'if that is not enough, then re-run this script.'
            Remove-Item $tempZip -Force
            Remove-Item $tempExtract -Recurse -Force
            return
        }
        Write-Ok "Removed $($installed.Count) files."
    }

    Write-Host "  Installing $($fontFiles.Count) font files..."
    $shell      = New-Object -ComObject Shell.Application
    $shellFonts = $shell.Namespace(0x14)   # 0x14 = special Fonts folder
    foreach ($file in $fontFiles) {
        # 4 = no progress UI, 16 = yes to all; the target is empty, so neither prompts.
        $shellFonts.CopyHere($file.FullName, 4 + 16)
    }

    $missing = Wait-FontInstall @($fontFiles | ForEach-Object Name)

    Remove-Item $tempZip -Force
    Remove-Item $tempExtract -Recurse -Force

    if ($missing.Count -gt 0) {
        Write-Fail "These fonts did not appear in $UserFontDir : $($missing -join ', ')"
        return
    }
    Write-Ok "$($entry.DisplayName) $($asset.Tag) installed."
}

# ---------------------------------------------------------------------------
# Main

if ($List) {
    Write-Host 'Available fonts' -ForegroundColor Cyan
    foreach ($key in $FontCatalog.Keys) {
        $installed = Get-InstalledFont $FontCatalog[$key].InstalledGlob
        $state = if ($installed.Count -gt 0) { 'installed' } else { 'not installed' }
        '  {0,-12} {1} ({2})' -f $key, $FontCatalog[$key].DisplayName, $state
    }
    exit 0
}

# Elevated runs install system-wide instead, which mixes badly with the
# per-user copy this script manages.
$identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if ($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Fail 'Run this script as a regular user, not as administrator.'
    exit 1
}

if ($All) {
    $targets = @($FontCatalog.Keys)
} elseif ($Font) {
    $targets = $Font
} else {
    $targets = $DefaultFonts
}

$unknown = @($targets | Where-Object { -not $FontCatalog.Contains($_) })
if ($unknown.Count -gt 0) {
    Write-Fail "Unknown font: $($unknown -join ', '). Run with -List to see the catalogue."
    exit 1
}

Write-Host 'Nerd Font installer' -ForegroundColor Cyan
Write-Host "  Target folder: $UserFontDir"

foreach ($key in $targets) { Install-Font $key }

Write-Host "`nDone. Set the font in your terminal profile to use it." -ForegroundColor Green
