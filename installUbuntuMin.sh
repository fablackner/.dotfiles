#!/usr/bin/env bash
# Minimal desktop setup for a fresh Ubuntu 24.04 (GNOME). Afterwards run:
#   ./doStow.sh && ./configureGnome.sh   # then log out and back in
set -euo pipefail

source "$(dirname "$0")/installUtility.sh"

trap print_install_report EXIT

if [[ "${EUID}" -eq 0 ]]; then
  echo "Run this script as your normal user (not root)."
  exit 1
fi

source /etc/os-release
if [[ "${ID:-}" != "ubuntu" || "${VERSION_ID:-}" != "24.04" ]]; then
  echo "Warning: written for Ubuntu 24.04, this is ${PRETTY_NAME:-unknown}."
fi

export DEBIAN_FRONTEND=noninteractive

# ---------------------------------------------------------
# APT: Core Dependencies & System/GUI Tools
# ---------------------------------------------------------
sudo apt-get update -qq

# git, curl and build-essential are not on a fresh Ubuntu desktop but this
# script needs them (Homebrew installer, repo clones, building keyd).
# Everything else it uses (gnupg, unzip, fontconfig, python3, xprop, ...)
# ships with Ubuntu desktop.
APT_PACKAGES=(
  git curl build-essential
  xclip xsel zsh stow flameshot
  gnome-tweaks gnome-shell-extension-prefs
)

run_step "Sys Packages (Bulk)" sudo apt-get install -y -qq "${APT_PACKAGES[@]}" >/dev/null

# ---------------------------------------------------------
# HOMEBREW: CLI Tools, Utilities, & Languages
# ---------------------------------------------------------
run_step "Homebrew System" install_homebrew

BREW_PACKAGES=(
  bat btop duf dust eza fd fzf gh git-delta glow lazydocker lazygit
  neovim resvg ripgrep starship tmux yazi zoxide
)

run_step "Brew Packages (Bulk)" /home/linuxbrew/.linuxbrew/bin/brew install -q "${BREW_PACKAGES[@]}"

# ---------------------------------------------------------
# CONFIGURATION & DOTFILES
# ---------------------------------------------------------
ensure_path_in_file "$HOME/.bashrc" "$HOME/.local/bin"

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

if [[ "$(getent passwd "$USER" | cut -d: -f7)" != "$(command -v zsh)" ]]; then
  run_step "Default shell zsh" sudo chsh -s "$(command -v zsh)" "$USER"
fi

# ---------------------------------------------------------
# VSCODE: Microsoft APT repository
# ---------------------------------------------------------
if ! command -v code >/dev/null 2>&1; then
  run_step "VSCode" install_vscode_apt
fi

# ---------------------------------------------------------
# KEYD: same remapping as on the KDE machine (not started at boot;
# Meta+Backspace / Meta+Esc start and stop it, see configureGnome.sh)
# ---------------------------------------------------------
run_step "keyd" install_keyd

printf '\nNext: ./doStow.sh && ./configureGnome.sh, then log out and back in.\n'
