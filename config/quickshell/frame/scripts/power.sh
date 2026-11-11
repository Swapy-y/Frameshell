#!/usr/bin/env bash
# power.sh shutdown|reboot|lock|logout

# ── log out ──────────────────────────────────────────────────────────────────
# Every app is asked to close (as if you clicked its X), Hyprland quits and the
# session ends, so the login screen comes back with nothing left running. No
# dialog in between: the shell has already faded the screen to black
# (modules/Curtain.qml).
# An app still open after 3 s (one asking "Save changes?", say) is closed with
# the session.
# What happened is written to ~/.local/state/frameshell/logout.log.

open_windows() {
    hyprctl -j clients 2>/dev/null | grep -c '"address":'
}

logout_now() {
    local sig="${HYPRLAND_INSTANCE_SIGNATURE:-}" hl="" dog="" a i
    echo "$(date '+%F %T') log out (session ${XDG_SESSION_ID:-?})"

    if [ -n "$sig" ] && command -v hyprctl >/dev/null 2>&1; then
        # Hyprland's process (first line of its lock file) and its watchdog, start-hyprland
        hl="$(head -n1 "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr/$sig/hyprland.lock" 2>/dev/null)"
        case $hl in '' | *[!0-9]*) hl="" ;; esac
        if [ -n "$hl" ]; then
            dog="$(ps -o ppid= -p "$hl" 2>/dev/null | tr -d ' ')"
            [ -n "$dog" ] && [ "$(cat "/proc/$dog/comm" 2>/dev/null)" = start-hyprland ] || dog=""
        fi
        echo "  Hyprland: ${hl:-?}, start-hyprland: ${dog:-none}, windows: $(open_windows)"

        # 1. ask every window to close
        if ! hyprctl eval 'for _, w in ipairs(hl.get_windows()) do pcall(function() hl.dispatch(hl.dsp.window.close({ window = w })) end) end' 2>/dev/null | grep -q '^ok'; then
            # a config in the old (hyprlang) syntax
            for a in $(hyprctl -j clients 2>/dev/null | sed -n 's/.*"address": *"\(0x[0-9a-fA-F]*\)".*/\1/p'); do
                hyprctl dispatch closewindow "address:$a" >/dev/null 2>&1
            done
        fi

        # 2. give them up to 3 s
        for i in $(seq 30); do
            [ "$(open_windows)" = 0 ] && break
            sleep 0.1
        done
        echo "  waited $((i / 10)).$((i % 10)) s for them, still open: $(open_windows)"

        # 3. Hyprland quits (the old syntax as a fallback)
        hyprctl dispatch 'hl.dsp.exit()' 2>/dev/null | grep -q '^ok' || hyprctl dispatch exit >/dev/null 2>&1

        # 4. wait until Hyprland and start-hyprland are gone (up to 10 s). Nothing may
        #    signal start-hyprland while it is exiting: that can crash it, and SDDM then
        #    leaves a black screen instead of the login screen.
        for i in $(seq 100); do
            if { [ -z "$hl" ] || ! kill -0 "$hl" 2>/dev/null; } && { [ -z "$dog" ] || ! kill -0 "$dog" 2>/dev/null; }; then
                break
            fi
            sleep 0.1
        done
        echo "  Hyprland gone after $((i / 10)).$((i % 10)) s"
    fi

    # 5. end the session: what still runs (an app that went on in the tray, the
    #    programs of a terminal ...) is closed too
    if [ -n "${XDG_SESSION_ID:-}" ] && command -v loginctl >/dev/null 2>&1; then
        sleep 1
        echo "  ending session $XDG_SESSION_ID"
        exec loginctl terminate-session "$XDG_SESSION_ID"
    fi
}

case "${1:-}" in
shutdown)
    systemctl poweroff
    ;;
reboot)
    systemctl reboot
    ;;
lock)
    # the Pixie lock screen (lock.sh; hyprlock if it fails), detached from the shell
    exec setsid -f bash "$(dirname "$(readlink -f "$0")")/lock.sh" </dev/null >/dev/null 2>&1
    ;;
logout)
    # detached from the shell: this has to outlive the shell and Hyprland
    if [ "${2:-}" != --now ] && command -v setsid >/dev/null 2>&1; then
        log="${XDG_STATE_HOME:-$HOME/.local/state}/frameshell/logout.log"
        if mkdir -p "${log%/*}" 2>/dev/null && touch "$log" 2>/dev/null; then
            # keep it small: start over once it passes 64 KB
            [ "$(stat -c %s "$log" 2>/dev/null || echo 0)" -gt 65536 ] && : >"$log"
        else
            log=/dev/null
        fi
        exec setsid -f bash "$0" logout --now </dev/null >>"$log" 2>&1
    fi
    logout_now
    ;;
*)
    echo "usage: $0 shutdown|reboot|lock|logout" >&2
    exit 2
    ;;
esac
