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

plugins=(
  "npm:pi-subagents"
  "npm:@codewithkenzo/pi-theme-switcher"
  "npm:@milanglacier/pi-plan-mode"
  "npm:pi-goal-list-loop-audit"
  "npm:@vigolium/piolium"
  "npm:pi-mcp-adapter"
  "npm:pi-web-access"
)

installed_plugins="$(pi list)"
for plugin in "${plugins[@]}"; do
  plugin_name="${plugin#npm:}"
  if grep -Fq -- "$plugin_name" <<< "$installed_plugins"; then
    write_skip "$plugin_name already present"
  else
    write_step "Installing $plugin…"
    pi install "$plugin"
    write_ok "Installed $plugin"
  fi
done

write_warn "Run 'pi', then use '/login' to authenticate."
