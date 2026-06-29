# Path to Oh My Zsh installation
export ZSH="$HOME/.oh-my-zsh"

# Theme — disabled in favor of Starship prompt
ZSH_THEME=""

# Plugins
plugins=(
  git
  zsh-autosuggestions
  zsh-syntax-highlighting
  docker
  npm
  python
)

source "$ZSH/oh-my-zsh.sh"

# ── PATH ───────────────────────────────────────────────────────────────────
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

# ── Aliases ────────────────────────────────────────────────────────────────
alias ll="ls -alF"
alias la="ls -A"
alias l="ls -CF"

# oh-my-zsh style directory shortcuts
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."

# fd / bat compatibility (Ubuntu names differ)
if command -v batcat &>/dev/null && ! command -v bat &>/dev/null; then
  alias bat="batcat"
fi
if command -v fdfind &>/dev/null && ! command -v fd &>/dev/null; then
  alias fd="fdfind"
fi

# ── Editor ─────────────────────────────────────────────────────────────────
export EDITOR="nvim"
export VISUAL="nvim"

# ── Starship prompt ───────────────────────────────────────────────────────
if command -v starship &>/dev/null; then
  eval "$(starship init zsh)"
fi

# ── Zoxide (smart cd) ────────────────────────────────────────────────────
if command -v zoxide &>/dev/null; then
  eval "$(zoxide init zsh)"
fi

# ── fzf ───────────────────────────────────────────────────────────────────
if command -v fzf &>/dev/null; then
  source <(fzf --zsh) 2>/dev/null || true
fi

# ── j (jump — dev-scaffolder directory jumper) ─────────────────────────────
# Defined by the jump tool's installer; sourced here when present.
# >>> dev-scaffolder jump (j) >>>
[ -f "$HOME/.local/share/dev-scaffolder/jump/init.zsh" ] && source "$HOME/.local/share/dev-scaffolder/jump/init.zsh"
# <<< dev-scaffolder jump (j) <<<

# ── Node version manager (optional) ──────────────────────────────────────
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
