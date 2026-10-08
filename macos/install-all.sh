#!/usr/bin/env bash
# ============================================================================
# macOS Dev-Machine Scaffolder — Orchestrator
# Installs every tool (in the right order) and deploys every config.
#
# Usage:
#   ./install-all.sh                          # run everything
#   ./install-all.sh --only nvim,starship     # run only matching tool scripts
#   ./install-all.sh --skip ghostty           # skip specific tool scripts
#   ./install-all.sh --dry-run                # print what would run
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_DIR="$SCRIPT_DIR/tools"

# ── Parse arguments ────────────────────────────────────────────────────────
ONLY=""
SKIP=""
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --only)  ONLY="$2"; shift 2 ;;
    --skip)  SKIP="$2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Convert comma-separated lists to arrays
IFS=',' read -ra ONLY_ARR <<< "$ONLY"
IFS=',' read -ra SKIP_ARR <<< "$SKIP"

# ── Banner ─────────────────────────────────────────────────────────────────
printf '\033[35m\n'
echo "╔══════════════════════════════════════════════════════════╗"
echo "║   macOS Dev-Machine Scaffolder                           ║"
echo "║   one-click reproducible terminal setup                  ║"
echo "╚══════════════════════════════════════════════════════════╝"
printf '\033[0m\n'

# ── Build plan ─────────────────────────────────────────────────────────────
# Extract tool name from filename: "50-starship.sh" -> "starship"
tool_name() {
  local base
  base="$(basename "$1" .sh)"
  echo "${base#[0-9][0-9]-}"
}

# Check if a name is in an array
in_array() {
  local needle="$1"; shift
  for item in "$@"; do
    [[ "$item" == "$needle" ]] && return 0
  done
  return 1
}

# Starship's bundled prompt requires Nerd Font glyphs. Explicit skips win.
if [[ -n "$ONLY" ]] && in_array starship "${ONLY_ARR[@]}" \
    && ! in_array starship "${SKIP_ARR[@]}" && ! in_array fonts "${SKIP_ARR[@]}"; then
  ONLY_ARR+=("fonts")
fi

echo "Plan:"
declare -a PLAN_NAMES=()
declare -a PLAN_PATHS=()
declare -a PLAN_RUN=()

for script in "$TOOLS_DIR"/*.sh; do
  [[ -f "$script" ]] || continue
  name="$(tool_name "$script")"
  run=true

  if [[ -n "$ONLY" ]] && ! in_array "$name" "${ONLY_ARR[@]}"; then
    run=false
  fi
  if [[ -n "$SKIP" ]] && in_array "$name" "${SKIP_ARR[@]}"; then
    run=false
  fi

  PLAN_NAMES+=("$name")
  PLAN_PATHS+=("$script")
  PLAN_RUN+=("$run")

  if $run; then
    printf '\033[32m  [+] %s\033[0m\n' "$name"
  else
    printf '\033[90m  [ ] %s\033[0m\n' "$name"
  fi
done

if $DRY_RUN; then
  printf '\n\033[33m(dry run — no scripts executed)\033[0m\n'
  exit 0
fi

# ── Execute ────────────────────────────────────────────────────────────────
failed=()
for i in "${!PLAN_NAMES[@]}"; do
  if [[ "${PLAN_RUN[$i]}" == "true" ]]; then
    # The plan handles fonts once (or honors an explicit skip), so standalone
    # Starship dependency setup must not repeat it.
    if ! DEV_SCAFFOLDER_FONTS_HANDLED=1 bash "${PLAN_PATHS[$i]}"; then
      printf '\033[31m  ✗ %s FAILED\033[0m\n' "${PLAN_NAMES[$i]}"
      failed+=("${PLAN_NAMES[$i]}")
    fi
  fi
done

echo ""
if [[ ${#failed[@]} -eq 0 ]]; then
  printf '\033[32m╔══════════════════════════════════════════════════════════╗\033[0m\n'
  printf '\033[32m║  ✅  Setup complete. Restart your terminal to enjoy.      ║\033[0m\n'
  printf '\033[32m╚══════════════════════════════════════════════════════════╝\033[0m\n'
else
  printf '\033[33m⚠  Completed with failures: %s\033[0m\n' "${failed[*]}"
  exit 1
fi
