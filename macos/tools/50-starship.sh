#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
write_banner "Starship Prompt"
brew_install starship "Starship"

deploy_config "$SCAFFOLDER_ROOT/configs/starship/starship.toml" "$HOME/.config/starship.toml"

# Wire `starship init zsh` into ~/.zshrc when it isn't already there. The
# deployed configs/zsh/.zshrc includes it, so this only matters for
# `--only starship` runs against a hand-maintained rc file.
rc="$HOME/.zshrc"
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
