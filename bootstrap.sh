#!/usr/bin/env bash
# ============================================================================
# dev-scaffolder — one-line bootstrap (macOS / Linux)
#
#   curl -fsSL https://raw.githubusercontent.com/phoenixzqy/dev-scaffolder/main/bootstrap.sh | bash
#
# Pass arguments through to the platform installer after `-s --`, e.g.:
#   curl -fsSL .../bootstrap.sh | bash -s -- --only jump
#   curl -fsSL .../bootstrap.sh | bash -s -- --dry-run
#
# Overridable via environment variables:
#   DEV_SCAFFOLDER_REPO   owner/name or full git URL   (default: phoenixzqy/dev-scaffolder)
#   DEV_SCAFFOLDER_REF    branch / tag / commit         (default: main)
#   DEV_SCAFFOLDER_DEST   clone destination             (default: ~/workspace/dev-scaffolder)
# ============================================================================
set -euo pipefail

REPO="${DEV_SCAFFOLDER_REPO:-phoenixzqy/dev-scaffolder}"
REF="${DEV_SCAFFOLDER_REF:-main}"
DEST="${DEV_SCAFFOLDER_DEST:-$HOME/workspace/dev-scaffolder}"

# ── Output helpers ──────────────────────────────────────────────────────────
say()  { printf '\033[36m▸ %s\033[0m\n' "$1"; }
ok()   { printf '\033[32m  ✓ %s\033[0m\n' "$1"; }
die()  { printf '\033[31m✗ %s\033[0m\n' "$1" >&2; exit 1; }

printf '\033[35m'
echo "╔══════════════════════════════════════════════════════════╗"
echo "║   dev-scaffolder bootstrap                               ║"
echo "╚══════════════════════════════════════════════════════════╝"
printf '\033[0m'

# ── Detect platform ─────────────────────────────────────────────────────────
case "$(uname -s)" in
  Darwin) PLATFORM="macos" ;;
  Linux)  PLATFORM="linux" ;;
  *)      die "Unsupported OS: $(uname -s). This bootstrap supports macOS and Linux." ;;
esac
say "Platform: $PLATFORM"

# ── Ensure git ──────────────────────────────────────────────────────────────
ensure_git() {
  command -v git >/dev/null 2>&1 && return
  say "git not found — installing…"
  if [[ "$PLATFORM" == "macos" ]]; then
    if command -v brew >/dev/null 2>&1; then
      brew install git
    else
      xcode-select --install 2>/dev/null || true
      die "Installing Xcode Command Line Tools (provides git). Re-run this command once it finishes."
    fi
  else
    if command -v apt-get >/dev/null 2>&1; then
      local sudo=""; [[ $EUID -ne 0 ]] && sudo="sudo"
      $sudo apt-get update -qq && $sudo apt-get install -y -qq git
    else
      die "Could not auto-install git. Please install git and re-run."
    fi
  fi
  ok "git installed"
}
ensure_git

# ── Resolve repo URL ────────────────────────────────────────────────────────
if [[ "$REPO" == *"://"* || "$REPO" == /* || "$REPO" == git@* ]]; then
  REPO_URL="$REPO"
else
  REPO_URL="https://github.com/$REPO.git"
fi

# ── Clone or update to the latest ───────────────────────────────────────────
if [[ -d "$DEST/.git" ]]; then
  say "Updating existing checkout at ${DEST}…"
  git -C "$DEST" remote set-url origin "$REPO_URL"
  git -C "$DEST" fetch --quiet origin "$REF"
  git -C "$DEST" checkout --quiet "$REF"
  git -C "$DEST" pull --ff-only --quiet origin "$REF" || say "Could not fast-forward; using current checkout."
  ok "Updated to latest '$REF'"
else
  say "Cloning $REPO_URL ($REF) → ${DEST}…"
  mkdir -p "$(dirname "$DEST")"
  git clone --branch "$REF" --depth 1 "$REPO_URL" "$DEST"
  ok "Cloned to $DEST"
fi

# ── Run the platform installer (passing through any args) ───────────────────
INSTALLER="$DEST/$PLATFORM/install-all.sh"
[[ -f "$INSTALLER" ]] || die "Installer not found: $INSTALLER"
chmod +x "$INSTALLER" 2>/dev/null || true

say "Running $PLATFORM installer…"
cd "$DEST/$PLATFORM"
exec bash "./install-all.sh" "$@"
