# 🖥️ Dev-Machine Scaffolder

One-click reproducible setup for a fresh dev machine. Platform-specific scripts
live under `windows/`, `macos/`, and `linux/`.

---

## Windows — Quick start

```powershell
git clone https://github.com/phoenixzqy/dev-scaffolder $env:USERPROFILE\workspace\dev-scaffolder
cd $env:USERPROFILE\workspace\dev-scaffolder\windows
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
.\install-all.ps1
```

Or run a subset:

```powershell
.\install-all.ps1 -Only nvim,starship,pwsh-profile
.\install-all.ps1 -Skip windows-terminal
.\install-all.ps1 -DryRun
```

## Layout

```
windows/
  install-all.ps1          # orchestrator — runs tools/*.ps1 in numeric order
  capture.ps1              # snapshot live configs from this machine into configs/
  lib/common.ps1           # shared helpers (winget, scoop, deploy, backup)
  tools/
    00-package-managers.ps1
    10-git.ps1   15-gh.ps1   20-node.ps1   25-python.ps1
    30-cli-tools.ps1   35-jump.ps1   40-fonts.ps1   50-starship.ps1   55-lazygit.ps1
    60-copilot-cli.ps1   70-nvim.ps1   80-windows-terminal.ps1   90-pwsh-profile.ps1
  configs/
    nvim/   starship/   windows-terminal/   lazygit/   gh/   pwsh/
  tests/

macos/
  install-all.sh           # orchestrator — runs tools/*.sh in numeric order
  capture.sh               # snapshot live configs from this machine into configs/
  lib/common.sh            # shared helpers (brew, deploy, backup)
  tools/
    00-homebrew.sh   10-git.sh   15-gh.sh   20-node.sh   25-python.sh
    30-cli-tools.sh   35-jump.sh   40-fonts.sh   50-starship.sh   55-lazygit.sh
    60-copilot-cli.sh   70-nvim.sh   80-ghostty.sh   90-zsh-profile.sh
  configs/
    nvim/   starship/   ghostty/   lazygit/   gh/   zsh/

linux/
  install-all.sh           # orchestrator — runs tools/*.sh in numeric order
  capture.sh               # snapshot live configs from this machine into configs/
  lib/common.sh            # shared helpers (apt, deploy, backup, sudo)
  tools/
    00-apt-update.sh   10-git.sh   15-gh.sh   20-node.sh   25-python.sh
    30-cli-tools.sh   35-jump.sh   40-fonts.sh   50-starship.sh   55-lazygit.sh
    60-copilot-cli.sh   70-nvim.sh   80-ghostty.sh   90-zsh-profile.sh
  configs/
    nvim/   starship/   ghostty/   lazygit/   gh/   zsh/

tools/                     # shared, self-maintained cross-platform tools
  jump/jump.py             # `j` — autojump-style directory jumper (Python stdlib)
  README.md                # conventions for shared tools; installed by all 3 scaffolders
```

Each `tools/*` script is **standalone** — run it on its own to (re)install just
that tool. The orchestrator simply runs them in order. Config files live in
`<platform>/configs/` as real files you can diff, edit, and review in PRs.

## Updating settings

Edit the real config wherever the app lives (e.g. `~/.config/starship.toml`),
then snapshot the change back into this repo and commit:

```bash
# macOS / Linux
./macos/capture.sh   # or ./linux/capture.sh
git add macos/configs && git commit -m "tweak: starship palette"
```

```powershell
# Windows
.\windows\capture.ps1
git add windows/configs && git commit -m "tweak: starship palette"
```

## Tools covered

All three platforms install the same core tools. Platform-specific differences noted below.

