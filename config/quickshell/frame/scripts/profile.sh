#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
#  profile.sh - your picture and your name, for the Settings app's Profile card
#  (System page, services/Profile.qml)
#
#    profile.sh pick                      a file dialog for a picture (zenity's; its
#                                         title matches the file-dialog rule of
#                                         hyprland.lua, so it floats in the middle):
#                                         prints the one you picked (nothing: none)
#    profile.sh picture PNG JPG [THEME]   PNG becomes your picture: ~/.face (and
#                                         ~/.face.icon, if you have that file), what
#                                         the lock screen shows; JPG the login
#                                         screen's, THEME/assets/avatar.jpg (Pixie,
#                                         /usr/share/sddm/themes/pixie) - install.sh
#                                         makes that file yours, so no password is
#                                         needed; prints "login" when it was replaced
#    profile.sh reset [THEME]             no picture any more: ~/.face and ~/.face.icon
#                                         go to the trash, the login screen's copy is
#                                         emptied (it shows the first letter of your
#                                         name then); prints "login" when it was
#    profile.sh name NAME                 your full name, the one the lock and login
#                                         screen show (/etc/passwd): with pkexec, so
#                                         it asks for your password
# ═══════════════════════════════════════════════════════════════════════════
set -u

case "${1:-}" in
pick)
    if ! command -v zenity >/dev/null 2>&1; then
        notify-send -a "Settings" "Profile" "Choosing a picture needs zenity: sudo pacman -S zenity" 2>/dev/null
        exit 2
    fi
    start="$(xdg-user-dir PICTURES 2>/dev/null)"
    [[ -n $start && -d $start ]] || start="$HOME"
    zenity --file-selection --title="Choose a Picture" --filename="$start/" \
        --file-filter="Pictures | *.png *.PNG *.jpg *.JPG *.jpeg *.JPEG *.webp *.WEBP" 2>/dev/null
    exit 0
    ;;
picture)
    png="${2:-}"
    jpg="${3:-}"
    theme="${4:-/usr/share/sddm/themes/pixie}"
    [[ -s $png ]] || exit 1
    # under another name first, so nothing reads half a picture
    cp -f "$png" "$HOME/.face.part" && chmod 644 "$HOME/.face.part" && mv -f "$HOME/.face.part" "$HOME/.face" || exit 1
    if [[ -f $HOME/.face.icon && ! -L $HOME/.face.icon ]]; then
        cp -f "$png" "$HOME/.face.icon"
    fi
    login="$theme/assets/avatar.jpg"
    if [[ -s $jpg && -f $login && -w $login ]]; then
        cat "$jpg" >"$login" && echo login
    elif [[ -e $login ]]; then
        echo "profile.sh: $login is not yours, so the login screen keeps its picture (run ./install.sh again)" >&2
    fi
    rm -f "$png" "$jpg"
    exit 0
    ;;
reset)
    theme="${2:-/usr/share/sddm/themes/pixie}"
    for f in "$HOME/.face" "$HOME/.face.icon"; do
        if [[ -L $f ]]; then
            rm -f "$f"
        elif [[ -e $f ]]; then
            gio trash -f "$f" 2>/dev/null || rm -f "$f" || exit 1
        fi
    done
    login="$theme/assets/avatar.jpg"
    if [[ ! -s $login ]]; then
        echo login                          # nothing there: the login screen shows the letter already
    elif [[ -f $login && -w $login ]]; then
        : >"$login" && echo login
    else
        echo "profile.sh: $login is not yours, so the login screen keeps its picture (run ./install.sh again)" >&2
    fi
    exit 0
    ;;
name)
    # pkexec: 126 = no password given (the dialog was closed), 127 = not allowed / wrong password
    command -v pkexec >/dev/null 2>&1 || { echo "profile.sh: pkexec (polkit) is missing" >&2; exit 3; }
    usermod=/usr/bin/usermod
    [[ -x $usermod ]] || usermod=/usr/sbin/usermod
    exec pkexec "$usermod" -c "${2-}" "$(id -un)"
    ;;
*)
    echo "usage: profile.sh pick | picture PNG JPG [THEME] | reset [THEME] | name NAME" >&2
    exit 2
    ;;
esac
