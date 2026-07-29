#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
write_banner "Starship Prompt"

install_starship() {
  write_step "Installing/updating Starship via official installer…"
  local tmp
  tmp="$(mktemp)"
  if ! curl -sS -o "$tmp" https://starship.rs/install.sh; then
    rm -f "$tmp"
    write_warn "Failed to download Starship installer"
    exit 1
  fi
  # Clear ARCH/PLATFORM/BIN_DIR from the environment: the official installer
  # honours them verbatim and skips its own detection, which yields bogus
  # targets like "amd64-unknown-linux-musl".
  if ! env -u ARCH -u PLATFORM -u BIN_DIR sh "$tmp" --yes --bin-dir "$HOME/.local/bin"; then
    rm -f "$tmp"
    write_warn "Starship installer failed"
    exit 1
  fi
  rm -f "$tmp"
  write_ok "Starship up to date"
}

install_starship

deploy_config "$SCAFFOLDER_ROOT/configs/starship/starship.toml" "$HOME/.config/starship.toml"

write_warn "Ensure your .zshrc contains: eval \"\$(starship init zsh)\""
write_warn "(The tools/90-zsh-profile.sh script handles this automatically.)"
