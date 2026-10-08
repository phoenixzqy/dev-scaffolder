#!/usr/bin/env bash
# ============================================================================
# capture.sh — Re-snapshot live configs from the current machine into configs/
# Run this whenever you tweak a tool's settings and want the scaffolder to
# pick up the change. Commit the resulting diff.
# ============================================================================
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
write_banner "Capturing live configs → configs/"

snap() {
  local src="$1" dst="$2"
  if [[ ! -e "$src" ]]; then
    write_warn "missing: $src"
    return
  fi
  mkdir -p "$(dirname "$dst")"
  if [[ -d "$src" ]]; then
    cp -R "$src" "$dst"
  else
    cp "$src" "$dst"
  fi
  write_ok "$src → $dst"
}

snap "$HOME/.config/starship.toml"               "$SCAFFOLDER_ROOT/configs/starship/starship.toml"
snap "$HOME/.config/ghostty/config"               "$SCAFFOLDER_ROOT/configs/ghostty/config"
snap "$HOME/.config/lazygit/config.yml"           "$SCAFFOLDER_ROOT/configs/lazygit/config.yml"
snap "$HOME/.config/gh/config.yml"                "$SCAFFOLDER_ROOT/configs/gh/config.yml"
snap "$HOME/.config/dev-scaffolder/zshrc"  "$SCAFFOLDER_ROOT/configs/zsh/.zshrc"

# nvim
nvim_dir="$HOME/.config/nvim"
if [[ -d "$nvim_dir" ]]; then
  rm -rf "$SCAFFOLDER_ROOT/configs/nvim"
  mkdir -p "$SCAFFOLDER_ROOT/configs/nvim"
  cp "$nvim_dir/init.lua" "$SCAFFOLDER_ROOT/configs/nvim/init.lua" 2>/dev/null || true
  if [[ -d "$nvim_dir/lua" ]]; then
    cp -R "$nvim_dir/lua" "$SCAFFOLDER_ROOT/configs/nvim/lua"
  fi
  write_ok "nvim config snapshotted"
fi

echo ""
write_ok "Done. Review 'git diff' in $SCAFFOLDER_ROOT and commit."
