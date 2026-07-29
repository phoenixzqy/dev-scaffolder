#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
write_banner "Starship Prompt"

STARSHIP_MARKER="# >>> dev-scaffolder starship >>>"

install_starship() {
  write_step "Installing/updating Starship via official installer…"
  local tmp log
  tmp="$(mktemp)"
  log="$(mktemp)"
  if ! curl -fsSL -o "$tmp" https://starship.rs/install.sh; then
    rm -f "$tmp" "$log"
    write_warn "Failed to download Starship installer"
    exit 1
  fi
  # Clear ARCH/PLATFORM/BIN_DIR from the environment: the official installer
  # honours them verbatim and skips its own detection, which yields bogus
  # targets like "amd64-unknown-linux-musl".
  if ! env -u ARCH -u PLATFORM -u BIN_DIR sh "$tmp" --yes --bin-dir "$HOME/.local/bin" > "$log" 2>&1; then
    cat "$log" >&2
    rm -f "$tmp" "$log"
    write_warn "Starship installer failed"
    exit 1
  fi
  rm -f "$tmp" "$log"
  write_ok "Starship up to date"
}

# Wire `starship init zsh` into ~/.zshrc when it isn't already there. The
# deployed configs/zsh/.zshrc includes it, so this only matters for
# `--only starship` runs against a hand-maintained rc file.
wire_zshrc() {
  local rc="$HOME/.zshrc"
  [[ -e "$rc" ]] || touch "$rc"
  if grep -qF "starship init zsh" "$rc" 2>/dev/null; then
    write_skip "starship init in $rc"
    return
  fi
  {
    echo ""
    echo "$STARSHIP_MARKER"
    echo 'if command -v starship &>/dev/null; then'
    echo '  eval "$(starship init zsh)"'
    echo 'fi'
    echo "# <<< dev-scaffolder starship <<<"
  } >> "$rc"
  write_ok "Wired starship into $rc"
}

install_starship
ensure_local_bin

deploy_config "$SCAFFOLDER_ROOT/configs/starship/starship.toml" "$HOME/.config/starship.toml"
wire_zshrc
