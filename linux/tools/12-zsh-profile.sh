#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
write_banner "Zsh + Oh My Zsh"

# Install/update zsh
apt_install zsh "Zsh"

# Install or update Oh My Zsh
if [[ -d "$HOME/.oh-my-zsh" ]]; then
  write_step "Updating Oh My Zsh…"
  git -C "$HOME/.oh-my-zsh" pull --rebase --quiet 2>/dev/null && write_ok "Oh My Zsh updated" || write_ok "Oh My Zsh is up to date"
else
  write_step "Installing Oh My Zsh…"
  tmp_omz="$(mktemp)"
  if ! curl -fsSL -o "$tmp_omz" https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh; then
    rm -f "$tmp_omz"
    write_warn "Failed to download Oh My Zsh installer"
    exit 1
  fi
  RUNZSH=no KEEP_ZSHRC=yes sh "$tmp_omz" --unattended
  rm -f "$tmp_omz"
  write_ok "Oh My Zsh installed"
fi

# Install or update popular plugins
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

if [[ -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]]; then
  write_step "Updating zsh-autosuggestions…"
  git -C "$ZSH_CUSTOM/plugins/zsh-autosuggestions" pull --rebase --quiet 2>/dev/null \
    && write_ok "zsh-autosuggestions updated" || write_ok "zsh-autosuggestions is up to date"
else
  write_step "Installing zsh-autosuggestions…"
  git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
  write_ok "zsh-autosuggestions installed"
fi

if [[ -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]]; then
  write_step "Updating zsh-syntax-highlighting…"
  git -C "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" pull --rebase --quiet 2>/dev/null \
    && write_ok "zsh-syntax-highlighting updated" || write_ok "zsh-syntax-highlighting is up to date"
else
  write_step "Installing zsh-syntax-highlighting…"
  git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
  write_ok "zsh-syntax-highlighting installed"
fi

# Integrate defaults without replacing user PATH/version-manager setup.
source "$SCAFFOLDER_ROOT/../lib/shell-profile.sh"
deploy_zsh_profile

# Keep the current login shell: Bash-only startup configuration may provide
# existing CLI tools. Changing shells must be an explicit user choice.
write_warn "To opt into zsh as your login shell, run: chsh -s $(command -v zsh)"

write_warn "Restart zsh (or run 'source ${ZDOTDIR:-$HOME}/.zshrc' from zsh) to activate."
