// Fay Desktop: the KWin behaviour from kde/.config that GNOME lacks out of the box.
// Plain keybindings (desktops, maximize, close, launchers) are set by configureGnome.sh.

import Clutter from 'gi://Clutter';
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import Meta from 'gi://Meta';
import Shell from 'gi://Shell';

import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';

// [x, y, width, height] as fractions of the monitor work area.
const TILES = {
    'tile-left': [0, 0, 0.5, 1],
    'tile-right': [0.5, 0, 0.5, 1],
    'tile-top': [0, 0, 1, 0.5],
    'tile-bottom': [0, 0.5, 1, 0.5],
    'tile-top-left': [0, 0, 0.5, 0.5],
    'tile-top-right': [0.5, 0, 0.5, 0.5],
    'tile-bottom-left': [0, 0.5, 0.5, 0.5],
    'tile-bottom-right': [0.5, 0.5, 0.5, 0.5],
};

const FOCUS = {
    'focus-left': [-1, 0],
    'focus-right': [1, 0],
    'focus-up': [0, -1],
    'focus-down': [0, 1],
};

const DIM_EFFECT = 'faydesk-dim';
const MODES = Shell.ActionMode.NORMAL;

function isManaged(win) {
    return win &&
        !win.minimized &&
        !win.skip_taskbar &&
        win.get_window_type() === Meta.WindowType.NORMAL;
}

function center(win) {
    const r = win.get_frame_rect();
    return [r.x + r.width / 2, r.y + r.height / 2];
}

export default class FayDesktop extends Extension {
    enable() {
        this._settings = this.getSettings();
        this._signals = [];
        this._keys = [];
        this._idleSources = new Set();

        for (const [name, frac] of Object.entries(TILES))
            this._bind(name, () => this._tile(frac));
        for (const [name, dir] of Object.entries(FOCUS))
            this._bind(name, () => this._focus(...dir));
        this._bind('workspace-left', () => this._switchWorkspace(-1));
        this._bind('workspace-right', () => this._switchWorkspace(1));
        this._bind('kill-window', () => global.display.focus_window?.kill());

        this._connect(global.display, 'window-created', (_d, win) => this._onWindowCreated(win));
        this._connect(global.display, 'notify::focus-window', () => this._updateDim());
        this._connect(this._settings, 'changed::dim-inactive', () => this._updateDim());
        this._connect(this._settings, 'changed::instant-workspace-switch', () => this._updateWorkspaceAnimation());

        for (const actor of global.get_window_actors())
            this._undecorate(actor.meta_window);
        this._updateDim();
        this._updateWorkspaceAnimation();
    }

    disable() {
        for (const name of this._keys)
            Main.wm.removeKeybinding(name);
        for (const [obj, id] of this._signals)
            obj.disconnect(id);
        for (const actor of global.get_window_actors())
            actor.remove_effect_by_name(DIM_EFFECT);
        this._restoreWorkspaceAnimation();
        for (const source of this._idleSources)
            GLib.source_remove(source);
        this._idleSources = null;
        this._keys = [];
        this._signals = [];
        this._settings = null;
    }

    _bind(name, handler) {
        Main.wm.addKeybinding(name, this._settings, Meta.KeyBindingFlags.IGNORE_AUTOREPEAT, MODES, handler);
        this._keys.push(name);
    }

    _connect(obj, signal, handler) {
        this._signals.push([obj, obj.connect(signal, handler)]);
    }

    // --- Quick tiling --------------------------------------------------------

    _tile([fx, fy, fw, fh]) {
        const win = global.display.focus_window;
        if (!isManaged(win))
            return;

        // allows_resize() is false while maximized or fullscreen, so leave those first.
        if (win.is_fullscreen())
            win.unmake_fullscreen();
        if (win.get_maximized())
            win.unmaximize(Meta.MaximizeFlags.BOTH);
        if (!win.allows_resize())
            return;

        const area = win.get_work_area_current_monitor();
        const gap = this._settings.get_int('tile-gap');
        // Round the edges, not the sizes, so neighbouring tiles line up exactly.
        const x0 = area.x + Math.round(area.width * fx);
        const x1 = area.x + Math.round(area.width * (fx + fw));
        const y0 = area.y + Math.round(area.height * fy);
        const y1 = area.y + Math.round(area.height * (fy + fh));

        win.move_resize_frame(true, x0 + gap, y0 + gap, x1 - x0 - 2 * gap, y1 - y0 - 2 * gap);
    }

    // --- Directional focus ---------------------------------------------------