| # | Tool | Windows (winget/scoop) | macOS (brew) | Linux (apt) | Config deployed |
|---|------|----------------------|--------------|-------------|-----------------|
| 00 | Package manager | winget + scoop | Homebrew | apt + build-essential | — |
| 10 | Git + aliases | `Git.Git` | `git` | `git` | `~/.gitconfig` aliases |
| 15 | GitHub CLI (gh) | `GitHub.cli` | `gh` | apt repo | `config.yml` (no tokens) |
| 20 | Node.js LTS + globals | `OpenJS.NodeJS.LTS` | `node` | NodeSource | — |
| 25 | Python 3 + packages | `Python.Python.3.12` | `python3` | `python3` | — |
| 30 | rg, fd, fzf, bat, zoxide, cmake | winget | brew | apt + curl | — |
| 35 | `j` directory jumper | our own (Python) | our own (Python) | our own (Python) | `j` shell function |
| 40 | JetBrainsMono Nerd Font | nerd-fonts zip | brew cask | nerd-fonts zip | — |
| 50 | Starship prompt | `Starship.Starship` | `starship` | curl installer | `~/.config/starship.toml` |
| 55 | Lazygit | scoop `extras/lazygit` | `lazygit` | GitHub release | `config.yml` |
| 60 | GitHub Copilot CLI | `npm i -g @github/copilot` | same | same | — |
| 70 | Neovim + plugins | `Neovim.Neovim` | `neovim` | PPA / AppImage | `nvim/` config dir |
| 80 | Terminal | Windows Terminal | Ghostty | Ghostty (optional) | `settings.json` / `config` |
| 90 | Shell profile | PowerShell profile | zsh + Oh My Zsh | zsh + Oh My Zsh | `$PROFILE` / `.zshrc` |

## `j` — directory jumper

