# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in the scripts provided in this repository, please report it responsibly:

1. **DO NOT** open a public Issue
2. Email the maintainer directly or use GitHub's private vulnerability reporting feature
3. Include steps to reproduce the issue

## Scope

This repository contains **detection and removal scripts** for a known threat. The scripts themselves should:

- Never execute arbitrary code from the internet
- Never modify system files beyond the documented scope
- Always verify changes after making them
- Always require Administrator confirmation before destructive operations

## Responsible Disclosure

This repository documents a real-world threat. We follow responsible disclosure principles:

- We document **detection and removal** techniques, not exploitation techniques
- We share **indicators of compromise** (hashes, paths) to help defenders
- We do NOT distribute malware samples
- We provide context and education about how the threat operates
