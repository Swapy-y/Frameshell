#!/usr/bin/env bash
# colorpicker.sh - pick a colour anywhere on the screen (the colour picker
# block in the top-right corner of the shell).
#
# Click to pick, right-click or Esc to cancel. The hex code (#RRGGBB) is
# copied to the clipboard and shown in a notification with a swatch.
set -u

command -v hyprpicker >/dev/null 2>&1 || {
    notify-send -a "Color picker" "hyprpicker is not installed" "sudo pacman -S hyprpicker"
    exit 1
}
pidof hyprpicker >/dev/null 2>&1 && exit 0     # already picking

color="$(hyprpicker --autocopy --no-fancy 2>/dev/null | grep -Eo '#[0-9A-Fa-f]{6}' | tail -n 1)"
[ -n "$color" ] || exit 0                      # cancelled

# a small swatch of the colour for the notification (one file per colour). It stays
# (a few hundred bytes each): the notification history shows it later too.
dir="${XDG_CACHE_HOME:-$HOME/.cache}/frameshell/colors"
mkdir -p "$dir"
swatch="$dir/${color#\#}.svg"
printf '<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64"><rect width="64" height="64" rx="16" fill="%s"/></svg>\n' "$color" >"$swatch"

notify-send -a "Color picker" -i "$swatch" "$color" "Copied to the clipboard"
