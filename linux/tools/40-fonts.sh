#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
write_banner "JetBrainsMono Nerd Font"

# Minimal Ubuntu installations may not include either utility.
if ! has_command unzip; then apt_install unzip "unzip"; fi
if ! has_command fc-cache; then apt_install fontconfig "Fontconfig"; fi

FONT_DIR="$HOME/.local/share/fonts/JetBrainsMonoNF"

if [[ -d "$FONT_DIR" ]] && ls "$FONT_DIR"/*.ttf &>/dev/null; then
  write_skip "JetBrainsMono Nerd Font"
  write_warn "Select JetBrainsMono Nerd Font in your terminal settings; SSH/WSL fonts must also be installed on the terminal client."
  exit 0
fi

FONT_VERSION="3.3.0"
FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/v${FONT_VERSION}/JetBrainsMono.zip"

write_step "Downloading JetBrainsMono Nerd Font v${FONT_VERSION}…"
tmp="$(mktemp -d)"
if ! download "$FONT_URL" "$tmp/JetBrainsMono.zip"; then
  rm -rf "$tmp"
  write_warn "Failed to download font"
  exit 1
fi

mkdir -p "$FONT_DIR"
unzip -o "$tmp/JetBrainsMono.zip" -d "$FONT_DIR" > /dev/null
rm -rf "$tmp"

# Refresh font cache
write_step "Refreshing font cache…"
fc-cache -f "$HOME/.local/share/fonts"
write_ok "JetBrainsMono Nerd Font installed"

write_warn "Select JetBrainsMono Nerd Font in your terminal settings; SSH/WSL fonts must also be installed on the terminal client."
