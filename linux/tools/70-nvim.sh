#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
write_banner "Neovim + plugins"

if has_command nvim; then
  # Update Neovim
  if [[ "$DISTRO_ID" == "ubuntu" ]]; then
    apt_install neovim "Neovim"
  else
    write_step "Updating Neovim from GitHub release…"
    local_arch="$SCAFFOLDER_ARCH_ALT"
    download "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-${local_arch}.appimage" \
      "$HOME/.local/bin/nvim"
    chmod +x "$HOME/.local/bin/nvim"
    write_ok "Neovim AppImage updated"
  fi
else
  # Use the Neovim PPA for the latest stable version (Ubuntu)
  if [[ "$DISTRO_ID" == "ubuntu" ]]; then
    write_step "Adding Neovim PPA…"
    as_root add-apt-repository -y ppa:neovim-ppa/unstable
    as_root apt-get update -qq
    apt_install neovim "Neovim"
  else
    # Debian / other: install from GitHub release (AppImage)
    write_step "Installing Neovim from GitHub release…"
    local_arch="$SCAFFOLDER_ARCH_ALT"
    download "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-${local_arch}.appimage" \
      "$HOME/.local/bin/nvim"
    chmod +x "$HOME/.local/bin/nvim"
    write_ok "Neovim AppImage installed"
  fi
fi

# Deploy config
src_dir="$SCAFFOLDER_ROOT/configs/nvim"
nvim_dir="$HOME/.config/nvim"

write_step "Deploying Neovim config to $nvim_dir …"
if [[ -d "$nvim_dir" ]]; then backup_path "$nvim_dir" || true; fi
cp -R "$src_dir" "$nvim_dir"
write_ok "Config deployed"

# Plugin bootstrap via lazy.nvim (headless)
if has_command nvim; then
  write_step "Syncing plugins (lazy.nvim headless)…"
  nvim --headless "+Lazy! sync" +qa 2>/dev/null || true
  write_ok "Plugins synced"
else
  write_warn "nvim not on PATH yet; restart your shell and run ':Lazy sync' inside nvim."
fi
