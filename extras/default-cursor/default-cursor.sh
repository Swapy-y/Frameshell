#!/bin/sh
# Written by frameshell's install.sh: keeps the computer's default mouse cursor
# (/usr/share/icons/default/index.theme) on the theme given as $1 (Simp1e-Adw-Dark),
# size 24.
#
# That file comes with the package default-cursors and says "Inherits=Adwaita", so
# everything that has no cursor theme of its own shows Adwaita - e.g. the login screen.
# The installer runs this once, and the pacman hook
# /etc/pacman.d/hooks/zz-frameshell-cursor.hook runs it again whenever an update of
# default-cursors puts its own index.theme back.
#
# Only that file is changed, never created: a file of our own there would stop pacman
# from installing default-cursors later ("exists in filesystem").
# If the theme gets uninstalled, the file is put back the way it was before frameshell
# (index.theme.frameshell-backup), so the default cursor never points at a missing theme.
#
# To stop it: sudo rm /etc/pacman.d/hooks/zz-frameshell-cursor.hook

theme="$1"
f=/usr/share/icons/default/index.theme
backup="$f.frameshell-backup"

case "$theme" in
"" | */* | .*)
    echo "default-cursor.sh: usage: default-cursor.sh <cursor theme folder in /usr/share/icons>" >&2
    exit 0
    ;;
esac
# the whole file as frameshell wants it
want="$(printf '%s\n' "[Icon Theme]" "Name=Default" \
    "Comment=Default cursor theme (set by frameshell)" "Inherits=$theme" "Size=24")"

# no file (default-cursors not installed, or just removed): nothing to change
[ -f "$f" ] || exit 0

if [ -d "/usr/share/icons/$theme/cursors" ]; then
    [ "$(cat "$f")" = "$want" ] && exit 0
    # the original once, so it can be put back (not a version this script wrote itself)
    if [ ! -e "$backup" ] && ! grep -qs "set by frameshell" "$f"; then
        cp -p "$f" "$backup"
    fi
    printf '%s\n' "$want" >"$f" &&
        echo "frameshell: the default mouse cursor is $theme, size 24 ($f)"
elif grep -qs "set by frameshell" "$f"; then
    # the theme is gone: the cursor from before frameshell
    if [ -f "$backup" ]; then
        cp -p "$backup" "$f" && rm -f "$backup"
    else
        printf '%s\n' "[Icon Theme]" "Inherits=Adwaita" >"$f"
    fi
    echo "frameshell: $theme is not installed any more - default mouse cursor as before ($f)"
fi
exit 0
