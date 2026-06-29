#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
write_banner "j (jump) — directory jumper"

# Shared, cross-platform tools live at the repo root in /tools.
REPO_ROOT="$(cd "$SCAFFOLDER_ROOT/.." && pwd)"
SRC="$REPO_ROOT/tools/jump/jump.py"
JUMP_HOME="$HOME/.local/share/dev-scaffolder/jump"
JUMP_MARKER="# >>> dev-scaffolder jump (j) >>>"

if [[ ! -f "$SRC" ]]; then
  write_warn "jump.py not found at $SRC — skipping."
  exit 1
fi

if ! has_command python3; then
  write_warn "python3 not found — run tools/25-python.sh first."
  exit 1
fi

# 1. Install the engine — version-aware so re-running upgrades in place.
read_jump_version() {
  # Prints the __version__ string from a jump.py file, or nothing.
  [[ -f "$1" ]] || return 0
  sed -n 's/^__version__[[:space:]]*=[[:space:]]*["'"'"']\([^"'"'"']*\)["'"'"'].*/\1/p' "$1" | head -n1
}

SRC_VER="$(read_jump_version "$SRC")"
DEST_VER="$(read_jump_version "$JUMP_HOME/jump.py")"
mkdir -p "$JUMP_HOME"
if [[ -n "$DEST_VER" && "$DEST_VER" == "$SRC_VER" ]]; then
  write_skip "j already at v$DEST_VER"
else
  if [[ -n "$DEST_VER" ]]; then
    write_step "Upgrading j v$DEST_VER -> v${SRC_VER}…"
  else
    write_step "Installing j v$SRC_VER to ${JUMP_HOME}…"
  fi
  cp "$SRC" "$JUMP_HOME/jump.py"
  chmod +x "$JUMP_HOME/jump.py"
  write_ok "j engine at v$SRC_VER (DB lives in $JUMP_HOME)"
fi

# 2. Write the shell integration — the `j` function lives here, so the tool is
#    self-contained and does not depend on the zsh-profile config being deployed.
cat > "$JUMP_HOME/init.zsh" <<'JINIT'
# dev-scaffolder jump (j) — shell integration (sourced from your shell rc).
# `cd` must run in this shell, so `j` is a function: bare `j` opens a picker
# and we cd into whatever path it prints; anything else is forwarded as-is.
export JUMP_HOME="$HOME/.local/share/dev-scaffolder/jump"
j() {
  if [ "$#" -eq 0 ]; then
    local __jump_target
    __jump_target="$(command python3 "$JUMP_HOME/jump.py" select)" || return
    [ -n "$__jump_target" ] && cd "$__jump_target"
  else
    command python3 "$JUMP_HOME/jump.py" "$@"
  fi
}
JINIT
write_ok "Shell integration written to $JUMP_HOME/init.zsh"

# 3. Ensure the user's ~/.zshrc sources it — idempotent, marker-guarded.
RC="$HOME/.zshrc"
[[ -e "$RC" ]] || touch "$RC"
if grep -qF "$JUMP_MARKER" "$RC" 2>/dev/null; then
  write_skip "j shell integration in $RC"
else
  {
    echo ""
    echo "$JUMP_MARKER"
    echo '[ -f "$HOME/.local/share/dev-scaffolder/jump/init.zsh" ] && source "$HOME/.local/share/dev-scaffolder/jump/init.zsh"'
    echo "# <<< dev-scaffolder jump (j) <<<"
  } >> "$RC"
  write_ok "Wired j into $RC"
fi

write_warn "Restart your shell (or 'source ~/.zshrc') to start using 'j'."
write_warn "Then: 'j add' to save a dir, 'j' to jump, 'j -h' for help."
