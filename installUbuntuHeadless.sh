#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/installUtility.sh"

trap print_install_report EXIT

if [[ "${EUID}" -eq 0 ]]; then
  echo "Run this script as your normal user (not root)."
  exit 1
fi



# ---------------------------------------------------------
# APT: Core Dependencies & Additional Packages
# ---------------------------------------------------------
sudo apt-get update -qq
sudo apt-get install -y -qq build-essential bubblewrap git curl gnupg ca-certificates unzip >/dev/null

run_step "apt:ffmpeg" sudo apt-get install -y -qq ffmpeg >/dev/null
run_step "apt:zsh" sudo apt-get install -y -qq zsh >/dev/null

# ---------------------------------------------------------
# HOMEBREW: CLI Tools, Utilities, & Languages
# ---------------------------------------------------------
run_step "Homebrew System" install_homebrew

BREW_PACKAGES=(
  bat btop duf dust eza fd fzf gh htop httpie imagemagick jq
  lazydocker lazygit midnight-commander neovim poppler resvg ripgrep
  sevenzip starship stow tmux yazi zellij zoxide
)

run_step "Brew Packages (Bulk)" /home/linuxbrew/.linuxbrew/bin/brew install -q "${BREW_PACKAGES[@]}"

if [[ -f "$(brew --prefix)/opt/fzf/install" ]]; then
  "$(brew --prefix)/opt/fzf/install" --all --no-bash --no-fish >/dev/null 2>&1
fi

# ---------------------------------------------------------
# CONFIGURATION & DOTFILES
# ---------------------------------------------------------

run_step "Oh-My-Zsh (Core)" sync_repo "$HOME/.oh-my-zsh" "https://github.com/ohmyzsh/ohmyzsh.git"

zsh_custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
mkdir -p "$zsh_custom/plugins" "$HOME/.local/bin"

sync_repo "$zsh_custom/plugins/zsh-autosuggestions" "https://github.com/zsh-users/zsh-autosuggestions"
sync_repo "$zsh_custom/plugins/zsh-syntax-highlighting" "https://github.com/zsh-users/zsh-syntax-highlighting.git"
sync_repo "$zsh_custom/plugins/zsh-completions" "https://github.com/zsh-users/zsh-completions"
sync_repo "$zsh_custom/plugins/fast-syntax-highlighting" "https://github.com/zdharma-continuum/fast-syntax-highlighting.git"
sync_repo "$HOME/.tmux/plugins/tpm" "https://github.com/tmux-plugins/tpm"

record_installed "Zsh & Tmux Plugins"