#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

if ! command -v stow >/dev/null 2>&1; then
  echo "stow is required but not installed."
  exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
  echo "Refusing to run doStow.sh: git working tree is not clean."
  echo "Commit, stash, or discard changes first."
  git --no-pager status --short
  exit 1
fi

packages=(git tmux zsh vscode mc kde nvim ghostty yazi starship zellij htop bin)
backup_root=".stow-adopt-backups/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$backup_root"

for package in "${packages[@]}"; do
  if [[ ! -d "$package" ]]; then
    echo "Skipping '$package' (directory not found)"
    continue
  fi

  stow --adopt "$package"
  cp -r "$package" "$backup_root/$package"

  if git ls-files -- "$package" | grep -q .; then
    git --no-pager restore -- "$package"
  else
    echo "Skipping git restore for '$package' (no tracked files yet)"
  fi
done

echo "Adopt backups saved under: $backup_root"
