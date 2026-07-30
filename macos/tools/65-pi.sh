#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
write_banner "Pi Coding Agent"

load_nvm
if ! has_command npm; then
  write_warn "npm not found — run tools/20-node.sh first."
  exit 1
fi

package="@earendil-works/pi-coding-agent"
if npm ls -g --depth=0 2>/dev/null | grep -q "$package@"; then
  write_skip "Pi already present"
else
  write_step "Installing $package via npm…"
  npm install -g --ignore-scripts "$package" --silent
  write_ok "Pi installed (command: pi)"
fi

write_warn "Run 'pi', then use '/login' to authenticate."
