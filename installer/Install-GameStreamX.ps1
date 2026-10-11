<#
.SYNOPSIS
  Installs GAMESTREAM X for the current Windows user (no administrator rights needed).
.DESCRIPTION
  Copies the application to %LOCALAPPDATA%\Programs\GameStreamX, creates a Start menu shortcut (and optionally a
  desktop shortcut), and registers an uninstall entry under "Installed apps". WinFsp is required for the virtual
  drive; if it is missing this script tells you where to get it but does not install it silently.
.PARAMETER DesktopShortcut
  Also create a desktop shortcut.
.PARAMETER InstallDir
  Custom installation folder.
#>
param(
    [switch]$DesktopShortcut,
    [string]$InstallDir = (Join-Path $env:LOCALAPPDATA "Programs\GameStreamX"),
    [switch]$Quiet
)
$ErrorActionPreference = "Stop"
$src = $PSScriptRoot
if (-not (Test-Path (Join-Path $src "GameStreamX.exe"))) { throw "Run this script from the extracted GAMESTREAM X release folder." }

$running = Get-Process GameStreamX -ErrorAction SilentlyContinue | Where-Object { $_.Path -and $_.Path.StartsWith($InstallDir, 'OrdinalIgnoreCase') }
if ($running) { throw "GAMESTREAM X is running from $InstallDir. Close it first." }

Write-Host "Installing GAMESTREAM X to $InstallDir ..."
New-Item -ItemType Directory -Force $InstallDir | Out-Null
# Replace program files only; user data lives in %LOCALAPPDATA%\GameStreamX and is never touched here.
Get-ChildItem $src -Force | Where-Object { $_.Name -notin @("Install.cmd") } | ForEach-Object {
    Copy-Item $_.FullName (Join-Path $InstallDir $_.Name) -Recurse -Force
}

$exe = Join-Path $InstallDir "GameStreamX.exe"
$shell = New-Object -ComObject WScript.Shell
function New-Shortcut($path) {
    $lnk = $shell.CreateShortcut($path)
    $lnk.TargetPath = $exe
    $lnk.WorkingDirectory = $InstallDir
    $lnk.IconLocation = "$exe,0"
    $lnk.Description = "GAMESTREAM X - Cloud-to-SSD game storage engine"
    $lnk.Save()
}
$startMenu = Join-Path ([Environment]::GetFolderPath("Programs")) "GAMESTREAM X.lnk"
New-Shortcut $startMenu
if ($DesktopShortcut) { New-Shortcut (Join-Path ([Environment]::GetFolderPath("Desktop")) "GAMESTREAM X.lnk") }

# Uninstall entry (per user).
$key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\GameStreamX"
New-Item -Path $key -Force | Out-Null
$version = (Get-Item $exe).VersionInfo.ProductVersion
Set-ItemProperty $key DisplayName "GAMESTREAM X"
Set-ItemProperty $key DisplayVersion $version
Set-ItemProperty $key Publisher "GAMESTREAM X"
Set-ItemProperty $key InstallLocation $InstallDir
Set-ItemProperty $key DisplayIcon "$exe,0"
Set-ItemProperty $key NoModify 1 -Type DWord
Set-ItemProperty $key NoRepair 1 -Type DWord
Set-ItemProperty $key UninstallString "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$InstallDir\Uninstall-GameStreamX.ps1`""
$size = [int]((Get-ChildItem $InstallDir -Recurse -File | Measure-Object Length -Sum).Sum / 1KB)
Set-ItemProperty $key EstimatedSize $size -Type DWord

# Prerequisite check (informational only).
$winfsp = Test-Path "${env:ProgramFiles(x86)}\WinFsp\bin\winfsp-x64.dll"
Write-Host ""
Write-Host "GAMESTREAM X $version installed." -ForegroundColor Green
if (-not $winfsp) {
    Write-Host "WinFsp is NOT installed. The virtual drive needs it." -ForegroundColor Yellow
    Write-Host "  Download the official installer from https://winfsp.dev/rel/  (or run: winget install WinFsp.WinFsp)"
} else { Write-Host "WinFsp: found." }
Write-Host "Start GAMESTREAM X from the Start menu. Google Drive setup: docs\GOOGLE_DRIVE_SETUP.md"
if (-not $Quiet) { Start-Process $exe }
