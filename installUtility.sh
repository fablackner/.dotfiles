#!/usr/bin/env bash
# Common utility functions for installation scripts

declare -a INSTALLED_STEPS=()
declare -a FAILED_STEPS=()
declare -a SKIPPED_STEPS=()

record_installed() { INSTALLED_STEPS+=("$1"); }
record_failed() { FAILED_STEPS+=("$1"); }
record_skipped() { SKIPPED_STEPS+=("$1"); }

run_step() {
  local step_name="$1"
  shift
  if "$@"; then
    record_installed "$step_name"
  else
    record_failed "$step_name"
  fi
}

print_install_report() {
  local exit_code="$?"
  printf '\n==== Installation Report ====\n'
  printf 'Installed (%d):\n' "${#INSTALLED_STEPS[@]}"
  [[ "${#INSTALLED_STEPS[@]}" -gt 0 ]] && printf '  - %s\n' "${INSTALLED_STEPS[@]}" || printf '  - none\n'
  printf 'Failed (%d):\n' "${#FAILED_STEPS[@]}"
  [[ "${#FAILED_STEPS[@]}" -gt 0 ]] && printf '  - %s\n' "${FAILED_STEPS[@]}" || printf '  - none\n'
  printf 'Skipped (%d):\n' "${#SKIPPED_STEPS[@]}"
  [[ "${#SKIPPED_STEPS[@]}" -gt 0 ]] && printf '  - %s\n' "${SKIPPED_STEPS[@]}" || printf '  - none\n'
  printf 'Exit code: %s\n' "$exit_code"
}

sync_repo() {
  local target_dir="$1"
  local repo_url="$2"
  shift 2
  if [[ -d "${target_dir}/.git" ]]; then
    git -C "$target_dir" pull --ff-only -q
  elif [[ ! -e "$target_dir" ]]; then
    git clone -q "$@" "$repo_url" "$target_dir"
  fi
}

install_homebrew() {
  if ! command -v brew >/dev/null 2>&1 && [[ ! -f /home/linuxbrew/.linuxbrew/bin/brew ]]; then
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" >/dev/null
  fi
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
  for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
    touch "$rc"
    grep -Fq 'brew shellenv' "$rc" || echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> "$rc"
  done
}

ensure_path_in_file() {
  touch "$1"
  grep -Fq "$2" "$1" || printf '\nexport PATH="%s:$PATH"\n' "$2" >> "$1"
}

install_uv() {
  local uv_install_dir="$HOME/.local/bin"

  if [[ -x "$uv_install_dir/uv" && -x "$uv_install_dir/uvx" ]]; then
    return 0
  fi

  mkdir -p "$uv_install_dir" || return
  curl -LsSf https://astral.sh/uv/install.sh \
    | env UV_INSTALL_DIR="$uv_install_dir" UV_NO_MODIFY_PATH=1 sh
}

install_bun() {
  local bun_install_dir="$HOME/.bun"

  if [[ ! -x "$bun_install_dir/bin/bun" ]]; then
    curl -fsSL https://bun.com/install | SHELL=/bin/sh bash || return
  fi

  export BUN_INSTALL="$bun_install_dir"
  export PATH="$BUN_INSTALL/bin:$PATH"
}

install_kitty() {
  local kitty_dir="$HOME/.local/kitty.app"
  local local_bin_dir="$HOME/.local/bin"
  local applications_dir="$HOME/.local/share/applications"
  local desktop_file="$applications_dir/kitty.desktop"

  curl -fsSL https://sw.kovidgoyal.net/kitty/installer.sh \
    | sh /dev/stdin launch=n || return

  mkdir -p "$local_bin_dir" "$applications_dir" || return
  ln -sf "$kitty_dir/bin/kitty" "$kitty_dir/bin/kitten" "$local_bin_dir/" || return
  cp "$kitty_dir/share/applications/kitty.desktop" "$desktop_file" || return
  sed -i \
    -e "s|Icon=kitty|Icon=$kitty_dir/share/icons/hicolor/256x256/apps/kitty.png|g" \
    -e "s|Exec=kitty|Exec=$kitty_dir/bin/kitty|g" \
    "$desktop_file"
}

install_jetbrainsmono() {
  local temp_dir archive_path
  temp_dir="$(mktemp -d)"
  archive_path="$temp_dir/JetBrainsMono.zip"
  curl -sfL "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/JetBrainsMono.zip" -o "$archive_path"
  unzip -q -o "$archive_path" -d "$temp_dir"
  mkdir -p "$HOME/.local/share/fonts"
  cp "$temp_dir"/*.ttf "$HOME/.local/share/fonts/" 2>/dev/null || true
  fc-cache -f "$HOME/.local/share/fonts"
  rm -rf "$temp_dir"
}

# Microsoft's deb822 layout. The code package writes this same file itself,
# so a differently named .list with another Signed-By path would make apt fail.
install_vscode_apt() {
  local keyring=/usr/share/keyrings/microsoft.gpg
  curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
    | gpg --dearmor | sudo install -D -m 644 /dev/stdin "$keyring" || return
  sudo rm -f /etc/apt/sources.list.d/vscode.list
  sudo tee /etc/apt/sources.list.d/vscode.sources >/dev/null <<SRC || return
Types: deb
URIs: https://packages.microsoft.com/repos/code
Suites: stable
Components: main
Architectures: amd64,arm64,armhf
Signed-By: $keyring
SRC
  echo "code code/add-microsoft-repo boolean true" | sudo debconf-set-selections
  sudo apt-get update -qq || return
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq code >/dev/null
}

# keyd is not packaged for Ubuntu 24.04. Installs the binary, the systemd unit
# and keyd/default.conf, but does not enable the service.
install_keyd() {
  local config_src
  config_src="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/keyd/default.conf"
  if ! command -v keyd >/dev/null 2>&1; then
    local temp_dir
    temp_dir="$(mktemp -d)"
    git -c advice.detachedHead=false clone -q --depth 1 --branch v2.5.0 https://github.com/rvaiya/keyd "$temp_dir/keyd" || return
    make -s -C "$temp_dir/keyd" >/dev/null 2>&1 || return
    sudo make -s -C "$temp_dir/keyd" install >/dev/null || return
    rm -rf "$temp_dir"
    sudo systemctl daemon-reload || true
  fi
  sudo install -D -m 644 "$config_src" /etc/keyd/default.conf
}
