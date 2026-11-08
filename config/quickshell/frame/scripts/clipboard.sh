#!/usr/bin/env bash
# clipboard.sh - the clipboard history for the Clipboard panel (left edge).
#
#   clipboard.sh list [N]        the newest N entries (default 50), one JSON
#                                object per line, newest first:
#                                  {"id":"12","kind":"text","text":"..."}
#                                  {"id":"11","kind":"image","path":"...png","w":1920,"h":1080}
#   clipboard.sh copy ID [TYPE]  put entry ID on the clipboard again
#   clipboard.sh delete ID       remove entry ID from the history
#
# The history itself is kept by cliphist (hyprland.lua starts
# "wl-paste --watch cliphist store"). Pictures are decoded once into
# $XDG_RUNTIME_DIR/frameshell-clipboard so the panel can show them.
set -u

cache="${XDG_RUNTIME_DIR:-/tmp}/frameshell-clipboard"
command -v cliphist >/dev/null 2>&1 || exit 0

image_re='^\[\[ binary data .+ (png|jpeg|gif|bmp|tiff) ([0-9]+)x([0-9]+) \]\]$'

case "${1:-}" in
list)
    max="${2:-50}"
    mkdir -p "$cache" && chmod 700 "$cache"
    keep=" "
    listing="$(cliphist list 2>/dev/null | head -n "$max")"
    while IFS=$'\t' read -r id preview; do
        [[ $id =~ ^[0-9]+$ ]] || continue
        if [[ $preview =~ $image_re ]]; then
            ext="${BASH_REMATCH[1]}" w="${BASH_REMATCH[2]}" h="${BASH_REMATCH[3]}"
            file="$cache/$id.$ext"
            [ -s "$file" ] || cliphist decode "$id" >"$file" 2>/dev/null
            if [ ! -s "$file" ]; then
                rm -f "$file"
                continue
            fi
            keep+="$id.$ext "
            jq -cn --arg id "$id" --arg path "$file" --argjson w "$w" --argjson h "$h" \
                '{id: $id, kind: "image", path: $path, w: $w, h: $h}'
        elif [[ $preview == "[[ binary data"* ]]; then
            continue                    # something that is neither text nor a picture
        else
            # the real text (with its line breaks), only the start of it
            text="$(cliphist decode "$id" 2>/dev/null | head -c 600)"
            jq -cn --arg id "$id" --arg text "$text" '{id: $id, kind: "text", text: $text}'
        fi
    done <<<"$listing"
    # forget pictures that left the list
    for f in "$cache"/*; do
        [ -e "$f" ] || continue
        [[ $keep == *" ${f##*/} "* ]] || rm -f "$f"
    done
    ;;
copy)
    id="${2:-}"
    [[ $id =~ ^[0-9]+$ ]] || exit 2
    if [ -n "${3:-}" ]; then
        cliphist decode "$id" | wl-copy --type "$3"
    else
        cliphist decode "$id" | wl-copy
    fi
    ;;
delete)
    id="${2:-}"
    [[ $id =~ ^[0-9]+$ ]] || exit 2
    printf '%s\n' "$id" | cliphist delete
    rm -f "$cache/$id".*
    ;;
*)
    echo "usage: $0 list [N] | copy ID [TYPE] | delete ID" >&2
    exit 2
    ;;
esac
