# tools/ — shared cross-platform tools

This folder holds **our own** small utilities that are installed by **all three**
scaffolders (Windows, macOS, Linux). Unlike `<platform>/tools/*`, which install
third-party software, the code here is maintained in this repo and shared across
every platform.

Each tool lives in its own subfolder and is installed by a matching
`NN-<tool>` script in every scaffolder's `tools/` directory (e.g.
`linux/tools/35-jump.sh`, `windows/tools/35-jump.ps1`).

## Conventions

- Tools are written in **Python 3** (installed by every scaffolder) using the
  **standard library only** — no third-party dependencies — so a single
  implementation runs identically on every OS.
- A tool's local state (its JSON DB, if any) lives at the **install location**,
  not in this repo.
- A command that must change the parent shell's state (like `cd`) is exposed as
  a **shell function**. The tool's installer is self-contained: it writes a
  shell-integration file at the install location (`init.zsh` / `init.ps1`) and
  idempotently wires a marker-guarded `source` line into the user's shell rc
  (`~/.zshrc` for Unix, the PowerShell profile for Windows). The deployed
  `configs/` profiles also source that file, so `--only <tool>` and full
  installs both work.

## Tools

| Tool | Folder | Command | What it does |
|------|--------|---------|--------------|
| jump | `tools/jump/` | `j` | A tiny autojump-style directory jumper with a TUI picker. |
