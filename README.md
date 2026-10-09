# 🖥️ Dev-Machine Scaffolder

One-click, idempotent setup for a fresh dev machine. Platform-specific scripts
live under `windows/`, `macos/`, and `linux/`, and share a set of
self-maintained tools under `tools/`.

## Table of contents

- [Quick start (one-liner)](#quick-start-one-liner)
  - [macOS / Linux](#macos--linux)
  - [Windows](#windows)
  - [Passing options to the installer](#passing-options-to-the-installer)
- [Manual install (clone then run)](#manual-install-clone-then-run)
- [Running a subset](#running-a-subset)
- [Layout](#layout)
- [Tools covered](#tools-covered)
- [`j` — directory jumper](#j--directory-jumper)
- [Devbox SSH](#devbox-ssh)
- [Updating settings](#updating-settings)
- [Notes](#notes)
- [Neovim details](#neovim-details)
  - [What's included](#whats-included)
  - [Key bindings](#key-bindings)
- [Testing](#testing)

---

## Quick start (one-liner)

The fastest path — no manual cloning. The bootstrap script installs `git` if
needed, clones the repo into a throwaway temp directory, runs the installer for
your platform, and then removes the temporary checkout — a clean install that
leaves no repo behind.

### macOS / Linux

```bash
curl -fsSL https://raw.githubusercontent.com/phoenixzqy/dev-scaffolder/main/bootstrap.sh | bash
```

### Windows

In PowerShell:

```powershell
irm https://raw.githubusercontent.com/phoenixzqy/dev-scaffolder/main/bootstrap.ps1 | iex
```

> **Security tip:** piping a script straight into a shell runs remote code. If
> you'd rather read it first, download then run:
>
> ```bash
> # macOS / Linux
> curl -fsSL https://raw.githubusercontent.com/phoenixzqy/dev-scaffolder/main/bootstrap.sh -o bootstrap.sh
> less bootstrap.sh        # review
> bash bootstrap.sh
> ```
>
> ```powershell
> # Windows
> irm https://raw.githubusercontent.com/phoenixzqy/dev-scaffolder/main/bootstrap.ps1 -OutFile bootstrap.ps1
> notepad bootstrap.ps1    # review
> .\bootstrap.ps1
> ```

### Passing options to the installer

Any arguments after the bootstrap script are forwarded to the platform
installer (see [Running a subset](#running-a-subset)):

```bash
# macOS / Linux — note the `-s --` to pass args through the pipe
curl -fsSL https://raw.githubusercontent.com/phoenixzqy/dev-scaffolder/main/bootstrap.sh | bash -s -- --only jump
```

```powershell
# Windows — download then run (irm | iex can't take args)
irm https://raw.githubusercontent.com/phoenixzqy/dev-scaffolder/main/bootstrap.ps1 -OutFile bootstrap.ps1
.\bootstrap.ps1 -Only jump
```

The bootstrap target is overridable with environment variables:
`DEV_SCAFFOLDER_REPO` (owner/name or git URL), `DEV_SCAFFOLDER_REF`
(branch/tag/commit), and `DEV_SCAFFOLDER_DEST` (clone destination). By default
the checkout is cloned into a temp directory and removed after install; set
`DEV_SCAFFOLDER_DEST` to keep a persistent checkout at that path instead.

## Manual install (clone then run)

Prefer to clone yourself? Each platform has its own orchestrator.

```bash
# macOS
git clone https://github.com/phoenixzqy/dev-scaffolder ~/workspace/dev-scaffolder
cd ~/workspace/dev-scaffolder/macos
chmod +x install-all.sh
./install-all.sh
```

```bash
# Linux (Ubuntu/Debian)
git clone https://github.com/phoenixzqy/dev-scaffolder ~/workspace/dev-scaffolder
cd ~/workspace/dev-scaffolder/linux
chmod +x install-all.sh
./install-all.sh
```

```powershell
# Windows
git clone https://github.com/phoenixzqy/dev-scaffolder $env:USERPROFILE\workspace\dev-scaffolder
cd $env:USERPROFILE\workspace\dev-scaffolder\windows
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
.\install-all.ps1
```

> **Linux note:** Tested on Ubuntu 22.04 / 24.04. Requires `sudo` for apt
> operations. Ghostty is optional and will be skipped if the apt repo is
> unavailable. On Ubuntu, `fd` and `bat` are available as `fdfind`/`batcat` —
> the scaffolder creates symlinks in `~/.local/bin` for compatibility.

## Running a subset

Every `tools/*` script is **standalone** — run it on its own to (re)install just
that tool. The orchestrator runs them in numeric order and accepts filters:

```bash
# macOS / Linux
./install-all.sh --only nvim,starship,zsh-profile
./install-all.sh --skip ghostty
./install-all.sh --dry-run
```

```powershell
# Windows
.\install-all.ps1 -Only nvim,starship,pwsh-profile
.\install-all.ps1 -Skip windows-terminal
.\install-all.ps1 -DryRun
```

## Layout

```
lib/shell-profile.sh         # shared non-destructive shell integration
windows/
  install-all.ps1          # orchestrator — runs tools/*.ps1 in numeric order
  capture.ps1              # snapshot live configs from this machine into configs/
  lib/common.ps1           # shared helpers (winget, scoop, deploy, backup)
  tools/
    00-package-managers.ps1
    10-git.ps1   15-gh.ps1   20-node.ps1   25-python.ps1
    30-cli-tools.ps1   35-jump.ps1   36-ssh-script.ps1   40-fonts.ps1   50-starship.ps1   55-lazygit.ps1
    60-copilot-cli.ps1   65-pi.ps1   70-nvim.ps1   80-windows-terminal.ps1   90-pwsh-profile.ps1
  configs/
    nvim/   starship/   windows-terminal/   lazygit/   gh/   pwsh/
  tests/

macos/
  install-all.sh           # orchestrator — runs tools/*.sh in numeric order
  capture.sh               # snapshot live configs from this machine into configs/
  lib/common.sh            # shared helpers (brew, deploy, backup)
  tools/
    00-homebrew.sh   10-git.sh   12-zsh-profile.sh   15-gh.sh   20-node.sh
    25-python.sh
    30-cli-tools.sh   35-jump.sh   36-ssh-script.sh   40-fonts.sh   50-starship.sh   55-lazygit.sh
    60-copilot-cli.sh   65-pi.sh   70-nvim.sh   80-ghostty.sh
  configs/
    nvim/   starship/   ghostty/   lazygit/   gh/   zsh/

linux/
  install-all.sh           # orchestrator — runs tools/*.sh in numeric order
  capture.sh               # snapshot live configs from this machine into configs/
  lib/common.sh            # shared helpers (apt, deploy, backup, sudo)
  tools/
    00-apt-update.sh   10-git.sh   12-zsh-profile.sh   15-gh.sh   20-node.sh
    25-python.sh
    30-cli-tools.sh   35-jump.sh   36-ssh-script.sh   40-fonts.sh   50-starship.sh   55-lazygit.sh
    60-copilot-cli.sh   65-pi.sh   70-nvim.sh   80-ghostty.sh
  configs/
    nvim/   starship/   ghostty/   lazygit/   gh/   zsh/

bootstrap.sh               # one-line installer (macOS/Linux): curl … | bash
bootstrap.ps1              # one-line installer (Windows): irm … | iex
tools/                     # shared, self-maintained cross-platform tools
  jump/jump.py             # `j` — autojump-style directory jumper (Python stdlib)
  ssh-script/              # Devbox SSH — server setup, named connections, Windows/WSL helpers
  README.md                # conventions for shared tools; installed by all 3 scaffolders
```

Config files live in `<platform>/configs/` as real files you can diff, edit, and
review in PRs.

## Tools covered

All three platforms install the same core tools. Platform-specific differences noted below.

| # | Tool | Windows (winget/scoop) | macOS (brew) | Linux (apt) | Config deployed |
|---|------|----------------------|--------------|-------------|-----------------|
| 00 | Package manager | winget + scoop | Homebrew | apt + build-essential | — |
| 10 | Git + aliases | `Git.Git` | `git` | `git` | `~/.gitconfig` aliases |
| 15 | GitHub CLI (gh) | `GitHub.cli` | `gh` | apt repo | `config.yml` (no tokens) |
| 20 | Node.js + globals | `OpenJS.NodeJS.LTS` | existing runtime or nvm LTS | existing runtime or nvm LTS | — |
| 25 | Python 3 + packages | `Python.Python.3.12` | `python3` | `python3` | — |
| 30 | rg, fd, fzf, bat, zoxide, cmake | winget | brew | apt + curl | — |
| 35 | `j` directory jumper | our own (Python) | our own (Python) | our own (Python) | `j` shell function |
| 36 | Devbox SSH | our own (Python + PowerShell helpers) | our own (Python) | our own (Python) | Explicit SSH setup with public-key folder discovery; named connections |
| 40 | JetBrainsMono Nerd Font | nerd-fonts zip | brew cask | nerd-fonts zip | — |
| 50 | Starship prompt | `Starship.Starship` | `starship` | curl installer | `~/.config/starship.toml` |
| 55 | Lazygit | scoop `extras/lazygit` | `lazygit` | GitHub release | `config.yml` |
| 60 | GitHub Copilot CLI | `npm i -g @github/copilot` | preserve existing; user-local npm fallback | preserve existing; user-local npm fallback | — |
| 65 | Pi Coding Agent | `npm i -g @earendil-works/pi-coding-agent` | same | same | — |
| 70 | Neovim + plugins | `Neovim.Neovim` | `neovim` | PPA / AppImage | `nvim/` config dir |
| 80 | Terminal | Windows Terminal | Ghostty | Ghostty (optional) | `settings.json` / `config` |
| 90 | Shell profile | PowerShell profile | zsh + Oh My Zsh | zsh + Oh My Zsh | `$PROFILE` / `.zshrc` |

The Pi step also installs `pi-subagents`, `@codewithkenzo/pi-theme-switcher`,
`@milanglacier/pi-plan-mode`, `pi-goal-list-loop-audit`, `@vigolium/piolium`,
`pi-mcp-adapter`, `pi-web-access`, `@juicesharp/rpiv-todo`,
`@ff-labs/pi-fff`, and `pi-ask-user`. Already-installed Pi packages
are skipped on subsequent runs.

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
j copy [path]    # copy a path (default: cwd) to the clipboard
j version        # print the installed version
j update         # self-update to the latest release
j -h             # full help
```

The picker shows a table — path on the left, **jump count** and **date added**
on the right — ordered by pinned → most-jumped → newest. Missing directories are
shown in red. Keys: `↑/↓` move, `enter` jump, `c` copy path, `d` delete,
`p` pin, `u` unpin, `/` search, `q` quit. See [`tools/jump/README.md`](tools/jump/README.md) for
details.

**Upgrades.** The engine carries a `__version__`; re-running any scaffolder
(`./install-all.sh`, including `--only jump`) compares it against the installed
copy and upgrades in place only when they differ. You can also self-update
without the repo via `j update`, which downloads the latest `jump.py` from
GitHub and atomically replaces the installed engine.

## Devbox SSH

`tools/ssh-script/` provides automatic Windows/macOS/Linux/WSL detection,
explicit SSH server setup, named keys, and shortcuts such as `ssh dev1`.
See its [setup and connection quick start](tools/ssh-script/README.md#quick-start).

Install only this tool from the repository root (Python must already be installed):

```sh
bash linux/tools/36-ssh-script.sh  # Linux/WSL; use macos/ on a Mac
```

```powershell
.\windows\tools\36-ssh-script.ps1
```

Full scaffolder runs also copy it automatically, and support `--only ssh-script`
on Unix or `-Only ssh-script` on Windows. These installers are per-user and
version-aware; they do not enable SSH or change firewalls. Run `setup --apply`
on each devbox to enable its server, then `add` on your local device to save
connection names. For one or two local devices connecting to four devboxes,
run `keygen` on each local device and keep its private key there. Copy each
device's public key into `tools/ssh-script/pub-keys/` on every remote devbox
(or `pub-keys/` beside the installed `devbox.py`). This folder is Git-ignored
in the repository. Server setup discovers and authorizes all its `.pub` files;
preview with `setup` before applying. WSL2 NAT connections also need the
supplied Windows forwarding helper, as described in the tool's README.

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

## Notes

- **Idempotent.** Re-running is safe; installers skip packages that are already present.
- **No admin required.** Fonts register per-user; packages install at user scope.
- **Secrets are never committed.** `gh auth` tokens (`hosts.yml`) are deliberately excluded — run `gh auth login` once after install.
- **Existing shell setup is preserved (macOS/Linux).** Zsh defaults live in
  `~/.config/dev-scaffolder/zshrc` and are sourced before the existing `.zshrc`
  (under `$ZDOTDIR` when set), keeping custom PATH and version-manager setup.
  Capture snapshots the managed defaults, not your personal startup file.
  Linux keeps your current login shell; opt into Zsh with `chsh -s "$(command -v zsh)"`.
- **Existing Copilot installs are preserved (macOS/Linux).** A reachable `copilot`
  is left to its current package manager; npm installs missing Copilot into
  `~/.local/bin` using a user-owned prefix independent of nvm versions.
  Missing PATH entries are added to Bash/Zsh startup files for standalone installs.
  Existing Node/npm runtimes and nvm defaults are retained so their global tools stay available.
- **Backups.** Any existing target config is renamed to `<name>.bak.<timestamp>` before a deploy. Neovim's `~/.config/nvim` (macOS/Linux) or `%LOCALAPPDATA%\nvim` (Windows) is backed up the same way.
- **Leader key** in Neovim is `\` (backslash); requires Neovim 0.11+ for the `vim.lsp.config` API.

### Missing Starship icons

Starship installs **JetBrainsMono Nerd Font** automatically on all three
platforms, including `--only starship` / `-Only starship` and direct runs of
`50-starship`. Full installs run the font step once. An explicit
`--skip fonts` / `-Skip fonts` overrides this dependency.

Boxes in place of the OS, Git, Node, or clock icons mean your terminal font
lacks the Nerd Font glyphs. Install the font with `./linux/install-all.sh --only fonts`
or `./macos/install-all.sh --only fonts`, then select **JetBrainsMono Nerd Font**
in your terminal's settings and fully restart the terminal. For a standalone
Starship setup, `--only starship` also installs the font.

For **SSH**, install and select the font on the computer running the terminal;
installing fonts on the remote server cannot change local rendering. For **WSL**,
run `windows/tools/40-fonts.ps1` on Windows, then set the WSL profile's font in
Windows Terminal to **JetBrainsMono Nerd Font**. In VS Code, set
`terminal.integrated.fontFamily` to `JetBrainsMono Nerd Font` on the client.
The bundled Ghostty and Windows Terminal configs already select this family.

## Neovim details

### What's included

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

### Key bindings

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

## Testing

Unix shell setup regression tests use Python's standard library and require Zsh:

```bash
python3 -B -m unittest discover -s tests -v
```

They use temporary homes and stub package operations to verify custom PATH,
profile symlinks, repeated installs, nvm defaults, and Copilot installation sources.

Windows validation includes the following tests.

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
