#!/usr/bin/env bash
# Make GNOME (Ubuntu 24.04) behave like the KDE setup in kde/.config:
# 12 desktops, KWin shortcuts, quick tiling, no window chrome, launchers.
# Window-management features GNOME lacks live in the faydesk extension
# (gnome/.local/share/gnome-shell/extensions/faydesk@fablackner).
#
# Shortcuts use keysyms of the German nodeadkeys layout, like KDE did.
# Safe to re-run. Log out and back in afterwards so GNOME loads the extension.
set -euo pipefail

cd "$(dirname "$0")"

if ! command -v gsettings >/dev/null 2>&1; then
  echo "gsettings not found; is this a GNOME desktop?"
  exit 1
fi

EXT_UUID="faydesk@fablackner"
EXT_SRC="$PWD/gnome/.local/share/gnome-shell/extensions/$EXT_UUID"

# Set a key only if the schema/key exists (Ubuntu dock or GNOME versions differ).
gset() {
  local schema="$1" key="$2" value="$3"
  if gsettings writable "$schema" "$key" >/dev/null 2>&1; then
    gsettings set "$schema" "$key" "$value"
  else
    echo "  skip $schema $key (not available)"
  fi
}

# ---------------------------------------------------------
# Extension
# ---------------------------------------------------------
glib-compile-schemas "$EXT_SRC/schemas"

# The extension directory itself is linked by doStow.sh (package "gnome").
# Create the parent so stow links only the extension, not ~/.local/share/gnome-shell.
mkdir -p "$HOME/.local/share/gnome-shell/extensions"

python3 - "$EXT_UUID" <<'PY'
import ast, subprocess, sys
uuid = sys.argv[1]
raw = subprocess.check_output(["gsettings", "get", "org.gnome.shell", "enabled-extensions"], text=True)
raw = raw.strip().removeprefix("@as ")
enabled = ast.literal_eval(raw)
if uuid not in enabled:
    enabled.append(uuid)
subprocess.check_call(["gsettings", "set", "org.gnome.shell", "enabled-extensions", str(enabled)])
PY
gset org.gnome.shell disable-user-extensions false

# ---------------------------------------------------------
# Desktops: 12 static, spanning all monitors (kwinrc [Desktops])
# ---------------------------------------------------------
gset org.gnome.mutter dynamic-workspaces false
gset org.gnome.mutter workspaces-only-on-primary false
gset org.gnome.desktop.wm.preferences num-workspaces 12

WM=org.gnome.desktop.wm.keybindings

# Meta+1..9, Meta+Alt+0/1/2 switch to desktop 1..12
for i in {1..9}; do
  gset "$WM" "switch-to-workspace-$i" "['<Super>$i']"
done
gset "$WM" switch-to-workspace-10 "['<Alt><Super>0']"
gset "$WM" switch-to-workspace-11 "['<Alt><Super>1']"
gset "$WM" switch-to-workspace-12 "['<Alt><Super>2']"

# Window to desktop N, same keys as kglobalshortcutsrc
gset "$WM" move-to-workspace-1 "['<Alt><Super>Left']"
gset "$WM" move-to-workspace-2 "['<Alt><Super>Right']"
gset "$WM" move-to-workspace-3 "['<Control><Super>z']"
gset "$WM" move-to-workspace-4 "['<Control><Super>y']"
for i in {5..9}; do
  gset "$WM" "move-to-workspace-$i" "['<Super>F$i']"
done
gset "$WM" move-to-workspace-10 "['<Super>Page_Down']"
gset "$WM" move-to-workspace-11 "['<Super>Page_Up']"
gset "$WM" move-to-workspace-12 "['<Shift><Alt><Super>b']"

# Meta+Ctrl+Left/Right (wrapping) is handled by the extension; clear GNOME's
# defaults, which collide with the window-to-desktop keys above.
for key in switch-to-workspace-{left,right,up,down,last} move-to-workspace-{left,right,up,down,last}; do
  gset "$WM" "$key" "[]"
done

# Ubuntu dock binds Super+1..9 and Super+Q.
gset org.gnome.shell.extensions.dash-to-dock hot-keys false
gset org.gnome.shell.extensions.dash-to-dock shortcut "[]"
gset org.gnome.shell.extensions.dash-to-dock shortcut-text "''"
for i in {1..9}; do
  gset org.gnome.shell.keybindings "switch-to-application-$i" "[]"
done

# ---------------------------------------------------------
# Window shortcuts
# ---------------------------------------------------------
gset "$WM" close "['<Alt>F4']"
gset "$WM" minimize "['<Super>w']"
gset "$WM" toggle-maximized "['<Super>p']"
gset "$WM" toggle-fullscreen "['<Super>f']"          # KDE: Meta+F toggled the frame
gset "$WM" switch-windows "['<Alt>Tab']"             # KDE: Walk Through Windows
gset "$WM" switch-windows-backward "['<Shift><Alt>Tab']"
gset "$WM" switch-applications "['<Super>Tab']"
gset "$WM" switch-applications-backward "['<Shift><Super>Tab']"
gset "$WM" activate-window-menu "[]"                 # Alt+Space opens search instead
gset org.gnome.shell.window-switcher current-workspace-only true
gset org.gnome.shell.app-switcher current-workspace-only true

