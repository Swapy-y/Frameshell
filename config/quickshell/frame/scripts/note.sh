#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
#  note.sh - the file dialog of the quick note's Save button (modules/QuickNote.qml)
#
#    note.sh pick-save   "Save As": prints the file the note should be saved to
#
#  Prints nothing when the dialog is cancelled. The shell itself writes the
#  file. The dialog is zenity's; its title matches the file-dialog rule of
#  hyprland.lua, so it floats in the middle.
# ═══════════════════════════════════════════════════════════════════════════
set -u

tell() { notify-send -a "Quick note" -i document-save "Quick note" "$1" 2>/dev/null || true; }

if ! command -v zenity >/dev/null 2>&1; then
    tell "The Save button needs zenity: sudo pacman -S zenity"
    exit 0
fi

# start in Documents (or your home folder)
dir="$(xdg-user-dir DOCUMENTS 2>/dev/null)"
[[ -n $dir && -d $dir ]] || dir="$HOME"

case "${1:-}" in
pick-save)
    f="$(zenity --file-selection --save --title="Save As" --filename="$dir/Quick note.txt" 2>/dev/null)" || exit 0
    [[ -n $f ]] && printf '%s\n' "$f"
    ;;
*)
    echo "usage: note.sh pick-save" >&2
    exit 2
    ;;
esac
