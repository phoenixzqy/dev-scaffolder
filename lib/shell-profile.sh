#!/usr/bin/env bash
# Shared non-destructive shell profile integration (requires platform common.sh).

# Keep user initialization after our defaults so custom PATH and version-manager
# setup still take effect. Store the managed file outside the bootstrap checkout.
deploy_zsh_profile() {
  local src="$SCAFFOLDER_ROOT/configs/zsh/.zshrc"
  local dst="${ZDOTDIR:-$HOME}/.zshrc"
  local managed="$HOME/.config/dev-scaffolder/zshrc"
  local marker='# >>> dev-scaffolder zsh >>>'

  deploy_config "$src" "$managed"
  if [[ -f "$dst" ]] && grep -qxF "$marker" "$dst"; then
    write_skip "Zsh profile integration"
    return
  fi

  mkdir -p "$(dirname "$dst")"
  # A symlink may belong to a dotfile manager. Write through it rather than
  # replacing it; users' startup commands and their ordering remain intact.
  local original=""
  if [[ -e "$dst" ]]; then
    original="$dst.bak.$(date +%Y%m%d-%H%M%S)"
    cp -p "$dst" "$original"
  fi
  {
    printf '%s\n' "$marker"
    printf '%s\n' '[ -f "$HOME/.config/dev-scaffolder/zshrc" ] && source "$HOME/.config/dev-scaffolder/zshrc"'
    printf '%s\n\n' '# <<< dev-scaffolder zsh <<<'
    if [[ -n "$original" ]]; then cat "$original"; fi
  } > "$dst"
  write_ok "Integrated Zsh defaults; preserved existing $dst"
}

# Persist the user-owned prefix for standalone installs and Linux users who
# retain Bash. Append only an additive, guarded PATH entry to existing files.
wire_local_bin() {
  local rc login_rc
  local marker='# >>> dev-scaffolder local bin >>>'
  local -a startup_files
  case "${SHELL:-}" in
    */zsh|zsh) startup_files=("${ZDOTDIR:-$HOME}/.zshrc") ;;
    */bash|bash)
      startup_files=("$HOME/.bashrc")
      if [[ -f "$HOME/.bash_profile" ]]; then
        login_rc="$HOME/.bash_profile"
      elif [[ -f "$HOME/.bash_login" ]]; then
        login_rc="$HOME/.bash_login"
      else
        login_rc="$HOME/.profile"
      fi
      startup_files+=("$login_rc")
      ;;
    *)
      write_warn 'Add $HOME/.local/bin to your shell PATH to run Copilot.'
      return
      ;;
  esac
  for rc in "${startup_files[@]}"; do
    mkdir -p "$(dirname "$rc")"
    if [[ -f "$rc" ]] && grep -qxF "$marker" "$rc"; then continue; fi
    {
      printf '\n%s\n' "$marker"
      printf '%s\n' 'case ":$PATH:" in'
      printf '%s\n' '  *":$HOME/.local/bin:"*) ;;'
      printf '%s\n' '  *) export PATH="$HOME/.local/bin:$PATH" ;;'
      printf '%s\n' 'esac' '# <<< dev-scaffolder local bin <<<'
    } >> "$rc"
    write_ok "Added user-local PATH entry to $rc"
  done
}
