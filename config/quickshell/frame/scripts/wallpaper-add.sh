#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
#  wallpaper-add.sh <wallpaper folder> [PICTURE...] - the Settings app's "Add"
#  tile (Wallpaper page, services/Wallpapers.qml)
#
#  Without pictures: opens a file dialog (zenity's; its title matches the
#  file-dialog rule of hyprland.lua, so it floats in the middle). With them
#  (pictures dropped on the tile): takes those. Copies them into the wallpaper
#  folder (~/.local/share/frameshell/wallpapers), where the shell sees them at
#  once. A picture that is already there is not copied again; a different one
#  with the same name gets a number (sea-2.png).
# ═══════════════════════════════════════════════════════════════════════════
set -u

dir="${1:-${XDG_DATA_HOME:-$HOME/.local/share}/frameshell/wallpapers}"
shift $(($# > 0 ? 1 : 0))

tell() { notify-send -a "Settings" -i preferences-desktop-wallpaper "Wallpaper" "$1" 2>/dev/null || true; }

if (($# > 0)); then
    pictures=("$@")                                  # dropped on the tile
else
    if ! command -v zenity >/dev/null 2>&1; then
        tell "Adding a picture needs zenity: sudo pacman -S zenity"
        exit 0
    fi

    # start in Pictures (or your home folder)
    start="$(xdg-user-dir PICTURES 2>/dev/null)"
    [[ -n $start && -d $start ]] || start="$HOME"

    picked="$(zenity --file-selection --multiple --separator=$'\n' --title="Choose Wallpapers" \
        --filename="$start/" \
        --file-filter="Pictures | *.png *.PNG *.jpg *.JPG *.jpeg *.JPEG *.webp *.WEBP" 2>/dev/null)" || exit 0
    [[ -n $picked ]] || exit 0
    mapfile -t pictures <<<"$picked"
fi

mkdir -p "$dir" || {
    tell "Could not make $dir"
    exit 1
}

failed=0
for src in "${pictures[@]}"; do
    [[ -f $src ]] || continue
    name="${src##*/}"
    ext="${name##*.}"
    ext="${ext,,}"
    case $ext in png | jpg | jpeg | webp) ;; *) continue ;; esac
    base="${name%.*}"
    dst="$dir/$name"
    n=2
    while [[ -e $dst ]]; do
        cmp -s "$src" "$dst" && continue 2           # already there
        dst="$dir/$base-$n.$ext"
        n=$((n + 1))
    done
    # copied under a hidden name first, so the shell never reads half a picture
    tmp="$dir/.${dst##*/}.part"
    if cp -- "$src" "$tmp" && chmod 644 "$tmp" && mv -f -- "$tmp" "$dst"; then
        :
    else
        rm -f -- "$tmp"
        failed=$((failed + 1))
    fi
done

((failed)) && tell "Could not copy $failed picture(s) into $dir"
exit 0
