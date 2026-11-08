#!/usr/bin/env bash
# emoji.sh EMOJI - what the emoji picker (SUPER + ., modules/EmojiPicker.qml) does with the
# emoji you pick, once it has closed:
#   1. copies it (Ctrl + V pastes it again)
#   2. puts it into the text field you were typing in (emoji-insert.py: the way an
#      input method does - GTK and Qt apps, Firefox, kitty ...)
#   3. no text field said so (apps without input method support: Electron apps such as
#      VS Code or Discord, X11 apps): types it with wtype, if it is installed
set -u
emoji="${1:-}"
[ -n "$emoji" ] || exit 0

printf %s "$emoji" | wl-copy

# the window you were in gets the keyboard back when the picker closes: a moment for that
sleep 0.15

if command -v python3 >/dev/null 2>&1; then
    python3 "$(dirname "$0")/emoji-insert.py" "$emoji" && exit 0
fi
if command -v wtype >/dev/null 2>&1; then
    exec wtype -- "$emoji"
fi
