#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
set -euo pipefail
write_banner "Devbox SSH"

SSH_SOURCE="$(cd "$SCAFFOLDER_ROOT/.." && pwd)/tools/ssh-script"
SSH_DEST="${DEVBOX_SSH_HOME:-$HOME/.local/share/dev-scaffolder/ssh-script}"
SSH_FILES=(README.md setup-windows.ps1 wsl-forward.ps1 devbox.py)

if ! has_command python3; then
  write_warn "python3 not found; run tools/25-python.sh first."
  exit 1
fi
for file in "${SSH_FILES[@]}"; do
  [[ -f "$SSH_SOURCE/$file" ]] || { write_warn "Missing bundled file: $file"; exit 1; }
done
read_ssh_version() {
  [[ -f "$1" ]] || return 0
  sed -n 's/^__version__ = "\([^"]*\)"/\1/p' "$1"
}
SSH_VERSION="$(read_ssh_version "$SSH_SOURCE/devbox.py")"
[[ -n "$SSH_VERSION" ]] || { write_warn "Bundled version is missing."; exit 1; }
SSH_INSTALLED_VERSION="$(read_ssh_version "$SSH_DEST/devbox.py")"
SSH_COMPLETE=true
for file in "${SSH_FILES[@]}"; do
  [[ -f "$SSH_DEST/$file" ]] || SSH_COMPLETE=false
done
if [[ "$SSH_INSTALLED_VERSION" == "$SSH_VERSION" ]] && $SSH_COMPLETE; then
  write_skip "Devbox SSH already at v$SSH_VERSION"
else
  for file in "${SSH_FILES[@]}"; do
    deploy_config "$SSH_SOURCE/$file" "$SSH_DEST/$file"
  done
  write_ok "Devbox SSH installed at v$SSH_VERSION"
fi
write_step "Run: python3 \"$SSH_DEST/devbox.py\" --help"
write_step "SSH server setup remains an explicit 'setup --apply' command."
