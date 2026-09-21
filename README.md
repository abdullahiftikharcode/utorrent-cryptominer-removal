# 🛡️ uTorrent Hidden Cryptominer — Detection & Removal Guide

> **Your "COM Surrogate" is eating 40%+ CPU? It's not Windows — it's a disguised XMRig miner dropped by uTorrent's official installer.**

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-blue.svg)]()
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue.svg)]()
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

---

## ⚠️ The Problem

If you've ever opened Task Manager and seen **"COM Surrogate"** pinning an entire CPU core at 100% usage (typically showing as 25–50% total CPU depending on your core count), **you may be running a hidden cryptocurrency miner** that was silently installed by uTorrent's official bundled installer.

This isn't a Windows bug. This isn't a thumbnail rendering issue. This is a **trojanized XMRig Monero miner** disguised to look like a legitimate Windows process.

### How It Disguises Itself

| Attribute | Real Windows COM Surrogate | The Miner |
|:---|:---|:---|
| **Process Name** | `dllhost.exe` (two lowercase L's) | `dlIhost.exe` (lowercase L + uppercase I) |
| **File Location** | `C:\Windows\System32\` | `C:\Users\<you>\AppData\Roaming\Dll\` |
| **File Description** | COM Surrogate | COM Surrogate *(spoofed)* |
| **Supporting Files** | Windows system DLLs | `WinRing0x64.sys` (XMRig MSR mining driver) |
| **Persistence** | On-demand by Windows shell | Scheduled Task `\UpdateTask` at every logon |
| **Defender Status** | Scanned normally | **Self-excluded** from Windows Defender |

The process name uses a **homoglyph attack**: the lowercase letter `l` is swapped for an uppercase `I`, making `dlIhost.exe` visually identical to `dllhost.exe` in Task Manager's default font. The executable also sets its Description field to "COM Surrogate" and its Company to "Microsoft Corporation" to complete the disguise.

### The Infection Chain

```
uTorrent Official Installer (utorrent.com)
    │
    ├── Installs uTorrent normally
    │
    └── BundleInstaller payload (PUABundler:Win32/uTorrent_BundleInstaller)
        │
        ├── Drops dlIhost.exe (XMRig miner) to %AppData%\Roaming\Dll\
        ├── Drops WinRing0x64.sys (kernel MSR driver for mining)
        ├── Adds Defender exclusion: %AppData%\Roaming\DLL
        └── Creates Scheduled Task "\UpdateTask" (logon trigger)
```

**Windows Defender doesn't catch it** because the malware's first action is to add its own directory to Defender's exclusion list using `Add-MpPreference -ExclusionPath`, which requires no UAC prompt when run from the user's context. By the time Defender would scan the file, the folder is already whitelisted.

---

## 🔍 Am I Infected? — Quick Check

### Method 1: One-Line PowerShell Check (Run as Administrator)

```powershell
Get-CimInstance Win32_Process | Where-Object { $_.ExecutablePath -like '*AppData*Dll*host*' } | Select-Object ProcessId, ExecutablePath, CommandLine
```

**If this returns any results, you are infected.** If it returns nothing, you're clean.

### Method 2: Manual Check

1. Open **Task Manager** → sort by **CPU** usage
2. If "COM Surrogate" is using 25–50% CPU constantly, **right-click it** → **Open file location**
3. If it opens to `C:\Users\<you>\AppData\Roaming\Dll\` instead of `C:\Windows\System32\`, **you have the miner**

### Method 3: Check for the Scheduled Task

```powershell
Get-ScheduledTask -TaskName 'UpdateTask' -ErrorAction SilentlyContinue | Select-Object TaskName, State, @{N='Action';E={$_.Actions.Execute}}
```

If this shows an action pointing to `AppData\Roaming\Dll\dlIhost.exe`, you're infected.

### Method 4: Check Defender Exclusions

```powershell
(Get-MpPreference).ExclusionPath | Where-Object { $_ -match 'DLL|Dll' }
```

If you see `C:\Users\<you>\AppData\Roaming\DLL` in the exclusion list, the miner added it.

---

## 🧹 Removal

### Option A: Automated Script (Recommended)

Download and run [`Remove-CryptominerThreat.ps1`](scripts/Remove-CryptominerThreat.ps1) as Administrator:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\scripts\Remove-CryptominerThreat.ps1
```

This script will:
1. Kill the miner process (`dlIhost.exe`)
2. Remove the persistence mechanism (`\UpdateTask` scheduled task)
3. Delete the malware directory (`%AppData%\Roaming\Dll\`)
4. Remove the self-added Windows Defender exclusion
5. Verify complete removal with 5 automated checks

### Option B: Manual Removal

```powershell
# 1. Kill the miner
Stop-Process -Name 'dlIhost' -Force -ErrorAction SilentlyContinue

# 2. Remove the scheduled task
Unregister-ScheduledTask -TaskName 'UpdateTask' -Confirm:$false

# 3. Delete the malware directory
Remove-Item "$env:AppData\Dll" -Recurse -Force

# 4. Remove Defender exclusion
Remove-MpPreference -ExclusionPath "$env:AppData\DLL"

# 5. Verify
Get-Process -Name 'dlIhost' -ErrorAction SilentlyContinue  # Should return nothing
Test-Path "$env:AppData\Dll"  # Should return False
```

---

## 🗑️ Remove uTorrent Completely

Since uTorrent's official installer is the infection vector, we strongly recommend removing it entirely and switching to **[qBittorrent](https://www.qbittorrent.org/)** (open-source, no bundled software, no ads).

Run [`Remove-uTorrent.ps1`](scripts/Remove-uTorrent.ps1) as Administrator for a complete removal:

```powershell
.\scripts\Remove-uTorrent.ps1
```

This removes:
- All uTorrent and uTorrent Web application files
- Registry entries (uninstall, file associations, class registrations)
- Startup autorun entries
- Scheduled tasks
- Any Defender exclusions added by uTorrent

---

## 📊 Indicators of Compromise (IOCs)

### File System

| Indicator | Path |
|:---|:---|
| Miner binary | `%AppData%\Roaming\Dll\dlIhost.exe` |
| Kernel driver | `%AppData%\Roaming\Dll\WinRing0x64.sys` |
| Miner directory | `%AppData%\Roaming\Dll\` |

### File Metadata

| Property | Value |
|:---|:---|
| `dlIhost.exe` size | 4,848,128 bytes (4.62 MB) |
| `WinRing0x64.sys` size | 14,544 bytes |
| Compile date | June 3, 2024 |
| Spoofed Company | Microsoft Corporation |
| Spoofed Description | COM Surrogate |

### Registry

| Key | Value |
|:---|:---|
| Defender exclusion | `HKLM:\SOFTWARE\Microsoft\Windows Defender\Exclusions\Paths` → `%AppData%\Roaming\DLL` |

### Scheduled Tasks

| Task | Trigger | Action |
|:---|:---|:---|
| `\UpdateTask` | `MSFT_TaskLogonTrigger` (every user logon) | `%AppData%\Roaming\Dll\dlIhost.exe` |

### Windows Defender Detection

| Threat ID | Threat Name | Severity |
|:---|:---|:---|
| 311958 | `PUABundler:Win32/uTorrent_BundleInstaller` | Low (1) |

### Process Characteristics

- Process name appears as "COM Surrogate" in Task Manager
- Sustained CPU usage of one full core (25–50% total CPU)
- Working Set (RAM) is typically small (~6 MB) despite massive CPU usage
- Accumulates thousands of seconds of CPU time if left running

---

## 🧰 Tools Included

| Script | Purpose |
|:---|:---|
| [`scripts/Remove-CryptominerThreat.ps1`](scripts/Remove-CryptominerThreat.ps1) | Detects and removes the dlIhost.exe miner, its persistence, and Defender exclusion |
| [`scripts/Remove-uTorrent.ps1`](scripts/Remove-uTorrent.ps1) | Completely uninstalls uTorrent & uTorrent Web with full cleanup |
| [`scripts/Detect-CryptominerThreat.ps1`](scripts/Detect-CryptominerThreat.ps1) | Detection-only scan (no changes made) — safe to run for checking |

---

## 📖 Technical Deep Dive

### Why This Evades Detection

1. **Defender Self-Exclusion**: The installer runs `Add-MpPreference -ExclusionPath` from the user's context (no UAC required) before dropping the miner binary. Windows Defender never scans the folder.

2. **Homoglyph Process Name**: `dlIhost.exe` vs `dllhost.exe` — the capital `I` is visually identical to lowercase `l` in Task Manager's Segoe UI font. Users see "COM Surrogate" with the correct description and company name.

3. **Legitimate Kernel Driver**: `WinRing0x64.sys` is a legitimate open-source driver used by hardware monitoring tools (HWiNFO, CPU-Z, etc.). It's digitally signed and not flagged by antivirus. XMRig uses it to write MSR registers for maximum mining performance.

4. **PUA Classification**: Defender classifies the uTorrent installer as `PUABundler` (Severity 1 — Low). By default, PUA detection may be disabled or set to warn-only, not block. The miner payload drops before PUA scanning completes.

5. **No Network IOCs at Install Time**: The miner binary is embedded in the installer bundle, not downloaded from a C2 server. There are no suspicious network connections during installation to trigger firewall or IDS alerts.

### The WinRing0x64.sys Driver

This is a legitimate open-source ring-0 driver ([OpenLibSys/WinRing0](https://github.com/GermanAizek/WinRing0)) commonly used by:
- HWiNFO64, CPU-Z, AIDA64, FanControl
- Various overclocking and monitoring utilities

XMRig uses it to write Model-Specific Registers (MSRs) — specifically to disable hardware prefetchers and set large pages — which significantly improves RandomX mining hash rates. Because the driver is legitimately signed and widely used, no antivirus flags it.

---

## ❓ FAQ

### Q: Is this really from uTorrent's official website?
**Yes.** The uTorrent free installer from `utorrent.com` bundles third-party software through an "offer" system. Windows Defender itself detects the installer as `PUABundler:Win32/uTorrent_BundleInstaller`. This has been documented since at least 2015 when [uTorrent was caught bundling a Bitcoin miner called EpicScale](https://torrentfreak.com/utorrent-quietly-installs-cryptomining-software-150306/).

### Q: Why didn't Defender stop it?
The malware adds a Defender exclusion for its own directory using `Add-MpPreference -ExclusionPath` **before** writing the miner binary to disk. This cmdlet works without UAC elevation when run from the user's own context.

### Q: What cryptocurrency does it mine?
**Monero (XMR)** via the RandomX algorithm using XMRig.

### Q: Should I change my passwords?
The XMRig miner itself doesn't steal credentials. However, the presence of a bundled miner means the installer executed arbitrary code. As a precaution, change important passwords and enable 2FA.

### Q: What should I use instead of uTorrent?
**[qBittorrent](https://www.qbittorrent.org/)** — open-source, no ads, no bundles, no miners.

---

## 🤝 Contributing

If you've been affected by this, please help others find this information:

1. **⭐ Star this repo** — it helps it appear in search results
2. **Submit file hashes** — open an Issue with your `dlIhost.exe` SHA256 hash so we can track variants
3. **Report your uTorrent version** — help us map which installer versions carry the payload
4. **Share your experience** — blog posts, Reddit threads, forum posts linking back here
5. **Submit PRs** — improved detection scripts, additional IOCs, translations

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines.

---

## 📜 License

MIT License — see [LICENSE](LICENSE) for details.

---

## 🔗 Related Resources

- [TorrentFreak: uTorrent Quietly Installs Cryptomining Software (2015)](https://torrentfreak.com/utorrent-quietly-installs-cryptomining-software-150306/)
- [XMRig GitHub Repository](https://github.com/xmrig/xmrig)
- [WinRing0 Driver Documentation](https://github.com/GermanAizek/WinRing0)
- [Microsoft: PUABundler Detection](https://learn.microsoft.com/en-us/defender-endpoint/detect-block-potentially-unwanted-apps-microsoft-defender-antivirus)

---

<p align="center">
  <strong>If this helped you, please ⭐ star this repo so others can find it.</strong><br>
  Every star helps this appear when someone searches "COM Surrogate high CPU" or "dllhost.exe 100% CPU".
</p>
