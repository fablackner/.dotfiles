# =============================================================================
# PATH & BASE ENVIRONMENTS
# =============================================================================
# Initialize Homebrew first so its binaries are available
if [[ -f /home/linuxbrew/.linuxbrew/bin/brew ]]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

# Prepend user-local binaries cleanly
export PATH="$HOME/.local/bin:$PATH"

# =============================================================================
# OH-MY-ZSH
# =============================================================================
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="" # Disabled so Starship can handle the prompt

plugins=(
  sudo
  web-search
  copypath
  copyfile
  copybuffer
  dirhistory
  history
  jsontools
  zsh-completions
  zsh-autosuggestions
  fast-syntax-highlighting
)

# Source OMZ before external tools so its defaults don't overwrite them
source $ZSH/oh-my-zsh.sh

# =============================================================================
# DEV ENVIRONMENTS & SOURCING
# =============================================================================
# >>> juliaup initialize >>>
path=('/home/fabian/.juliaup/bin' $path)
export PATH
# <<< juliaup initialize <<<

[[ -r "$HOME/.local/bin/env" ]] && source "$HOME/.local/bin/env"
[[ -r "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"

# nvm
export NVM_DIR="$HOME/.config/nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
[ -s "/home/fabian/.bun/_bun" ] && source "/home/fabian/.bun/_bun"

# =============================================================================
# EXTERNAL TOOLS INIT
# =============================================================================
command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init zsh)"
command -v fzf >/dev/null 2>&1 && source <(fzf --zsh)
command -v starship >/dev/null 2>&1 && eval "$(starship init zsh)"

# =============================================================================
# CUSTOM CONFIGURATION INJECTION
# =============================================================================
# Placed last for absolute override authority
if [[ -f "$HOME/.zsh_custom" ]]; then
    source "$HOME/.zsh_custom"
fi
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

export PATH="/home/fabian/.local/bin:$PATH"
