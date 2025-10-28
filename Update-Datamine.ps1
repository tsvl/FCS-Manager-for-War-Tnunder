<#
.SYNOPSIS
  Update-Datamine.ps1 - Extract and filter War Thunder datamine files for FCS Generator

.DESCRIPTION
  This script:
  - Locates your War Thunder installation (or accepts -InstallPath)
  - Extracts aces.vromfs.bin and lang.vromfs.bin using wt_ext_cli.exe
  - Filters to only the files we need (tankmodels, groundmodels_weapons, lang CSVs)
  - Mirrors them into .\Datamine (cleaning old files, preserving .gitkeep)
  - Copies lang CSVs into .\Localization

.PARAMETER InstallPath
  Optional: manually specify the War Thunder install folder. If not provided, the script will attempt to locate it automatically.

.EXAMPLE
  pwsh .\Update-Datamine.ps1
  pwsh .\Update-Datamine.ps1 -InstallPath "D:\Games\War Thunder"
#>

[CmdletBinding()]
param(
  [string]$InstallPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# === 1. Verify wt_ext_cli.exe is available ===
$wtExtCliCmd = $null
$cmd = Get-Command "wt_ext_cli.exe" -ErrorAction SilentlyContinue
if ($cmd) { $wtExtCliCmd = $cmd.Source }
if (-not $wtExtCliCmd) {
  $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
  $localCli = Join-Path $scriptDir "wt_ext_cli.exe"
  if (Test-Path -LiteralPath $localCli) { $wtExtCliCmd = $localCli }
}
if (-not $wtExtCliCmd) {
  Write-Warning "wt_ext_cli.exe not found in PATH or next to the script. Please install it or place it alongside this script."
  exit 1
}

# === 2. Locate War Thunder installation ===
if (-not $InstallPath) {
  # Try registry lookup (StrictMode-safe)
  $InstallPath = Get-ChildItem HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall, HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall, HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall |
    Get-ItemProperty |
    Where-Object {
      $_.PSObject.Properties['DisplayName'] -and
      $_.PSObject.Properties['InstallLocation'] -and
      $_.DisplayName -eq 'War Thunder' -and
      $_.InstallLocation
    } |
    Select-Object -ExpandProperty InstallLocation -First 1
}

if ($InstallPath) {
  Write-Host "Found War Thunder installation at: $InstallPath" -ForegroundColor Cyan
}
else {
  Write-Warning "War Thunder installation not found automatically."
  while ($true) {
    $inputPath = Read-Host "Please enter the full War Thunder installation folder path (or press Enter to cancel)"
    if ([string]::IsNullOrWhiteSpace($inputPath)) {
      Write-Error "Operation cancelled by user."
      exit 1
    }
    $inputPath = $inputPath.Trim('"')

    # Validate both required files exist
    $acesPath = Join-Path $inputPath 'aces.vromfs.bin'
    $langPath = Join-Path $inputPath 'lang.vromfs.bin'
    if ((Test-Path -LiteralPath $inputPath -PathType Container) -and
        (Test-Path -LiteralPath $acesPath) -and
        (Test-Path -LiteralPath $langPath)) {
      $InstallPath = $inputPath
      Write-Host "Using War Thunder installation at: $InstallPath" -ForegroundColor Cyan
      break
    }
    else {
      Write-Warning "Invalid path or required files not found (need both aces.vromfs.bin and lang.vromfs.bin)."
    }
  }
}

# === 3. Extract archives to temp ===
$DatamineTemp = Join-Path $env:TEMP "FCSGenerator"
if (Test-Path -LiteralPath $DatamineTemp) {
  Remove-Item -LiteralPath $DatamineTemp -Recurse -Force
}
New-Item -ItemType Directory -Path $DatamineTemp -Force | Out-Null

Write-Host "Extracting datamine files to $DatamineTemp..." -ForegroundColor Yellow
& $wtExtCliCmd unpack_vromf -i (Join-Path $InstallPath 'aces.vromfs.bin') -o $DatamineTemp --blk_extension "blkx"
& $wtExtCliCmd unpack_vromf -i (Join-Path $InstallPath 'lang.vromfs.bin')  -o $DatamineTemp --blk_extension "blkx"

# === 4. Load ignore list for tankmodels ===
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ignoreFile = Join-Path $scriptDir 'ignore.txt'
$ignoreSet = @{}
if (Test-Path -LiteralPath $ignoreFile) {
  foreach ($line in (Get-Content -LiteralPath $ignoreFile)) {
    $trimmed = $line.Trim().Trim('"')
    if ($trimmed -and -not $trimmed.StartsWith('#')) {
      $ignoreSet[$trimmed] = $true
    }
  }
}

# === 5. Define source paths in temp ===
$tankSrc = Join-Path $DatamineTemp 'aces.vromfs.bin_u\gamedata\units\tankmodels'
$weapSrc = Join-Path $DatamineTemp 'aces.vromfs.bin_u\gamedata\weapons\groundmodels_weapons'
$langSrc = Join-Path $DatamineTemp 'lang.vromfs.bin_u\lang'

# === 6. Filter files (top-level only, no subdirs) ===
Write-Host "Filtering files..." -ForegroundColor Yellow

# Tankmodels: top-level files, excluding ignore list
$tankFiles = @()
if (Test-Path -LiteralPath $tankSrc) {
  $tankFiles = Get-ChildItem -LiteralPath $tankSrc -File | Where-Object { -not $ignoreSet.ContainsKey($_.Name) }
}

# Groundmodels_weapons: all top-level files
$weapFiles = @()
if (Test-Path -LiteralPath $weapSrc) {
  $weapFiles = Get-ChildItem -LiteralPath $weapSrc -File
}

# Lang: only units.csv and units_weaponry.csv
$langWanted = @('units.csv', 'units_weaponry.csv')
$langFiles = @()
if (Test-Path -LiteralPath $langSrc) {
  foreach ($name in $langWanted) {
    $path = Join-Path $langSrc $name
    if (Test-Path -LiteralPath $path) {
      $langFiles += Get-Item -LiteralPath $path
    }
  }
}

# === 7. Define destination paths ===
$repoRoot = $scriptDir
$destRoot = Join-Path $repoRoot 'Datamine'
$tankDest = Join-Path $destRoot 'aces.vromfs.bin_u\gamedata\units\tankmodels'
$weapDest = Join-Path $destRoot 'aces.vromfs.bin_u\gamedata\weapons\groundmodels_weapons'
$langDest = Join-Path $destRoot 'lang.vromfs.bin_u\lang'
$locRoot  = Join-Path $repoRoot 'Localization'

# Create destination directories if they don't exist
foreach ($dir in @($tankDest, $weapDest, $langDest, $locRoot)) {
  if (-not (Test-Path -LiteralPath $dir)) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
  }
}

