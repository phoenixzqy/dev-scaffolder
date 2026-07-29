#!/usr/bin/env bash
# Shared helpers for the macOS scaffolder. Source from every tools/*.sh script.
set -euo pipefail

# Resolve repo root regardless of where we were invoked from.
SCAFFOLDER_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ── Output helpers ─────────────────────────────────────────────────────────
write_banner() {
  local title="$1"
  echo ""
  printf '\033[35m╔══════════════════════════════════════════════════════════╗\033[0m\n'
  printf '\033[35m║  %-56s║\033[0m\n' "$title"
  printf '\033[35m╚══════════════════════════════════════════════════════════╝\033[0m\n'
}

write_step() { printf '\033[36m▸ %s\033[0m\n' "$1"; }
write_ok()   { printf '\033[32m  ✓ %s\033[0m\n' "$1"; }
write_skip() { printf '\033[90m  • %s (already present)\033[0m\n' "$1"; }
write_warn() { printf '\033[33m  ⚠ %s\033[0m\n' "$1"; }

# ── Homebrew helpers ───────────────────────────────────────────────────────
ensure_brew() {
  if command -v brew &>/dev/null; then return; fi
  write_step "Installing Homebrew…"
  local tmp
  tmp="$(mktemp)"
  curl -fsSL -o "$tmp" https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh
  /bin/bash "$tmp"
  rm -f "$tmp"
  # Add brew to PATH for Apple Silicon
  if [[ -f /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
  write_ok "Homebrew installed"
}

# Install or upgrade a brew formula.
brew_install() {
  local pkg="$1"
  local display="${2:-$pkg}"
  if brew list --formula "$pkg" &>/dev/null; then
    write_step "Updating $display via brew…"
    brew upgrade "$pkg" 2>/dev/null && write_ok "Updated $display" || write_ok "$display is up to date"
  else
    write_step "Installing $display via brew…"
    brew install "$pkg"
    write_ok "Installed $display"
  fi
}

# Install or upgrade a brew cask.
brew_cask_install() {
  local cask="$1"
  local display="${2:-$cask}"
  if brew list --cask "$cask" &>/dev/null; then
    write_step "Updating $display via brew cask…"
    brew upgrade --cask "$cask" 2>/dev/null && write_ok "Updated $display" || write_ok "$display is up to date"
  else
    write_step "Installing $display via brew cask…"
    brew install --cask "$cask"
    write_ok "Installed $display"
  fi
}

# ── Config deployment ──────────────────────────────────────────────────────
# Back up an existing file/dir, returning the backup path.
backup_path() {
  local target="$1"
  if [[ ! -e "$target" ]]; then return 1; fi
  local stamp
  stamp="$(date +%Y%m%d-%H%M%S)"
  local backup="${target}.bak.${stamp}"
  mv "$target" "$backup"
  write_warn "Backed up existing $target → $backup"
}

# True when src and dst already have identical content.
same_content() {
  local src="$1" dst="$2"
  [[ -e "$dst" ]] || return 1
  if [[ -d "$src" ]]; then
    [[ -d "$dst" ]] || return 1
    diff -rq "$src" "$dst" &>/dev/null
  else
    [[ -f "$dst" ]] || return 1
    cmp -s "$src" "$dst"
  fi
}

# Deploy a config file/dir from configs/ to a target location.
deploy_config() {
  local src="$1"
  local dst="$2"
  if [[ ! -e "$src" ]]; then
    echo "ERROR: Source config not found: $src" >&2
    return 1
  fi
  if same_content "$src" "$dst"; then
    write_skip "$dst"
    return
  fi
  mkdir -p "$(dirname "$dst")"
  if [[ -e "$dst" ]]; then backup_path "$dst" || true; fi
  if [[ -d "$src" ]]; then
    cp -R "$src" "$dst"
  else
    cp "$src" "$dst"
  fi
  write_ok "Deployed $dst"
}

# Check if a command exists.
has_command() { command -v "$1" &>/dev/null; }

# Load nvm into the current shell session.
load_nvm() {
  export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
  if [[ -s "$NVM_DIR/nvm.sh" ]]; then
    \. "$NVM_DIR/nvm.sh"
  fi
}