A small, self-maintained tool we ship in `tools/jump/` (a simplified
[autojump](https://github.com/wting/autojump)) and install on all three
platforms. One global command, `j`, saves directories and jumps back into them
through a terminal picker. Pure Python standard library, so it runs identically
everywhere.

```text
j add            # save the current directory
j                # open the picker and cd into the chosen directory
j list           # print saved paths
j version        # print the installed version
j update         # self-update to the latest release
j -h             # full help
```

The picker shows a table — path on the left, **jump count** and **date added**
on the right — ordered by pinned → most-jumped → newest. Missing directories are
shown in red. Keys: `↑/↓` move, `enter` jump, `d` delete, `p` pin, `u` unpin,
`/` search, `q` quit. See [`tools/jump/README.md`](tools/jump/README.md) for
details.

**Upgrades.** The engine carries a `__version__`; re-running any scaffolder
(`./install-all.sh`, including `--only jump`) compares it against the installed
copy and upgrades in place only when they differ. You can also self-update
without the repo via `j update`, which downloads the latest `jump.py` from
GitHub and atomically replaces the installed engine.

## Notes

- **Idempotent.** Re-running is safe; installers skip packages that are already present.
- **No admin required.** Fonts register per-user; packages install at user scope.
- **Secrets are never committed.** `gh auth` tokens (`hosts.yml`) are deliberately excluded — run `gh auth login` once after install.
- **Backups.** Any existing target config is renamed to `<name>.bak.<timestamp>` before a deploy.

## Neovim details

### What's Included

| Category | Plugins |
|----------|---------|
| **Theme** | kanagawa.nvim (wave) |
| **File Explorer** | nvim-tree.lua + devicons |
| **Fuzzy Finders** | fzf.vim + Telescope (with live-grep-args, fzf-native) |
| **LSP** | mason.nvim + mason-lspconfig + nvim-lspconfig (ts_ls, pyright, lua_ls, html, cssls, jsonls, bashls) |
| **Autocompletion** | nvim-cmp + LuaSnip + friendly-snippets |
| **Syntax** | nvim-treesitter (JS/TS/Python/Lua/HTML/CSS/JSON/YAML/Bash/Markdown/C#) |
| **Statusline** | lualine.nvim + bufferline.nvim |
| **Git** | vim-fugitive + gitsigns.nvim |
| **Formatting** | conform.nvim (black, stylua, shfmt) |
| **Linting** | nvim-lint (ESLint) |
| **Spell Check** | vim-dirtytalk + spelunker.vim |
| **UI** | nvim-scrollbar, nvim-cursorline, colorful-winsep, dropbar.nvim |
| **Markdown** | markdown-preview.nvim |
| **AI** | copilot.vim + CopilotChat.nvim |
| **Classic Vim** | vim-surround, rainbow |

## Testing

The repo ships with two layers of tests.

### 1. Pester unit tests — fast, safe, runs anywhere

```powershell
.\windows\tests\Invoke-Tests.ps1          # pretty output
.\windows\tests\Invoke-Tests.ps1 -CI      # returns non-zero on failure
```

Covers ~60 assertions: every `.ps1` parses, every `windows/tools/*.ps1` dot-sources the shared lib, `Deploy-Config` backs up existing targets, `-Only/-Skip/-DryRun` filters work, captured configs exist, and `gh/config.yml` has no OAuth tokens.

### 2. Windows Sandbox — fresh Windows VM, real install

The only way to truly verify a from-scratch install works is to run it on a fresh Windows box. `windows/tests/sandbox.wsb` spins up an ephemeral, disposable Windows VM that mounts this repo read-only and auto-runs `install-all.ps1` on logon.

One-time setup (elevated PowerShell, then reboot):

```powershell
Enable-WindowsOptionalFeature -Online -FeatureName Containers-DisposableClientVM -All
```

Then just double-click `windows/tests/sandbox.wsb`. The sandbox is destroyed when you close the window, so you can re-run as often as you like with zero state bleed.

### 3. Live idempotency check (on your current machine)

Re-running any `windows/tools/*.ps1` on a machine that already has the tool installed should be a no-op. This is tested explicitly and you can sanity-check on demand:

```powershell
.\windows\tools\10-git.ps1       # prints "Git (already present)"
.\windows\tools\40-fonts.ps1     # prints "JetBrainsMono Nerd Font (already present)"
```

## macOS — Quick start

```bash
git clone https://github.com/phoenixzqy/dev-scaffolder ~/workspace/dev-scaffolder
cd ~/workspace/dev-scaffolder/macos
chmod +x install-all.sh
./install-all.sh
```

Or run a subset:

```bash
./install-all.sh --only nvim,starship,zsh-profile
./install-all.sh --skip ghostty
./install-all.sh --dry-run
```

## Linux (Ubuntu/Debian) — Quick start

```bash
git clone https://github.com/phoenixzqy/dev-scaffolder ~/workspace/dev-scaffolder
cd ~/workspace/dev-scaffolder/linux
chmod +x install-all.sh
./install-all.sh
```

Or run a subset:

```bash
./install-all.sh --only nvim,starship,zsh-profile
./install-all.sh --skip ghostty
./install-all.sh --dry-run
```

> **Note:** Tested on Ubuntu 22.04 / 24.04. Requires `sudo` for apt operations.
> Ghostty is optional and will be skipped if the apt repo is unavailable.
> On Ubuntu, `fd` and `bat` are available as `fdfind`/`batcat` — the scaffolder
> creates symlinks in `~/.local/bin` for compatibility.

## Neovim key bindings

| Key | Action |
|-----|--------|
| `Ctrl+N` | Toggle file tree |
| `Ctrl+P` | Fuzzy file finder (fzf) |
| `\f` | Ripgrep project-wide search |
| `\ff` | Telescope find files |
| `\fg` | Telescope live grep |
| `\fb` | Telescope buffers |
| `F1-F9` | Go to buffer 1-9 |
| `Shift+←/→` | Cycle buffers |
| `Ctrl+↑/↓/←/→` | Navigate viewports |
| `gd / gr / K` | LSP: definition / references / hover |
| `\rn / \ca` | LSP: rename / code action |
| `\cc` | Toggle Copilot Chat |
| `\mp` | Toggle Markdown preview |

## Notes

- Backs up existing `~/.config/nvim` (macOS) or `%LOCALAPPDATA%\nvim` (Windows) before overwriting
- Installs JetBrainsMono Nerd Font for proper icon rendering
- Leader key is `\` (backslash)
- Requires Neovim 0.11+ for `vim.lsp.config` API