    // Same scoring as KWin's Workspace::switchWindow: distance along the
    // direction plus a penalty for the sideways offset.
    _focus(dx, dy) {
        const current = global.display.focus_window;
        const workspace = global.workspace_manager.get_active_workspace();
        const candidates = global.display.sort_windows_by_stacking(
            workspace.list_windows().filter(w => isManaged(w) && w !== current)).reverse();

        if (!current) {
            candidates[0]?.activate(global.get_current_time());
            return;
        }

        const [cx, cy] = center(current);
        let best = null;
        let bestScore = Infinity;
        for (const win of candidates) {
            const [x, y] = center(win);
            const distance = dx !== 0 ? (x - cx) * dx : (y - cy) * dy;
            if (distance <= 0)
                continue;
            const offset = Math.abs(dx !== 0 ? y - cy : x - cx);
            const score = distance + offset + (offset * offset) / distance;
            if (score < bestScore) {
                best = win;
                bestScore = score;
            }
        }
        best?.activate(global.get_current_time());
    }

    // --- Desktops ------------------------------------------------------------

    _switchWorkspace(step) {
        const manager = global.workspace_manager;
        const n = manager.get_n_workspaces();
        const index = (manager.get_active_workspace_index() + step + n) % n;
        manager.get_workspace_by_index(index).activate(global.get_current_time());
    }

    _updateWorkspaceAnimation() {
        this._restoreWorkspaceAnimation();
        const animation = Main.wm._workspaceAnimation;
        if (!animation || !this._settings.get_boolean('instant-workspace-switch'))
            return;
        // WindowManager._switchWorkspace completes the switch in this callback.
        animation.animateSwitch = (_from, _to, _direction, onComplete) => onComplete();
        this._patchedAnimation = animation;
    }

    _restoreWorkspaceAnimation() {
        if (this._patchedAnimation)
            delete this._patchedAnimation.animateSwitch;
        this._patchedAnimation = null;
    }

    // --- New windows ---------------------------------------------------------

    _onWindowCreated(win) {
        // On Wayland the window has no actor yet at this point; wait until it is
        // shown. Changing X11 hints before that keeps the window from being shown,
        // and X11 clients reset a maximize done inside 'shown', so go idle first.
        const id = win.connect('shown', () => {
            win.disconnect(id);
            this._undecorate(win);
            this._updateDim();
            const source = GLib.idle_add(GLib.PRIORITY_DEFAULT_IDLE, () => {
                this._idleSources?.delete(source);
                this._maximizeNew(win);
                return GLib.SOURCE_REMOVE;
            });
            this._idleSources.add(source);
        });
    }

    _maximizeNew(win) {
        if (!this._settings?.get_boolean('maximize-new-windows'))
            return;
        if (!win.get_compositor_private())
            return; // closed in the meantime
        if (isManaged(win) && !win.get_transient_for() && win.can_maximize() &&
            !win.is_fullscreen() && !win.get_maximized())
            win.maximize(Meta.MaximizeFlags.BOTH);
    }

    // Wayland clients draw their own decorations (kitty/ghostty are told not to);
    // X11 clients get a Mutter frame unless their Motif hints ask for none.
    _undecorate(win) {
        if (!this._settings.get_boolean('undecorate-x11'))
            return;
        if (!win || !win.decorated || win.get_client_type() !== Meta.WindowClientType.X11)
            return;
        if (win.get_window_type() !== Meta.WindowType.NORMAL)
            return;
        const xid = win.get_description()?.match(/0x[0-9a-f]+/i)?.[0];
        if (!xid)
            return;
        try {
            const launcher = new Gio.SubprocessLauncher({flags: Gio.SubprocessFlags.STDERR_SILENCE});
            if (!GLib.getenv('DISPLAY'))
                launcher.setenv('DISPLAY', ':0', true);
            launcher.spawnv(['xprop', '-id', xid, '-f', '_MOTIF_WM_HINTS', '32c',
                '-set', '_MOTIF_WM_HINTS', '2, 0, 0, 0, 0']);
        } catch (e) {
            console.warn(`faydesk: could not undecorate ${xid}: ${e.message}`);
        }
    }

    // --- Dim inactive windows ------------------------------------------------

    _updateDim() {
        const strength = this._settings?.get_double('dim-inactive') ?? 0;
        const focus = global.display.focus_window;

        for (const actor of global.get_window_actors()) {
            const win = actor.meta_window;
            const dim = strength > 0 && focus !== null && isManaged(win) && win !== focus &&
                focus.get_transient_for() !== win;
            let effect = actor.get_effect(DIM_EFFECT);
            if (!dim) {
                if (effect)
                    actor.remove_effect(effect);
                continue;
            }
            if (!effect) {
                effect = new Clutter.BrightnessContrastEffect();
                actor.add_effect_with_name(DIM_EFFECT, effect);
            }
            effect.set_brightness(-strength);
        }
    }
}
