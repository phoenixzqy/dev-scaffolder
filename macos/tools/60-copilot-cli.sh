#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
write_banner "GitHub Copilot CLI"

# Respect native, Homebrew, npm, and other installations before nvm can
# change command resolution. Updates belong to the existing package manager.
if has_command copilot; then
  write_skip "Copilot CLI ($(command -v copilot))"
  exit 0
fi

load_nvm
if has_command copilot; then
  write_skip "Copilot CLI ($(command -v copilot))"
  exit 0
fi
if ! has_command npm; then
  write_warn "npm not found — run tools/20-node.sh first."
  exit 1
fi

# Use a stable user-owned prefix: system Node prefixes may need root, and
# version-specific nvm prefixes hide global CLIs when the runtime changes.
mkdir -p "$HOME/.local/bin"
write_step "Installing @github/copilot via npm (user-local prefix)…"
npm install -g --prefix "$HOME/.local" "@github/copilot" --silent
write_ok "Copilot CLI installed ($HOME/.local/bin/copilot)"
source "$SCAFFOLDER_ROOT/../lib/shell-profile.sh"
wire_local_bin
write_warn "Restart your shell to activate the user-local PATH entry."

write_warn "Run 'copilot' and follow the auth prompt on first launch."
