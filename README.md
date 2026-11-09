# .dotfiles

Neovim and Kitty are installed from their official pre-built Linux archives. Kitty is installed per-user in `~/.local/kitty.app`. JetBrainsMono Nerd Font is downloaded automatically from the Nerd Fonts v3.4.0 release archive by the installer scripts.

## Tools Included

The installer includes a comprehensive set of modern CLI tools:

**File and Directory Navigation:**
- fzf - Command-line fuzzy finder
- zoxide - Smarter cd with directory tracking
- fd - Fast alternative to find
- eza - Modern ls replacement with Git status
- yazi - Async terminal file manager

**Text Search and Processing:**
- ripgrep (rg) - Fast regex search
- bat - Cat with syntax highlighting
- jq - JSON processor
- delta - Syntax highlighting pager for Git/diff

**Version Control and Development:**
- lazygit - Git terminal UI
- lazydocker - Docker terminal UI
- gh - GitHub CLI

**System Monitoring:**
- btop - Resource monitor
- htop - Process viewer
- duf - Disk usage/free utility
- dust - Disk usage visualization

**Terminal Emulators, Multiplexing, and Environment:**
- Ghostty - GPU-accelerated terminal emulator
- Kitty - GPU-accelerated terminal emulator
- tmux - Terminal multiplexer
- zellij - Modern tmux alternative
- starship - Customizable shell prompt

Install with:
```
./installSuse.sh
# or
./installUbuntu.sh

./doStow.sh
```

## Ubuntu 24.04 desktop (GNOME with the KDE setup's behaviour)

On a fresh Ubuntu 24.04:
```
sudo apt install -y git
git clone https://github.com/fablackner/.dotfiles ~/.dotfiles && cd ~/.dotfiles
./installUbuntu.sh      # or ./installUbuntuMin.sh
./doStow.sh
./configureGnome.sh
```
Then log out and back in. Both scripts install VS Code and keyd (built from source, config in `keyd/default.conf`, not started at boot). `installUbuntuMin.sh` leaves out uv, Bun, zellij and most apt tools (ffmpeg, imagemagick, mc, htop, meld, kdiff3, ...).

`configureGnome.sh` carries the KWin setup over to GNOME: 12 static desktops, the shortcuts from `kglobalshortcutsrc`, launchers, no titlebar buttons, an auto-hiding dock on the left, night light and the `de nodeadkeys` layout the shortcuts were recorded with. The `faydesk@fablackner` extension (stowed from `gnome/`) adds what GNOME lacks:

| Shortcut | Action |
|---|---|
| Meta+A / Meta+G | tile left / right half |
| Meta+Q / B / Z / X | tile top-left / top-right / bottom-left / bottom-right |
| Meta+R / T / C / S | focus window left / right / up / down |
| Meta+Ctrl+Left/Right | previous / next desktop, wrapping around |
| Meta+Ctrl+Esc | kill window |

It also opens new windows maximized, dims unfocused windows by 10%, switches desktops without animation and removes Mutter titlebars from X11 windows. Settings live under `org.gnome.shell.extensions.faydesk` (e.g. `gsettings set org.gnome.shell.extensions.faydesk tile-gap 0`).

Handled by GNOME directly: Meta+1..9 and Meta+Alt+0/1/2 switch desktops, the window-to-desktop keys from KDE, Meta+P maximize, Meta+W minimize, Meta+F fullscreen, Alt+F4, Alt+Tab, Meta+L lock, Alt+Space search.

Update neovim with:
```
./updateNeovim.sh
```
