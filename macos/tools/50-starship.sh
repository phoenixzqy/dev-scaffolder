#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
write_banner "Starship Prompt"

# Standalone runs need the font too; the orchestrator owns dependency selection.
if [[ "${DEV_SCAFFOLDER_FONTS_HANDLED:-0}" != "1" ]]; then
  bash "$SCAFFOLDER_ROOT/tools/40-fonts.sh"
fi
brew_install starship "Starship"

deploy_config "$SCAFFOLDER_ROOT/configs/starship/starship.toml" "$HOME/.config/starship.toml"

# Wire `starship init zsh` into ~/.zshrc when it isn't already there. The
# deployed configs/zsh/.zshrc includes it, so this only matters for
# `--only starship` runs against a hand-maintained rc file.
rc="${ZDOTDIR:-$HOME}/.zshrc"
mkdir -p "$(dirname "$rc")"
[[ -e "$rc" ]] || touch "$rc"
if grep -qF "starship init zsh" "$rc" 2>/dev/null; then
  write_skip "starship init in $rc"
else
  {
    echo ""
    echo "# >>> dev-scaffolder starship >>>"
    echo 'if command -v starship &>/dev/null; then'
    echo '  eval "$(starship init zsh)"'
    echo 'fi'
    echo "# <<< dev-scaffolder starship <<<"
  } >> "$rc"
  write_ok "Wired starship into $rc"
fi

# Glyph rendering happens in the terminal client, not in Starship or SSH.
write_warn "Starship icons require a Nerd Font. Select 'JetBrainsMono Nerd Font' in your terminal's font settings and restart the terminal."
write_warn "The font step installs locally. For remote sessions, install the font on the computer running your terminal. For SSH/WSL, install and select the font on the client/Windows host."
