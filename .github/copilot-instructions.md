# AGENT.md — Project Instructions for AI Agents

> Automatically loaded by GitHub Copilot coding agent and Copilot CLI.
> Also referenced from `.github/copilot-instructions.md` (VS Code Copilot)
> and `CLAUDE.md` (Claude Code).

## Project Overview

**dev-scaffolder** is a one-click, idempotent dev-machine setup tool. It installs
CLI tools, deploys config files, and configures the terminal environment from
scratch. Platform-specific code lives in `windows/` and `macos/`.

## Repository Layout

```
windows/                    # Windows scaffolder (PowerShell)
  install-all.ps1           #   orchestrator — runs tools/*.ps1 in numeric order
  capture.ps1               #   snapshot live configs back into configs/
  lib/common.ps1            #   shared helpers (winget, scoop, deploy, backup)
  tools/NN-<name>.ps1       #   one script per tool, standalone & idempotent
  configs/<tool>/           #   config files deployed to their target locations
  tests/                    #   Pester 5 tests + Windows Sandbox .wsb

macos/                      # macOS scaffolder (Bash + Homebrew)
  install-all.sh            #   orchestrator — runs tools/*.sh in numeric order
  capture.sh                #   snapshot live configs back into configs/
  lib/common.sh             #   shared helpers (brew_install, deploy_config, etc.)
  tools/NN-<name>.sh        #   one script per tool, standalone & idempotent
  configs/<tool>/           #   config files deployed to their target locations

linux/                      # Linux scaffolder (Bash + apt, Ubuntu/Debian)
  install-all.sh            #   orchestrator — runs tools/*.sh in numeric order
  capture.sh                #   snapshot live configs back into configs/
  lib/common.sh             #   shared helpers (apt_install, deploy_config, sudo, arch detect)
  tools/NN-<name>.sh        #   one script per tool, standalone & idempotent
  configs/<tool>/           #   config files deployed to their target locations

.ai/skills/                 # Reusable LLM skill prompts (see below)

tools/                      # Shared, self-maintained cross-platform tools
  jump/jump.py              #   `j` — autojump-style directory jumper (Python stdlib)
  README.md                 #   conventions for shared tools
```

## Shared Tools (`tools/`)

The repo-root `tools/` folder holds **our own** utilities that are installed by
**all three** scaffolders (not third-party software). Conventions:

- Written in **Python 3** (installed by every scaffolder) using the **standard
  library only** — one implementation runs identically on every OS.
- A tool's local state (e.g. a JSON DB) lives at the **install location**, never
  committed to the repo.
- Installed by a matching `NN-<tool>` script in every scaffolder's `tools/`
  directory (e.g. `linux/tools/35-jump.sh`, `macos/tools/35-jump.sh`,
  `windows/tools/35-jump.ps1`), which copies the tool to its install location.
- **Versioned & upgradeable.** Each tool carries a `__version__` constant. Its
  installer is **version-aware**: it reads `__version__` from the bundled source
  and the installed copy, upgrades in place only when they differ, and reports
  `already at vX` otherwise (keeping the step idempotent). Where practical a tool
  also offers a self-update path that fetches the latest source from GitHub raw
  and atomically replaces the installed copy (e.g. `j update`).
- A command that must change the parent shell's state (like `cd`) is exposed as
  a **shell function**. The tool's installer is self-contained: it writes a
  shell-integration file at the install location (`init.zsh` / `init.ps1`) and
  idempotently wires a marker-guarded `source` line into the user's shell rc
  (`~/.zshrc` on Unix, the PowerShell profile on Windows). The deployed
  `configs/` profiles also source that integration file, so both `--only <tool>`
  runs and full installs work.
- Current tools: **`j`** (`tools/jump/`) — a simplified autojump with a TUI
  picker; see `tools/jump/README.md`. Supports `j version` / `j update`.

## Conventions

### PowerShell (Windows)

- Every `tools/*.ps1` script **must** dot-source `"$PSScriptRoot\..\lib\common.ps1"` on line 2.
- Scripts are named `NN-<tool>.ps1` where NN is a two-digit sort order.
- Use `Install-WingetPackage` or `Install-ScoopPackage` from `lib/common.ps1`
  for idempotent installs — never raw `winget install` / `scoop install`.
- Use `Deploy-Config -Source ... -Target ...` to place config files (handles
  backup of existing targets automatically).
- Use `Write-Banner`, `Write-Step`, `Write-Ok`, `Write-Skip`, `Write-Warn2`
  for consistent output.
