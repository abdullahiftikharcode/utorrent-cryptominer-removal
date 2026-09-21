<#
.SYNOPSIS
    Detection-only scan for the dlIhost.exe XMRig cryptominer. Makes NO changes to your system.

.DESCRIPTION
    Safely checks for all indicators of compromise associated with the uTorrent-bundled
    XMRig miner without modifying anything. Safe to share with others for checking.

    Checks:
    1. Running processes matching the miner pattern
    2. Malware files on disk (%AppData%\Roaming\Dll\)
    3. Persistence mechanism (Scheduled Task \UpdateTask)
    4. Windows Defender exclusion for malware directory
    5. WinRing0 kernel driver registration

.EXAMPLE
    .\Detect-CryptominerThreat.ps1
#>

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  uTorrent Cryptominer — Detection Scan (READ-ONLY)" -ForegroundColor White
Write-Host "  This scan makes NO changes to your system." -ForegroundColor DarkGray
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

$findings = 0
$MalwareDir = Join-Path $env:APPDATA "Dll"

# ── Check 1: Running process ─────────────────────────────────────────────
Write-Host "[Check 1/5] Scanning for dlIhost.exe process..." -ForegroundColor Yellow
$proc = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object { $_.ExecutablePath -like '*AppData*Dll*host*' }
if ($proc) {
    Write-Host "  [!] INFECTED: Found miner process" -ForegroundColor Red
    Write-Host "      PID:  $($proc.ProcessId)" -ForegroundColor Red
    Write-Host "      Path: $($proc.ExecutablePath)" -ForegroundColor Red
    Write-Host "      Cmd:  $($proc.CommandLine)" -ForegroundColor Red
    $findings++
} else {
    $proc2 = Get-Process -Name 'dlIhost' -ErrorAction SilentlyContinue
    if ($proc2) {
        Write-Host "  [!] INFECTED: dlIhost.exe is running (PID: $($proc2.Id))" -ForegroundColor Red
        $findings++
    } else {
        Write-Host "  [OK] No miner process detected." -ForegroundColor Green
    }
}

# ── Check 2: Files on disk ───────────────────────────────────────────────
Write-Host "[Check 2/5] Checking for malware files..." -ForegroundColor Yellow
if (Test-Path $MalwareDir) {
    $files = Get-ChildItem $MalwareDir -Force -ErrorAction SilentlyContinue
    Write-Host "  [!] INFECTED: Malware directory found: $MalwareDir" -ForegroundColor Red
    foreach ($f in $files) {
        $hash = ""
        try { $hash = (Get-FileHash $f.FullName -Algorithm SHA256 -ErrorAction SilentlyContinue).Hash } catch {}
        Write-Host "      - $($f.Name) | $([math]::Round($f.Length/1KB,1)) KB | Created: $($f.CreationTime) | SHA256: $hash" -ForegroundColor Red
    }
    $findings++
} else {
    Write-Host "  [OK] No malware directory found." -ForegroundColor Green
}

# ── Check 3: Scheduled task ──────────────────────────────────────────────
Write-Host "[Check 3/5] Checking for persistence mechanism..." -ForegroundColor Yellow
$task = Get-ScheduledTask -TaskName 'UpdateTask' -ErrorAction SilentlyContinue
if ($task) {
    $action = ($task.Actions | Select-Object -First 1).Execute
    Write-Host "  [!] INFECTED: Scheduled task '\UpdateTask' exists" -ForegroundColor Red
    Write-Host "      State:  $($task.State)" -ForegroundColor Red
    Write-Host "      Action: $action" -ForegroundColor Red
    $findings++
} else {
    Write-Host "  [OK] No suspicious scheduled task found." -ForegroundColor Green
}

# ── Check 4: Defender exclusion ──────────────────────────────────────────
Write-Host "[Check 4/5] Checking Windows Defender exclusions..." -ForegroundColor Yellow
try {
    $exclusions = (Get-MpPreference -ErrorAction SilentlyContinue).ExclusionPath
    $suspicious = $exclusions | Where-Object { $_ -match 'DLL|Dll' -and $_ -match 'AppData' }
    if ($suspicious) {
        Write-Host "  [!] INFECTED: Defender exclusion found for malware directory" -ForegroundColor Red
        foreach ($s in @($suspicious)) {
            Write-Host "      Excluded: $s" -ForegroundColor Red
        }
        $findings++
    } else {
        Write-Host "  [OK] No suspicious Defender exclusions." -ForegroundColor Green
    }
} catch {
    Write-Host "  [~] Could not read Defender preferences (run as Administrator for full scan)." -ForegroundColor DarkYellow
}

# ── Check 5: WinRing0 driver ─────────────────────────────────────────────
Write-Host "[Check 5/5] Checking for WinRing0 kernel driver..." -ForegroundColor Yellow
$driver = Get-Service -Name 'WinRing0_1_2_0' -ErrorAction SilentlyContinue
if ($driver) {
    Write-Host "  [!] WARNING: WinRing0 driver is registered (Status: $($driver.Status))" -ForegroundColor Yellow
    Write-Host "      Note: This driver is also used by legitimate tools (HWiNFO, CPU-Z)." -ForegroundColor Yellow
    Write-Host "      Only suspicious if combined with other findings above." -ForegroundColor Yellow
    # Don't increment findings — this alone isn't proof of infection
} else {
    Write-Host "  [OK] WinRing0 driver not registered." -ForegroundColor Green
}

# ── Summary ───────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
if ($findings -gt 0) {
    Write-Host "  RESULT: $findings indicator(s) of compromise found." -ForegroundColor Red
    Write-Host "  Your system IS INFECTED with the uTorrent cryptominer." -ForegroundColor Red
    Write-Host "" 
    Write-Host "  To remove it, run:" -ForegroundColor Yellow
    Write-Host "    .\Remove-CryptominerThreat.ps1" -ForegroundColor White
    Write-Host ""
    Write-Host "  Or follow the manual removal steps in the README." -ForegroundColor White
} else {
    Write-Host "  RESULT: No indicators of compromise found." -ForegroundColor Green
    Write-Host "  Your system appears clean." -ForegroundColor Green
}
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""
