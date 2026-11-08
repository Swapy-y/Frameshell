#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
#  wallpaper.sh <picture> [login theme folder]
#
#  Run by the shell after you picked a wallpaper (SUPER + CTRL + Left / Right,
#  services/Wallpapers.qml):
#    1. remembers it: ~/.local/state/frameshell/wallpaper (the lock screen
#       reads that file too, so it shows the same picture)
#    2. gives the login screen the same picture: copies it over the theme's
#       assets/wallpaper.png (/usr/share/sddm/themes/pixie). install.sh makes
#       that one file yours, so no password is needed. If it isn't (an older
#       install), run ./install.sh again.
# ═══════════════════════════════════════════════════════════════════════════
pic="${1:-}"
theme="${2:-/usr/share/sddm/themes/pixie}"
[[ -f $pic ]] || { echo "wallpaper.sh: no such picture: $pic" >&2; exit 1; }

state="${XDG_STATE_HOME:-$HOME/.local/state}/frameshell"
mkdir -p "$state"
printf '%s\n' "$pic" >"$state/wallpaper"

login="$theme/assets/wallpaper.png"
if [[ -w $login ]]; then
    cmp -s "$pic" "$login" || cat "$pic" >"$login"
elif [[ -e $login ]]; then
    echo "wallpaper.sh: $login is not yours, so the login screen keeps its picture (run ./install.sh again)" >&2
fi
exit 0
