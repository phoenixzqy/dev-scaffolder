#!/usr/bin/env bash
# Shared helpers for the Linux scaffolder. Source from every tools/*.sh script.
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

# ── Distro detection ──────────────────────────────────────────────────────
detect_distro() {
  if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    DISTRO_ID="${ID:-unknown}"
    DISTRO_VERSION="${VERSION_ID:-unknown}"
    DISTRO_CODENAME="${VERSION_CODENAME:-unknown}"
  else
    DISTRO_ID="unknown"
    DISTRO_VERSION="unknown"
    DISTRO_CODENAME="unknown"
  fi
  export DISTRO_ID DISTRO_VERSION DISTRO_CODENAME
}
detect_distro

# ── Architecture detection ────────────────────────────────────────────────
detect_arch() {
  local machine
  machine="$(uname -m)"
  case "$machine" in
    x86_64)  ARCH="amd64"; ARCH_ALT="x86_64" ;;
    aarch64) ARCH="arm64";  ARCH_ALT="aarch64" ;;
    *)       ARCH="$machine"; ARCH_ALT="$machine" ;;
  esac
  export ARCH ARCH_ALT
}
detect_arch

# ── Sudo helper ───────────────────────────────────────────────────────────
# Preflight: cache sudo credentials once. Fail early if unavailable.
ensure_sudo() {
  if [[ $EUID -eq 0 ]]; then return; fi
  if ! sudo -v 2>/dev/null; then
    echo "ERROR: sudo is required for apt operations. Run as a user with sudo access." >&2
    exit 1
  fi
}

as_root() {
  if [[ $EUID -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

# ── APT helpers ───────────────────────────────────────────────────────────
# Install or upgrade an apt package.
apt_install() {
  local pkg="$1"
  local display="${2:-$pkg}"
  if dpkg -s "$pkg" &>/dev/null; then
    write_step "Updating $display via apt…"
    as_root apt-get install -y -qq "$pkg" 2>/dev/null
    write_ok "$display is up to date"
  else
    write_step "Installing $display via apt…"
    as_root apt-get install -y -qq "$pkg"
    write_ok "Installed $display"
  fi
}

# Add a signed apt repository (modern /etc/apt/keyrings approach).
add_apt_repo() {
  local name="$1"       # short name (e.g., "github-cli")
  local keyring="$2"    # URL to GPG key
  local repo_line="$3"  # full deb line with signed-by placeholder

  local keyring_dir="/etc/apt/keyrings"
  local keyring_file="$keyring_dir/${name}.gpg"
  local list_file="/etc/apt/sources.list.d/${name}.list"

  if [[ -f "$list_file" ]]; then
    write_skip "apt repo: $name"
    return
  fi

  write_step "Adding apt repository: ${name}…"
  as_root mkdir -p "$keyring_dir"
  curl -fsSL "$keyring" | as_root gpg --dearmor -o "$keyring_file"
  echo "$repo_line" | as_root tee "$list_file" > /dev/null
  as_root apt-get update -qq
  write_ok "Added apt repo: $name"
}

# ── Config deployment ──────────────────────────────────────────────────────
backup_path() {
  local target="$1"
  if [[ ! -e "$target" ]]; then return 1; fi
  local stamp
  stamp="$(date +%Y%m%d-%H%M%S)"
  local backup="${target}.bak.${stamp}"
  mv "$target" "$backup"
  write_warn "Backed up existing $target → $backup"
  echo "$backup"
}

deploy_config() {
  local src="$1"
  local dst="$2"
  if [[ ! -e "$src" ]]; then
    echo "ERROR: Source config not found: $src" >&2
    return 1
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

# Ensure ~/.local/bin is on PATH (for user-level installs).
ensure_local_bin() {
  mkdir -p "$HOME/.local/bin"
  if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    export PATH="$HOME/.local/bin:$PATH"
  fi
}
ensure_local_bin

# Download a file from a URL to a destination.
download() {
  local url="$1"
  local dst="$2"
  if ! curl -fsSL -o "$dst" "$url"; then
    echo "ERROR: Failed to download $url" >&2
    return 1
  fi
}

# Download a remote script, then execute it (safer than piping curl to bash).
run_remote_script() {
  local url="$1"; shift
  local tmp
  tmp="$(mktemp)"
  if ! curl -fsSL -o "$tmp" "$url"; then
    rm -f "$tmp"
    echo "ERROR: Failed to download installer from $url" >&2
    return 1
  fi
  bash "$tmp" "$@"
  local rc=$?
  rm -f "$tmp"
  return $rc
}

# Install from GitHub release tarball/binary.
github_release_install() {
  local repo="$1"    # e.g., "jesseduffield/lazygit"
  local version="$2" # e.g., "0.44.1" (no leading v)
  local asset="$3"   # asset filename pattern (already arch-resolved)
  local binary="$4"  # expected binary name
  local dst="$HOME/.local/bin/$binary"

  if [[ -f "$dst" ]]; then
    write_step "Updating $binary from GitHub…"
  else
    write_step "Downloading $binary v$version from GitHub…"
  fi

  local url="https://github.com/$repo/releases/download/v${version}/${asset}"
  local tmp
  tmp="$(mktemp -d)"

  if ! download "$url" "$tmp/$asset"; then
    rm -rf "$tmp"
    return 1
  fi

  case "$asset" in
    *.tar.gz)
      tar -xzf "$tmp/$asset" -C "$tmp"
      ;;
    *.zip)
      unzip -o "$tmp/$asset" -d "$tmp" > /dev/null
      ;;
    *)
      cp "$tmp/$asset" "$dst"
      chmod +x "$dst"
      rm -rf "$tmp"
      write_ok "Installed $binary to $dst"
      return
      ;;
  esac

  # Find the binary — may be at root or in a subdirectory
  local binary_path
  binary_path="$(find "$tmp" -name "$binary" -type f | head -n1)"
  if [[ -z "$binary_path" ]]; then
    echo "ERROR: Binary '$binary' not found in downloaded archive" >&2
    rm -rf "$tmp"
    return 1
  fi

  cp "$binary_path" "$dst"
  chmod +x "$dst"
  rm -rf "$tmp"
  write_ok "Installed $binary to $dst"
}
