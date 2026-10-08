#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
write_banner "JetBrainsMono Nerd Font"
brew_cask_install font-jetbrains-mono-nerd-font "JetBrainsMono Nerd Font"

write_warn "Select JetBrainsMono Nerd Font in your terminal settings; SSH fonts must also be installed on the terminal client."
