#!/usr/bin/env bash
# lock.sh [--instant] - lock the screen.
# lock.sh --resident  - start the lock screen in the background, unlocked
#                       (hyprland.lua does it at login)
#
# The lock screen (../lock.qml: the Pixie login screen) is its own Quickshell
# process. It is started once and then waits in the background, everything
# loaded, so locking only has to show it: it comes up at once and fades in
# over the desktop. If it cannot lock - Quickshell missing, an error, a
# crash - hyprlock takes over, so the screen is never left unlocked. Only one
# lock runs at a time: calling this again while locked does nothing.
#
# --instant (hypridle, right before a suspend) shows it at once instead of
# fading - also one that is still fading in - so the computer never wakes up
# with the desktop half visible.
#
# Used by SUPER + Escape (hyprland.lua), hypridle (lock_cmd, before_sleep_cmd)
# and "Lock" in the power menu (power.sh).
set -u

here=$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)
qml="$here/lock.qml"
run="${XDG_RUNTIME_DIR:-/tmp}"
lockfile="$run/frameshell-lock"           # held while locked
state="$run/frameshell-lock-state"        # lock.qml writes locked / unlocking / unlocked / ended
pidfile="$run/frameshell-lockscreen.pid"  # the lock screen waiting in the background

mode=lock
held=0
resident=0
for a in "$@"; do
    case $a in
    --held) held=1 ;;
    --instant) mode=now ;;
    --resident) resident=1 ;;
    --resident-exec)
        # (internal) become the lock screen that stays in the background
        echo $$ >"$pidfile"
        export FRAME_LOCK_RESIDENT=1 FRAME_LOCK_MARKER="$state"
        exec qs -p "$qml"
        ;;
    esac
done

# Hyprland draws the desktop under the lock screen (misc:session_lock_xray) only
# while it fades in or out; the lock screen switches it off once it is fully there
xray() { # xray true|false
    [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && command -v hyprctl >/dev/null 2>&1 || return 0
    timeout 2 hyprctl eval "hl.config({ misc = { session_lock_xray = $1 } })" >/dev/null 2>&1
    return 0
}

# the process id of the lock screen in the background, if it runs
resident_pid() {
    local pid=""
    { read -r pid <"$pidfile"; } 2>/dev/null
    case $pid in '' | *[!0-9]*) return 1 ;; esac
    { tr '\0' ' ' <"/proc/$pid/cmdline"; } 2>/dev/null | grep -q 'lock\.qml' || return 1
    echo "$pid"
}

# start the lock screen in the background: idle (unlocked), lock or now
start_resident() {
    rm -f "$pidfile"
    FRAME_LOCK_START="$1" setsid bash "$0" --resident-exec </dev/null >/dev/null 2>&1 &
    for _ in $(seq 40); do
        resident_pid >/dev/null && return 0
        sleep 0.05
    done
    return 1
}

if [ $resident = 1 ]; then
    command -v qs >/dev/null 2>&1 && [ -f "$qml" ] || exit 0
    resident_pid >/dev/null || start_resident idle
    exit 0
fi

# Hold $lockfile while locked. -o: the lock screen does not inherit it.
if [ $held = 0 ]; then
    if command -v flock >/dev/null 2>&1; then
        if ! flock -n "$lockfile" true 2>/dev/null; then
            # already locked: before a suspend, make a lock screen that is still
            # fading in appear at once
            if [ $mode = now ] && command -v qs >/dev/null 2>&1 && pid="$(resident_pid)"; then
                timeout 2 qs ipc --pid "$pid" call lock now >/dev/null 2>&1
            fi
            exit 0
        fi
        if [ $mode = now ]; then
            exec flock -n -E 0 -o "$lockfile" bash "$0" --held --instant
        fi
        exec flock -n -E 0 -o "$lockfile" bash "$0" --held
    fi
    pidof hyprlock >/dev/null 2>&1 && exit 0
fi

read_state() {
    st=""
    { read -r st <"$state"; } 2>/dev/null || true
}

if command -v qs >/dev/null 2>&1 && [ -f "$qml" ]; then
    rm -f "$state"
    [ $mode = now ] || xray true

    # show the lock screen that waits in the background; start one if there is none
    pid="$(resident_pid)" || pid=""
    # (--pid: this very process, even if some other lock screen were running too)
    if [ -n "$pid" ] && ! timeout 2 qs ipc --pid "$pid" call lock "$mode" >/dev/null 2>&1; then
        kill "$pid" 2>/dev/null    # not answering: replace it
        pid=""
    fi
    if [ -z "$pid" ]; then
        start_resident "$mode"
        pid="$(resident_pid)" || pid=""
    fi

    if [ -n "$pid" ]; then
        # up within 6 s (it gives up itself after 5 s)?
        st=""
        for _ in $(seq 60); do
            read_state
            [ -n "$st" ] && break
            kill -0 "$pid" 2>/dev/null || break
            sleep 0.1
        done
        # then wait until you are back in ("unlocking": the lock screen still fades out)
        while { [ "$st" = locked ] || [ "$st" = unlocking ]; } && kill -0 "$pid" 2>/dev/null; do
            sleep 0.5
            read_state
        done
        xray false
        case $st in
        unlocked | ended)
            rm -f "$state"
            exit 0
            ;;
        esac
        # never came up, or quit while locked: hyprlock takes over
        kill "$pid" 2>/dev/null
        echo "lock.sh: the lock screen failed (state '${st:-none}'), starting hyprlock" >&2
    else
        xray false
        echo "lock.sh: the lock screen did not start, starting hyprlock" >&2
    fi
fi

# fallback: hyprlock (takes over a lock that was left behind,
# see allow_session_lock_restore in hyprland.lua)
pidof hyprlock >/dev/null 2>&1 || exec hyprlock --no-fade-in
