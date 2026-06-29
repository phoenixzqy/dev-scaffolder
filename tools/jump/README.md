# j — directory jumper

A very simplified, self-maintained version of
[autojump](https://github.com/wting/autojump). One global command, `j`, lets you
save directories and jump back into them through a small terminal UI. Pure Python
standard library, so it runs the same on Windows, macOS and Linux.

## Usage

```text
j add            # save the current directory to the DB
j                # open the picker and cd into the chosen directory
j list           # print saved paths (pinned first, then newest)
j rm <path>      # remove a path
j pin <path>     # pin a path to the top
j unpin <path>   # unpin a path
j version        # print the installed version
j update         # self-update to the latest release
```

### The picker (`j` with no arguments)

A full-width, numbered table of saved paths is shown under a column header
(`#`, `Path`, `Count`, `Date / Time`). Each row lists the **path** (aligned to
the left) and, in fixed-width columns flushed to the right edge, its **jump
count** and the **date it was added** — e.g. `12×   2026-06-29 18:09`. Entries
are ordered:

1. **pinned** entries first, then
2. by **jump count** (most-jumped first), then
3. by **date added** (newest first).

Directories that no longer exist on disk are auto-detected and shown in **red**.
Navigate and act with:

| Key | Action |
|-----|--------|
| ↑ / ↓ (or `k` / `j`) | move the selection |
| `enter` | jump into the selected directory (and bump its jump count) |
| `d` | delete the selected entry from the DB |
| `p` | pin the selected entry to the top |
| `u` | unpin the selected entry |
| `/` | open a Vim-style search box; type to filter live |
| `q` / `esc` | quit without jumping |

All available actions are always shown in a full-width footer pinned to the
bottom of the screen.

## How it works

`cd` cannot be performed by a child process on behalf of its parent shell, so `j`
is a **shell function** (installed into your shell profile by the scaffolders).
Running bare `j` calls `jump.py select`, which renders the TUI to the terminal
and prints the chosen path to stdout; the shell function then `cd`s into it. Any
other arguments are forwarded straight to `jump.py`.

## Storage

State is a single JSON file, `db.json`, kept **next to the installed `jump.py`**
(the tool's install location):

- Unix: `~/.local/share/dev-scaffolder/jump/db.json`
- Windows: `%LOCALAPPDATA%\dev-scaffolder\jump\db.json`

Override the location with the `JUMP_HOME` environment variable.

## Installation

Installed automatically by every scaffolder:

- `linux/tools/35-jump.sh`
- `macos/tools/35-jump.sh`
- `windows/tools/35-jump.ps1`

Each installer is **self-contained**: it copies `jump.py` to the install
location, writes a small shell-integration file there (`init.zsh` on Unix,
`init.ps1` on Windows) that defines the `j` function, and idempotently wires a
marker-guarded `source`/dot-source line into your shell rc (`~/.zshrc` on Unix,
the PowerShell profile on Windows). Restart your shell (or `source ~/.zshrc`)
afterwards. Re-running an installer is a no-op.

## Versioning & upgrades

`jump.py` carries a `__version__` string (the tool's single source of truth for
its version). There are two ways to upgrade:

- **Via the scaffolders.** Re-running any scaffolder reads the `__version__` of
  the bundled `jump.py` and compares it with the installed copy. It upgrades in
  place only when they differ, and reports `already at vX` otherwise — so the
  step stays idempotent.
- **Self-update with `j update`.** Without needing the repo checked out, `j
  update` downloads the latest `jump.py` from GitHub
  (`tools/jump/jump.py` on `main`), validates that it compiles, compares
  versions, and atomically replaces the installed engine. Point it at a fork or
  branch by setting the `JUMP_UPDATE_URL` environment variable to a raw
  `jump.py` URL.

Check the installed version any time with `j version` (or `j --version`).
