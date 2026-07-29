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

# Deploy .zshrc
deploy_config "$SCAFFOLDER_ROOT/configs/zsh/.zshrc" "$HOME/.zshrc"

# Make zsh the default login shell (unattended).
set_default_shell_zsh() {
  local zsh_path
  zsh_path="$(command -v zsh)"
  local login_shell
  login_shell="$(getent passwd "$USER" 2>/dev/null | cut -d: -f7)"
  login_shell="${login_shell:-$SHELL}"

  if [[ "$login_shell" == "$zsh_path" ]]; then
    write_skip "zsh is the default shell"
    return
  fi

  # zsh must be listed in /etc/shells or chsh refuses it.
  if ! grep -qxF "$zsh_path" /etc/shells 2>/dev/null; then
    echo "$zsh_path" | as_root tee -a /etc/shells > /dev/null
  fi

  write_step "Changing default shell to zsh…"
  # Interactive chsh prompts for a password; run it through sudo (already
  # cached by the orchestrator) so a full install stays unattended.
  if as_root chsh -s "$zsh_path" "$USER" 2>/dev/null; then
    write_ok "Default shell set to zsh (takes effect on next login)"
  else
    write_warn "Could not change shell automatically. Run: chsh -s $zsh_path"
  fi
}
ensure_sudo
set_default_shell_zsh

write_warn "Restart your shell (or run 'source ~/.zshrc') to activate."
