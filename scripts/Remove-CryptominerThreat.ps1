<#
.SYNOPSIS
    Detects and removes the dlIhost.exe XMRig cryptominer dropped by uTorrent's bundled installer.

.DESCRIPTION
    This script performs complete removal of the disguised XMRig miner that masquerades as
    Windows "COM Surrogate" (dllhost.exe) using a homoglyph attack (dlIhost.exe with uppercase I).

    It will:
    1. Kill the miner process
    2. Remove the persistence scheduled task (\UpdateTask)
    3. Delete the malware directory (%AppData%\Roaming\Dll\)
    4. Remove the self-added Windows Defender exclusion
    5. Run 5 automated verification checks

    Requires: Administrator privileges, PowerShell 5.1+, Windows 10/11

.EXAMPLE
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
    .\Remove-CryptominerThreat.ps1
#>

# ── Require Admin ─────────────────────────────────────────────────────────
$IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $IsAdmin) {
    Write-Host "[!] This script must be run as Administrator." -ForegroundColor Red
    Write-Host "    Right-click PowerShell -> Run as Administrator, then re-run this script." -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  uTorrent Cryptominer (dlIhost.exe) — Removal Tool" -ForegroundColor White
Write-Host "  https://github.com/abdullahiftikharcode/utorrent-cryptominer-removal" -ForegroundColor DarkGray
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

$MalwareDir = Join-Path $env:APPDATA "Dll"
$MalwareExe = Join-Path $MalwareDir "dlIhost.exe"
$MalwareDriver = Join-Path $MalwareDir "WinRing0x64.sys"
$TaskName = "UpdateTask"
$DefenderExclusion = Join-Path $env:APPDATA "DLL"

# ── Detection Phase ──────────────────────────────────────────────────────
Write-Host "[*] Scanning for infection indicators..." -ForegroundColor Yellow
$infected = $false

$proc = Get-Process -Name 'dlIhost' -ErrorAction SilentlyContinue
if ($proc) {
    Write-Host "  [!] FOUND: dlIhost.exe is running (PID: $($proc.Id), CPU: $([math]::Round($proc.CPU,1))s)" -ForegroundColor Red
    $infected = $true
}

if (Test-Path $MalwareDir) {
    $files = Get-ChildItem $MalwareDir -Force -ErrorAction SilentlyContinue
    Write-Host "  [!] FOUND: Malware directory exists with $($files.Count) file(s):" -ForegroundColor Red
    foreach ($f in $files) {
        Write-Host "       - $($f.Name) ($([math]::Round($f.Length/1KB,1)) KB)" -ForegroundColor Red
    }
    $infected = $true
}

$task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($task) {
    Write-Host "  [!] FOUND: Scheduled task '\$TaskName' (State: $($task.State))" -ForegroundColor Red
    $infected = $true
}

$exclusions = (Get-MpPreference -ErrorAction SilentlyContinue).ExclusionPath
$hasExclusion = $exclusions | Where-Object { $_ -match [regex]::Escape($env:APPDATA) -and $_ -match 'DLL' }
if ($hasExclusion) {
    Write-Host "  [!] FOUND: Defender exclusion for malware directory" -ForegroundColor Red
    $infected = $true
}

# Also check for running process via WMI (catches cases where process name differs)
$wmiProc = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object { $_.ExecutablePath -like '*AppData*Dll*host*' }
if ($wmiProc) {
    Write-Host "  [!] FOUND: Suspicious process via WMI (PID: $($wmiProc.ProcessId), Path: $($wmiProc.ExecutablePath))" -ForegroundColor Red
    $infected = $true
}

if (-not $infected) {
    Write-Host ""
    Write-Host "  [+] No infection detected. Your system appears clean." -ForegroundColor Green
    Write-Host ""
    exit 0
}

Write-Host ""
Write-Host "[*] Infection confirmed. Beginning removal..." -ForegroundColor Yellow
Write-Host ""

# ── Step 1: Kill the process ─────────────────────────────────────────────
Write-Host "[Step 1/4] Terminating miner process..." -ForegroundColor Yellow
$proc = Get-Process -Name 'dlIhost' -ErrorAction SilentlyContinue
if ($proc) {
    Stop-Process -Name 'dlIhost' -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
    $check = Get-Process -Name 'dlIhost' -ErrorAction SilentlyContinue
    if ($check) {
        # Force kill via taskkill as fallback
        & taskkill.exe /F /IM "dlIhost.exe" /T 2>$null | Out-Null
        Start-Sleep -Seconds 1
    }
    Write-Host "  [+] Miner process terminated." -ForegroundColor Green
} else {
    Write-Host "  [~] Miner process not currently running." -ForegroundColor DarkGray
}

# ── Step 2: Remove scheduled task ────────────────────────────────────────
Write-Host "[Step 2/4] Removing persistence mechanism..." -ForegroundColor Yellow
$task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($task) {
    Disable-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue | Out-Null
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host "  [+] Scheduled task '\$TaskName' removed." -ForegroundColor Green
} else {
    Write-Host "  [~] Scheduled task '\$TaskName' not found (already removed or different name)." -ForegroundColor DarkGray
}

# Also check for any other tasks pointing to the malware directory
Get-ScheduledTask -ErrorAction SilentlyContinue | ForEach-Object {
    $t = $_
    foreach ($action in $t.Actions) {
        if ($action.Execute -like '*AppData*Dll*dlIhost*') {
            Unregister-ScheduledTask -TaskName $t.TaskName -Confirm:$false -ErrorAction SilentlyContinue
            Write-Host "  [+] Also removed task '$($t.TaskName)' pointing to malware." -ForegroundColor Green
        }
    }
}

# ── Step 3: Delete malware files ─────────────────────────────────────────
Write-Host "[Step 3/4] Deleting malware files..." -ForegroundColor Yellow
if (Test-Path $MalwareDir) {
    Remove-Item $MalwareDir -Recurse -Force -ErrorAction SilentlyContinue
    if (Test-Path $MalwareDir) {
        # Retry after a short delay (file locks)
        Start-Sleep -Seconds 2
        Remove-Item $MalwareDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    if (-not (Test-Path $MalwareDir)) {
        Write-Host "  [+] Deleted: $MalwareDir" -ForegroundColor Green
    } else {
        Write-Host "  [!] WARNING: Could not delete $MalwareDir — files may be locked. Try after reboot." -ForegroundColor Red
    }
} else {
    Write-Host "  [~] Malware directory already deleted." -ForegroundColor DarkGray
}

# ── Step 4: Remove Defender exclusion ────────────────────────────────────
Write-Host "[Step 4/4] Removing Windows Defender exclusion..." -ForegroundColor Yellow
$exclusions = (Get-MpPreference -ErrorAction SilentlyContinue).ExclusionPath
foreach ($excl in @($exclusions)) {
    if ($excl -match [regex]::Escape($env:APPDATA) -and $excl -match 'DLL') {
        Remove-MpPreference -ExclusionPath $excl -ErrorAction SilentlyContinue
        Write-Host "  [+] Removed Defender exclusion: $excl" -ForegroundColor Green
    }
}

# ── Verification ─────────────────────────────────────────────────────────
Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  VERIFICATION" -ForegroundColor White
Write-Host "================================================================" -ForegroundColor Cyan

$allPassed = $true

# Check 1: Process
$c1 = Get-Process -Name 'dlIhost' -ErrorAction SilentlyContinue
if ($c1) { Write-Host "  [FAIL] dlIhost process still running" -ForegroundColor Red; $allPassed = $false }
else      { Write-Host "  [PASS] dlIhost process not running" -ForegroundColor Green }

# Check 2: Scheduled task
$c2 = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($c2) { Write-Host "  [FAIL] UpdateTask still exists" -ForegroundColor Red; $allPassed = $false }
else     { Write-Host "  [PASS] UpdateTask removed" -ForegroundColor Green }

# Check 3: Malware directory
if (Test-Path $MalwareDir) { Write-Host "  [FAIL] Malware directory still exists" -ForegroundColor Red; $allPassed = $false }
else                        { Write-Host "  [PASS] Malware directory deleted" -ForegroundColor Green }

# Check 4: Defender exclusion
$c4 = (Get-MpPreference -ErrorAction SilentlyContinue).ExclusionPath | Where-Object { $_ -match [regex]::Escape($env:APPDATA) -and $_ -match 'DLL' }
if ($c4) { Write-Host "  [FAIL] Defender exclusion still present" -ForegroundColor Red; $allPassed = $false }
else     { Write-Host "  [PASS] Defender exclusion removed" -ForegroundColor Green }

# Check 5: WinRing0 driver
$c5 = Get-Service -Name 'WinRing0_1_2_0' -ErrorAction SilentlyContinue
if ($c5) { Write-Host "  [FAIL] WinRing0 driver still registered" -ForegroundColor Red; $allPassed = $false }
else     { Write-Host "  [PASS] WinRing0 driver not loaded" -ForegroundColor Green }

Write-Host ""
if ($allPassed) {
    Write-Host "================================================================" -ForegroundColor Green
    Write-Host "  SUCCESS: Cryptominer completely removed." -ForegroundColor Green
    Write-Host "================================================================" -ForegroundColor Green
} else {
    Write-Host "================================================================" -ForegroundColor Red
    Write-Host "  PARTIAL: Some items need attention (see FAIL above)." -ForegroundColor Red
    Write-Host "  Try rebooting and running this script again." -ForegroundColor Red
    Write-Host "================================================================" -ForegroundColor Red
}

Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Uninstall uTorrent (the infection source): .\Remove-uTorrent.ps1" -ForegroundColor White
Write-Host "  2. Install qBittorrent: https://www.qbittorrent.org/download" -ForegroundColor White
Write-Host "  3. Run a full Malwarebytes/HitmanPro scan for peace of mind" -ForegroundColor White
Write-Host ""