# === 8. Helper function: mirror files and clean extras (except .gitkeep) ===
function Sync-Files {
  param(
    [System.IO.FileInfo[]]$SourceFiles,
    [string]$DestinationDir
  )

  $copiedNames = @{}

  # Copy all source files
  foreach ($file in $SourceFiles) {
    $destPath = Join-Path $DestinationDir $file.Name
    Copy-Item -LiteralPath $file.FullName -Destination $destPath -Force
    $copiedNames[$file.Name] = $true
  }

  # Remove files in destination that weren't in source (except .gitkeep)
  if (Test-Path -LiteralPath $DestinationDir) {
    foreach ($existing in (Get-ChildItem -LiteralPath $DestinationDir -File)) {
      if ($existing.Name -eq '.gitkeep') { continue }
      if (-not $copiedNames.ContainsKey($existing.Name)) {
        Remove-Item -LiteralPath $existing.FullName -Force
      }
    }
  }
}

# === 9. Mirror files into Datamine ===
Write-Host "Mirroring tankmodels..." -ForegroundColor Green
Sync-Files -SourceFiles $tankFiles -DestinationDir $tankDest

Write-Host "Mirroring groundmodels_weapons..." -ForegroundColor Green
Sync-Files -SourceFiles $weapFiles -DestinationDir $weapDest

Write-Host "Mirroring lang CSVs..." -ForegroundColor Green
Sync-Files -SourceFiles $langFiles -DestinationDir $langDest

# === 10. Also copy units_weaponry.csv into Localization (janky hack to avoid updating exe lol) ===
foreach ($file in $langFiles) {
  if ($file.Name -eq 'units_weaponry.csv') {
    Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $locRoot $file.Name) -Force
  }
}

# === 11. Cleanup temp extraction ===
if (Test-Path -LiteralPath $DatamineTemp) {
  Remove-Item -LiteralPath $DatamineTemp -Recurse -Force
}

Write-Host "Done! Datamine files updated." -ForegroundColor Cyan