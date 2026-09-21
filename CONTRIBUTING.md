# Contributing to uTorrent Cryptominer Removal

Thank you for helping others protect their systems! Here's how you can contribute.

## 🐛 Reporting Your Infection

If you've been affected, please [open an Issue](../../issues/new?template=infection_report.yml) with:

1. **uTorrent version** you had installed
2. **When you installed it** (approximate date)
3. **SHA256 hash** of your `dlIhost.exe` (if you still have it):
   ```powershell
   Get-FileHash "$env:AppData\Dll\dlIhost.exe" -Algorithm SHA256
   ```
4. **How you discovered it** (Task Manager, antivirus alert, etc.)
5. **Your Windows version** (run `winver`)

## 🔧 Improving Scripts

### Guidelines
- All scripts must work on **PowerShell 5.1+** (ships with Windows 10/11)
- Use `$env:APPDATA` and similar variables instead of hardcoded paths
- Include `-ErrorAction SilentlyContinue` on operations that may fail
- Always verify after making changes (check that removal actually succeeded)
- Detection scripts must be **read-only** — no system modifications

### Testing
- Test on a clean Windows install to ensure no false positives
- Test on an infected system (VM recommended) to ensure detection works
- Run `Invoke-ScriptAnalyzer` (PSScriptAnalyzer) if available

## 📝 Improving Documentation

- Fix typos and improve clarity
- Add translations (create `docs/README.<lang>.md`)
- Add screenshots of the infection in Task Manager
- Document new variants or infection vectors

## 🔒 Submitting IOCs

If you have file hashes, registry keys, network indicators, or other IOCs from variants of this threat:

1. Fork the repo
2. Add your IOCs to the README's IOC section
3. Open a PR with details on the variant

## Code of Conduct

- Be respectful and constructive
- Focus on helping victims, not blaming them
- Don't submit actual malware samples to this repo — use hashes only
- Report responsibly — this project documents threats, not enables them

## Pull Request Process

1. Fork the repo and create a feature branch
2. Make your changes
3. Test thoroughly
4. Open a PR with a clear description of what you changed and why
5. Link any related Issues

Thank you for contributing! ⭐
