#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/installUtility.sh"

trap print_install_report EXIT

if [[ "${EUID}" -eq 0 ]]; then
  echo "Run this script as your normal user (not root)."
  exit 1
fi

# ---------------------------------------------------------
# ZYPPER: Core Dependencies & System/GUI Tools
# ---------------------------------------------------------
sudo zypper -n refresh >/dev/null
run_step "zypper:core_deps" sudo zypper -n install git curl gcc make fontconfig unzip gzip tar

run_step "zypper:wl-clipboard" sudo zypper -n install wl-clipboard >/dev/null
run_step "zypper:xclip" sudo zypper -n install xclip >/dev/null
run_step "zypper:xsel" sudo zypper -n install xsel >/dev/null
run_step "zypper:ghostty" sudo zypper -n install ghostty >/dev/null
run_step "zypper:flameshot" sudo zypper -n install flameshot >/dev/null
run_step "zypper:meld" sudo zypper -n install meld >/dev/null
run_step "zypper:kdiff3" sudo zypper -n install kdiff3 >/dev/null
run_step "zypper:ffmpeg" sudo zypper -n install ffmpeg >/dev/null
run_step "zypper:zsh" sudo zypper -n install zsh >/dev/null

# Migrated from Homebrew
run_step "zypper:utils" sudo zypper -n install ImageMagick poppler-tools tmux mc htop jq stow httpie 7zip >/dev/null

# ---------------------------------------------------------
# HOMEBREW: CLI Tools, Utilities, & Languages
# ---------------------------------------------------------
run_step "Homebrew System" install_homebrew

BREW_PACKAGES=(
  bat btop duf dust eza fd fzf gh lazydocker lazygit
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
# VSCODE: Custom Zypper Repository
# ---------------------------------------------------------
if ! command -v code >/dev/null 2>&1; then
  sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc >/dev/null 2>&1
  
  if [[ ! -f /etc/zypp/repos.d/vscode.repo ]]; then
    sudo zypper -n addrepo https://packages.microsoft.com/yumrepos/vscode vscode >/dev/null
    sudo zypper -n refresh >/dev/null
  fi
  
  run_step "VSCode" sudo zypper -n install code >/dev/null
fi