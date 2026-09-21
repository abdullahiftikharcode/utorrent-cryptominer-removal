<#
.SYNOPSIS
    Completely removes uTorrent and uTorrent Web from Windows.

.DESCRIPTION
    Since uTorrent's official installer is the confirmed infection vector for the
    dlIhost.exe XMRig cryptominer, this script performs a thorough removal of all
    uTorrent and uTorrent Web components including:

    - Application files (AppData\Roaming, AppData\Local, ProgramData)
    - Registry keys (Software, Classes, Uninstall entries)
    - Startup autorun entries (HKCU\...\Run)
    - Scheduled tasks
    - Defender exclusions
    - Temp files

    Recommended replacement: qBittorrent (https://www.qbittorrent.org/)

    Requires: Administrator privileges, PowerShell 5.1+

.EXAMPLE
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
    .\Remove-uTorrent.ps1
#>

$IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $IsAdmin) {
    Write-Host "[!] This script must be run as Administrator." -ForegroundColor Red
    Write-Host "    Right-click PowerShell -> Run as Administrator, then re-run this script." -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  uTorrent & uTorrent Web — Complete Removal Tool" -ForegroundColor White
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# ── Step 1: Kill processes ───────────────────────────────────────────────
Write-Host "[Step 1/7] Terminating uTorrent processes..." -ForegroundColor Yellow
$procNames = @('uTorrent', 'utweb', 'BitTorrentAntivirus', 'bittorrent', 'utorrentie', 'crashpad_handler')
foreach ($name in $procNames) {
    $p = Get-Process -Name $name -ErrorAction SilentlyContinue
    if ($p) {
        Stop-Process -Name $name -Force -ErrorAction SilentlyContinue
        Write-Host "  [+] Killed: $name (PID: $($p.Id))" -ForegroundColor Green
    }
}
Start-Sleep -Seconds 2

# ── Step 2: Delete AppData folders ───────────────────────────────────────
Write-Host "[Step 2/7] Removing application directories..." -ForegroundColor Yellow
$folders = @(
    (Join-Path $env:APPDATA "uTorrent"),
    (Join-Path $env:APPDATA "uTorrent Web"),
    (Join-Path $env:LOCALAPPDATA "uTorrent"),
    (Join-Path $env:LOCALAPPDATA "uTorrent Web"),
    "$env:APPDATA\..\LocalLow\uTorrent",
    "$env:ProgramData\BitTorrent",
    "$env:ProgramData\uTorrent"
)
foreach ($f in $folders) {
    if (Test-Path $f) {
        Remove-Item $f -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "  [+] Deleted: $f" -ForegroundColor Green
    }
}

# ── Step 3: Remove registry keys ────────────────────────────────────────
Write-Host "[Step 3/7] Cleaning registry keys..." -ForegroundColor Yellow
$regKeys = @(
    'HKCU:\Software\BitTorrent',
    'HKCU:\Software\uTorrent',
    'HKCU:\Software\Clients\Media\uTorrent',
    'HKCU:\Software\Classes\.torrent',
    'HKCU:\Software\Classes\uTorrent',
    'HKCU:\Software\Classes\BitTorrent',
    'HKLM:\SOFTWARE\BitTorrent',
    'HKLM:\SOFTWARE\uTorrent',
    'HKLM:\SOFTWARE\WOW6432Node\BitTorrent',
    'HKLM:\SOFTWARE\WOW6432Node\uTorrent',
    'HKLM:\SOFTWARE\Classes\uTorrent'
)
foreach ($k in $regKeys) {
    if (Test-Path $k) {
        Remove-Item $k -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "  [+] Removed: $k" -ForegroundColor Green
    }
}

# ── Step 4: Remove uninstall entries ─────────────────────────────────────
Write-Host "[Step 4/7] Removing uninstall registry entries..." -ForegroundColor Yellow
$uninstPaths = @(
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall',
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
)
foreach ($up in $uninstPaths) {
    if (Test-Path $up) {
        Get-ChildItem $up -ErrorAction SilentlyContinue | ForEach-Object {
            $dn = $_.GetValue('DisplayName')
            if ($dn -match 'uTorrent|BitTorrent|torrent') {
                Remove-Item $_.PSPath -Recurse -Force -ErrorAction SilentlyContinue
                Write-Host "  [+] Removed: $dn" -ForegroundColor Green
            }
        }
    }
}

# ── Step 5: Remove startup entries ───────────────────────────────────────
Write-Host "[Step 5/7] Removing startup autorun entries..." -ForegroundColor Yellow
$runPaths = @(
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run',
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'
)
foreach ($rp in $runPaths) {
    if (Test-Path $rp) {
        $props = Get-ItemProperty $rp -ErrorAction SilentlyContinue
        $props.PSObject.Properties | Where-Object { $_.Value -match 'uTorrent|utweb|BitTorrent' } | ForEach-Object {
            Remove-ItemProperty $rp -Name $_.Name -Force -ErrorAction SilentlyContinue
            Write-Host "  [+] Removed autorun: [$($_.Name)]" -ForegroundColor Green
        }
    }
}

# ── Step 6: Remove scheduled tasks ──────────────────────────────────────
Write-Host "[Step 6/7] Removing scheduled tasks..." -ForegroundColor Yellow
Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object {
    $_.TaskName -match 'uTorrent|BitTorrent|torrent' -or
    ($_.Actions | Where-Object { $_.Execute -match 'uTorrent|utweb|BitTorrent' })
} | ForEach-Object {
    Unregister-ScheduledTask -TaskName $_.TaskName -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host "  [+] Removed task: $($_.TaskName)" -ForegroundColor Green
}

# ── Step 7: Remove Defender exclusions ───────────────────────────────────
Write-Host "[Step 7/7] Removing Defender exclusions..." -ForegroundColor Yellow
$prefs = Get-MpPreference -ErrorAction SilentlyContinue
foreach ($excl in @($prefs.ExclusionPath)) {
    if ($excl -match 'uTorrent|BitTorrent') {
        Remove-MpPreference -ExclusionPath $excl -ErrorAction SilentlyContinue
        Write-Host "  [+] Removed exclusion: $excl" -ForegroundColor Green
    }
}

# ── Verification ─────────────────────────────────────────────────────────
Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  VERIFICATION" -ForegroundColor White
Write-Host "================================================================" -ForegroundColor Cyan

$pass = $true

$c1 = Get-Process -Name 'uTorrent','utweb','BitTorrentAntivirus' -ErrorAction SilentlyContinue
if ($c1) { Write-Host "  [FAIL] Processes still running: $($c1.Name -join ', ')" -ForegroundColor Red; $pass = $false }
else     { Write-Host "  [PASS] No uTorrent processes running." -ForegroundColor Green }

foreach ($f in @((Join-Path $env:APPDATA "uTorrent"), (Join-Path $env:APPDATA "uTorrent Web"))) {
    if (Test-Path $f) { Write-Host "  [FAIL] Folder still exists: $f" -ForegroundColor Red; $pass = $false }
    else              { Write-Host "  [PASS] Folder gone: $f" -ForegroundColor Green }
}

$rk = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -ErrorAction SilentlyContinue
$hits = $rk.PSObject.Properties | Where-Object { $_.Value -match 'uTorrent|utweb|BitTorrent' }
if ($hits) { Write-Host "  [FAIL] Autorun entries still present" -ForegroundColor Red; $pass = $false }
else       { Write-Host "  [PASS] No autorun entries remain." -ForegroundColor Green }

Write-Host ""
if ($pass) {
    Write-Host "================================================================" -ForegroundColor Green
    Write-Host "  SUCCESS: uTorrent completely removed." -ForegroundColor Green
    Write-Host "================================================================" -ForegroundColor Green
} else {
    Write-Host "================================================================" -ForegroundColor Red
    Write-Host "  Some items need attention (see FAIL above)." -ForegroundColor Red
    Write-Host "================================================================" -ForegroundColor Red
}

Write-Host ""
Write-Host "Recommended replacement: qBittorrent" -ForegroundColor Cyan
Write-Host "Download: https://www.qbittorrent.org/download" -ForegroundColor White
Write-Host ""