# Free keys that the KDE layout uses for something else.
gset org.gnome.shell.keybindings toggle-application-view "[]"    # Super+A
gset org.gnome.shell.keybindings toggle-quick-settings "[]"      # Super+S
gset org.gnome.mutter.keybindings switch-monitor "['XF86Display']"  # Super+P
gset org.gnome.mutter.wayland.keybindings restore-shortcuts "[]"  # Super+Escape
gset org.gnome.settings-daemon.plugins.media-keys terminal "[]"  # Ctrl+Alt+T

# Meta opens the overview, Alt+Space / Meta+Alt+W like KRunner / Overview
gset org.gnome.mutter overlay-key "'Super_L'"
gset org.gnome.shell.keybindings toggle-overview "['<Alt>space', '<Alt><Super>w']"
gset org.gnome.settings-daemon.plugins.media-keys screensaver "['<Super>l']"

# Meta+drag moves, Meta+right-drag resizes (like KWin)
gset org.gnome.desktop.wm.preferences mouse-button-modifier "'<Super>'"
gset org.gnome.desktop.wm.preferences resize-with-right-button true

# ---------------------------------------------------------
# No window chrome
# ---------------------------------------------------------
# No titlebar buttons; GTK headerbars follow this too.
gset org.gnome.desktop.wm.preferences button-layout "':'"
gset org.gnome.mutter attach-modal-dialogs false

# ---------------------------------------------------------
# Look: dark, night light, auto-hiding dock on the left (Plasma panel)
# ---------------------------------------------------------
gset org.gnome.desktop.interface color-scheme "'prefer-dark'"
gset org.gnome.desktop.interface gtk-theme "'Yaru-dark'"
gset org.gnome.desktop.interface monospace-font-name "'JetBrainsMono Nerd Font Mono 13'"
gset org.gnome.settings-daemon.plugins.color night-light-enabled true
gset org.gnome.settings-daemon.plugins.color night-light-temperature "uint32 5500"
gset org.gnome.shell.extensions.dash-to-dock dock-position "'LEFT'"
gset org.gnome.shell.extensions.dash-to-dock dock-fixed false
gset org.gnome.shell.extensions.dash-to-dock autohide true
gset org.gnome.shell.extensions.dash-to-dock intellihide false
gset org.gnome.shell.extensions.dash-to-dock extend-height false

# Keyboard layout the shortcuts were recorded with (kxkbrc)
gset org.gnome.desktop.input-sources sources "[('xkb', 'de+nodeadkeys')]"

# ---------------------------------------------------------
# Launchers (kglobalshortcutsrc [services])
# ---------------------------------------------------------
# On de-nodeadkeys: " = Shift+2, ! = Shift+1, § = Shift+3, $ = Shift+4,
# & = Shift+6, / = Shift+7. GNOME stores the unshifted key plus Shift.
# Desktop files live in kde/.local/share/applications (stowed by doStow.sh).
# The GNOME session PATH has neither ~/.local/bin nor Homebrew, so kitty is
# called by its full path and tmux/yazi run in an interactive zsh (.zshrc
# sets up brew). The KDE desktop files hardcode /home/fabian, so avoid them.
KITTY="$HOME/.local/kitty.app/bin/kitty"
LAUNCHERS=(
  "VS Code|code|<Shift><Super>2"
  "Chrome|google-chrome|<Shift><Super>1"
  "Kitty tmux|$KITTY zsh -ic 'tmux new-session -A -s main'|<Shift><Super>3"
  "Yazi|$KITTY zsh -ic yazi|<Shift><Super>4"
  "Kitty|$KITTY|<Shift><Super>7"
  "Files|nautilus --new-window|<Shift><Super>6"
  "Screenshot|flameshot gui|<Control><Alt>h"
  "Shutdown|gtk-launch sudo-2|<Control><Alt><Super>h"
  "Start keyd|gtk-launch sudo-3|<Super>BackSpace"
  "Stop keyd|gtk-launch sudo-4|<Super>Escape"
)

MK=org.gnome.settings-daemon.plugins.media-keys
MK_PATH=/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings
paths=()
for i in "${!LAUNCHERS[@]}"; do
  IFS='|' read -r name command binding <<<"${LAUNCHERS[$i]}"
  path="$MK_PATH/faydesk$i/"
  paths+=("'$path'")
  gsettings set "$MK.custom-keybinding:$path" name "$name"
  gsettings set "$MK.custom-keybinding:$path" command "$command"
  gsettings set "$MK.custom-keybinding:$path" binding "$binding"
done
gsettings set "$MK" custom-keybindings "[$(IFS=,; echo "${paths[*]}")]"

echo "GNOME configured. Log out and back in to load $EXT_UUID."
