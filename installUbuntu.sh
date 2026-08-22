#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/installUtility.sh"

trap print_install_report EXIT

if [[ "${EUID}" -eq 0 ]]; then
  echo "Run this script as your normal user (not root)."
  exit 1
fi

# ---------------------------------------------------------
# APT: Core Dependencies & System/GUI Tools
# ---------------------------------------------------------
sudo apt-get update -qq

APT_PACKAGES=(
  build-essential bubblewrap git curl gnupg ca-certificates fontconfig unzip
  wl-clipboard xclip xsel ghostty flameshot meld kdiff3 ffmpeg zsh
  imagemagick poppler-utils tmux mc htop jq stow httpie 7zip
)

run_step "Sys Packages (Bulk)" sudo apt-get install -y -qq "${APT_PACKAGES[@]}" >/dev/null

# ---------------------------------------------------------
# HOMEBREW: CLI Tools, Utilities, & Languages
# ---------------------------------------------------------
run_step "Homebrew System" install_homebrew

BREW_PACKAGES=(
  bat btop duf dust eza fd fzf gh glow lazydocker lazygit
  neovim resvg ripgrep starship yazi zellij zoxide
)

run_step "Brew Packages (Bulk)" /home/linuxbrew/.linuxbrew/bin/brew install -q "${BREW_PACKAGES[@]}"

if [[ -f "$(brew --prefix)/opt/fzf/install" ]]; then
  "$(brew --prefix)/opt/fzf/install" --all --no-bash --no-fish >/dev/null 2>&1
fi

# ---------------------------------------------------------
# CONFIGURATION & DOTFILES
# ---------------------------------------------------------
ensure_path_in_file "$HOME/.zshrc" "$HOME/.local/bin"
ensure_path_in_file "$HOME/.bashrc" "$HOME/.local/bin"

run_step "uv" install_uv
run_step "Bun" install_bun
run_step "Kitty" install_kitty
run_step "JetBrainsMono Nerd Font" install_jetbrainsmono

run_step "Oh-My-Zsh (Core)" sync_repo "$HOME/.oh-my-zsh" "https://github.com/ohmyzsh/ohmyzsh.git"

zsh_custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
mkdir -p "$zsh_custom/plugins" "$HOME/.local/bin"

sync_repo "$zsh_custom/plugins/zsh-autosuggestions" "https://github.com/zsh-users/zsh-autosuggestions"
sync_repo "$zsh_custom/plugins/zsh-syntax-highlighting" "https://github.com/zsh-users/zsh-syntax-highlighting.git"
sync_repo "$zsh_custom/plugins/zsh-completions" "https://github.com/zsh-users/zsh-completions"
sync_repo "$zsh_custom/plugins/fast-syntax-highlighting" "https://github.com/zdharma-continuum/fast-syntax-highlighting.git"
sync_repo "$HOME/.tmux/plugins/tpm" "https://github.com/tmux-plugins/tpm"

record_installed "Zsh & Tmux Plugins"

# ---------------------------------------------------------
# VSCODE: Custom APT Source
# ---------------------------------------------------------
if ! command -v code >/dev/null 2>&1; then
  if [[ ! -f /etc/apt/sources.list.d/vscode.list ]]; then
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee /etc/apt/keyrings/packages.microsoft.gpg >/dev/null
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
      | sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null
    sudo apt-get update -qq
  fi
  run_step "VSCode" sudo apt-get install -y -qq code >/dev/null
fi
