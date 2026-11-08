#!/usr/bin/env bash
# screenshot.sh area|screen|saved FILE - screenshots, with the shell's own
# screenshot screen (modules/Screenshot.qml).
#
#   area        (Print)        the screen freezes: drag over an area, move it or
#                              drag its edges, right-click to draw on it;
#                              Enter = done, Esc = cancel
#   screen      (Shift+Print)  the screen the pointer is on, at once
#   saved FILE  (the shell, when it has taken one) FILE is the picture
#
# (hyprland.lua starts the first two itself, through Hyprland's event socket:
# quicker than this script.)
#
# The picture is moved to ~/Pictures/Screenshots AND copied to the clipboard.
# A notification "Screenshot saved" shows it for 8 seconds: click it and the
# file manager opens the folder in a new window, with the file selected. Esc on
# the screenshot screen cancels: nothing is saved, the clipboard stays as it was.
set -u

case "${1:-area}" in
area | screen)
    exec qs -c frame ipc call screenshot "${1:-area}"
    ;;
saved) ;;
*)
    echo "usage: $0 area|screen|saved FILE" >&2
    exit 2
    ;;
esac

src="${2:-}"
# nothing taken (or an empty file): nothing to do
if [ -z "$src" ] || [ ! -s "$src" ]; then
    [ -n "$src" ] && rm -f "$src"
    exit 0
fi

dir="$HOME/Pictures/Screenshots"
mkdir -p "$dir"
file="$dir/Screenshot_$(date +%F_%H-%M-%S).png"
# two in the same second: don't overwrite the first
n=2
while [ -e "$file" ]; do
    file="$dir/Screenshot_$(date +%F_%H-%M-%S)_$n.png"
    n=$((n + 1))
done
mv -f "$src" "$file" || exit 1

wl-copy --type image/png <"$file"

# waits until the notification is clicked ("default") or goes away (nothing)
action="$(notify-send -a Screenshot -i "$file" -A "default=Open" -t 8000 "Screenshot saved")"

if [ "$action" = default ]; then
    if command -v nautilus >/dev/null 2>&1; then
        # a new window of the folder with the file selected (Nautilus opens a file's folder
        # and selects it; --select would show it in a Nautilus window that is already open)
        exec nautilus --new-window "$file"
    fi
    # any other file manager that speaks the freedesktop "show this file" call
    gdbus call --session --dest org.freedesktop.FileManager1 \
        --object-path /org/freedesktop/FileManager1 \
        --method org.freedesktop.FileManager1.ShowItems "['file://$file']" "" >/dev/null 2>&1 ||
        exec xdg-open "$dir"
fi