- All scripts must be `#Requires -Version 5.1`.
- Scripts must be idempotent — re-running on a machine that already has the
  tool installed should be a no-op (print "already present" and return).

### Bash (macOS)

- Every `tools/*.sh` script **must** source `"$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"` near the top.
- Scripts are named `NN-<tool>.sh` where NN is a two-digit sort order.
- Scripts must start with `#!/usr/bin/env bash` and `set -euo pipefail`.
- Use `brew_install` or `brew_cask_install` from `lib/common.sh` for idempotent
  installs — never raw `brew install`.
- Use `deploy_config` to place config files (handles backup of existing targets).
- Use `write_banner`, `write_step`, `write_ok`, `write_skip`, `write_warn`
  for consistent output.
- Scripts must be idempotent — re-running should be a no-op when already installed.
- Use `capture.sh` (macOS) to snapshot live configs back into the repo.

### Bash (Linux)

- Every `tools/*.sh` script **must** source `"$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"` near the top.
- Scripts are named `NN-<tool>.sh` where NN is a two-digit sort order.
- Scripts must start with `#!/usr/bin/env bash` and `set -euo pipefail`.
- Use `apt_install` from `lib/common.sh` for idempotent installs — never raw `apt-get install`.
- Use `as_root` for commands needing sudo — never raw `sudo`.
- Use `add_apt_repo` for adding signed apt repositories (modern `/etc/apt/keyrings` approach).
- Use `github_release_install` for tools not in apt (e.g., lazygit).
- Use `deploy_config` to place config files (handles backup of existing targets).
- Use `write_banner`, `write_step`, `write_ok`, `write_skip`, `write_warn`
  for consistent output.
- Scripts must be idempotent — re-running should be a no-op when already installed.
- Target Ubuntu 22.04/24.04. Use `DISTRO_ID` from `lib/common.sh` when branching on distro.
- Use `capture.sh` (Linux) to snapshot live configs back into the repo.

### Config Files

- Config files live in `<platform>/configs/<tool>/` as real, diffable files.
- Never commit secrets, tokens, or machine-specific paths (like absolute home dirs).
- Use `capture.ps1` (Windows) or `capture.sh` (macOS/Linux) to snapshot live configs back into the repo.

### Documentation

- Keep the root `README.md` in sync with the code. Whenever you **add a tool**,
  **change install/run commands**, **alter the repo layout**, or **change
  user-facing behavior**, update `README.md` in the same change:
  - add/adjust the tool's row in the "Tools covered" table,
  - update the "Layout" tree if files/folders moved,
  - add or revise any quick-start or usage snippets.
- A shared tool (under `tools/`) keeps its own `tools/<tool>/README.md`; when you
  change its behavior, update both that file and the root `README.md` summary.
- `README.md` / `CLAUDE.md` / `AGENT.md` and `.github/copilot-instructions.md`
  are the source-of-truth docs (the latter three are symlinks to one file) — when
  conventions change, update `.github/copilot-instructions.md`.

### Testing

- Windows Pester tests live in `windows/tests/` and require Pester 5+.
- Every `.ps1` file must parse without syntax errors.
- Every `tools/*.ps1` must dot-source `lib/common.ps1`.
- Run tests: `windows/tests/Invoke-Tests.ps1`

## Skills

Reusable skill prompts are stored in `.ai/skills/`. Reference them when
performing common tasks:

| Skill | File | Use When |
|-------|------|----------|
| Add Windows Tool | `.ai/skills/add-windows-tool.md` | Adding a new tool to the Windows scaffolder |
| Add macOS/Linux Tool | `.ai/skills/add-unix-tool.md` | Adding a new tool to the macOS or Linux scaffolder |
| PowerShell Conventions | `.ai/skills/powershell-conventions.md` | Writing or reviewing PowerShell scripts |
| Bash Conventions | `.ai/skills/bash-conventions.md` | Writing or reviewing Bash scripts |
| Manage Configs | `.ai/skills/manage-configs.md` | Adding, updating, or deploying config files |

## Do's and Don'ts

- **Do** keep scripts idempotent and standalone.
- **Do** use the helper functions in `lib/common.ps1` instead of raw commands.
- **Do** back up existing configs before overwriting.
- **Do** update `README.md` whenever you add a tool or change commands, layout, or behavior.
- **Do** run `windows/tests/Invoke-Tests.ps1` after changes.
- **Don't** commit secrets, OAuth tokens, or API keys.
- **Don't** require admin/elevated permissions — use per-user installs.
- **Don't** add tools that can't be installed silently/unattended.
