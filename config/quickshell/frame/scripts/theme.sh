#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
#  theme.sh <name> - GTK and Qt apps follow the shell's colour theme
#  (Config.qml `themes`: Default, Noir, Mocha).
#
#    Default  ->  the GTK theme Frame,        Kvantum Frame,        Qt colours frame.conf,
#                 kitty ~/.config/kitty/frame.conf, Firefox ~/.config/frameshell/firefox/Default
#    <Name>   ->  the GTK theme Frame-<Name>, Kvantum Frame<Name>,  Qt colours frame-<name>.conf,
#                 kitty ~/.config/kitty/frame-<name>.conf, Firefox .../firefox/<Name>
#                 (a theme of your own without them: Default's)
#
#  The shell runs it when you pick a theme (SUPER + CTRL + Up / Down, services/Themes.qml)
#  and once when it starts. It also remembers the theme for the shell
#  (~/.local/state/frameshell/theme, read by Config.qml).
#
#  It only switches settings that use one of the Frame themes now: a GTK theme,
#  Kvantum theme, Qt colour scheme, kitty config or Firefox userChrome.css /
#  userContent.css you picked yourself stays. Running GTK 3 apps and kitty
#  windows change at once; GTK 4 / libadwaita and Qt apps and Firefox when they
#  start again.
# ═══════════════════════════════════════════════════════════════════════════
name="${1:-Default}"
CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/frameshell"

gtk=Frame
kvantum=Frame
qtcolors=frame.conf
if [[ $name != Default ]]; then
    [[ -d $DATA/themes/Frame-$name ]] && gtk="Frame-$name"
    [[ -d $CFG/Kvantum/Frame$name ]] && kvantum="Frame$name"
    [[ -f $CFG/qt6ct/colors/frame-${name,,}.conf || -f $CFG/qt5ct/colors/frame-${name,,}.conf ]] &&
        qtcolors="frame-${name,,}.conf"
fi

# key=value in an ini-like file: changed only if it holds one of ours (`match`)
# and only when it really changes (apps watching the file are not woken for nothing)
set_key() { # set_key <file> <key> <new value> <match: a pattern for the current value>
    local file=$1 key=$2 value=$3 match=$4 current
    [[ -f $file ]] || return 0
    current="$(grep -m1 "^$key=" "$file" | cut -d= -f2-)"
    [[ -n $current && $current == $match && $current != "$value" ]] || return 0
    sed -i "s|^$key=.*|$key=$value|" "$file"
}

# ── GTK ──
# running GTK 3 apps (and plain GTK 4 ones) switch at once
if command -v gsettings >/dev/null 2>&1; then
    current="$(gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null)"
    if [[ $current == "'Frame"* && $current != "'$gtk'" ]]; then
        gsettings set org.gnome.desktop.interface gtk-theme "$gtk"
    fi
fi
set_key "$CFG/gtk-3.0/settings.ini" gtk-theme-name "$gtk" "Frame*"
set_key "$CFG/gtk-4.0/settings.ini" gtk-theme-name "$gtk" "Frame*"
# libadwaita apps never load a theme: ~/.config/gtk-4.0/gtk.css imports the colours
css="$CFG/gtk-4.0/gtk.css"
if [[ -f $css ]] && grep -q "themes/Frame[^/\"]*/gtk-4.0/colors.css" "$css" &&
    ! grep -q "themes/$gtk/gtk-4.0/colors.css" "$css"; then
    sed -i "s#themes/Frame[^/\"]*/gtk-4.0/colors.css#themes/$gtk/gtk-4.0/colors.css#" "$css"
fi

# ── Qt: the Kvantum theme (the shapes) and the qt5ct / qt6ct palette ──
set_key "$CFG/Kvantum/kvantum.kvconfig" theme "$kvantum" "Frame*"
for v in 5 6; do
    conf="$CFG/qt${v}ct/qt${v}ct.conf"
    [[ -f $conf ]] || continue
    current="$(grep -m1 "^color_scheme_path=" "$conf" | cut -d= -f2-)"
    [[ $current == */colors/frame*.conf ]] || continue
    set_key "$conf" color_scheme_path "${current%/*}/$qtcolors" "*/colors/frame*.conf"
done

# ── kitty: ~/.config/kitty/kitty.conf is a link to the theme's config (frame.conf for Default,
#    frame-<name>.conf); open kitty windows reload it at once. A kitty.conf of your own (a file,
#    not such a link) stays. ──
kittyconf=frame.conf
[[ $name != Default && -f $CFG/kitty/frame-${name,,}.conf ]] && kittyconf="frame-${name,,}.conf"
link="$CFG/kitty/kitty.conf"
if [[ -L $link && -f $CFG/kitty/$kittyconf ]]; then
    current="$(readlink "$link")"
    if [[ ${current##*/} == frame*.conf && ${current##*/} != "$kittyconf" ]]; then
        ln -sfn "$kittyconf" "$link" && pkill -USR1 -x kitty 2>/dev/null
    fi
fi

# ── Firefox: userChrome.css and userContent.css in each profile's chrome folder are links to
#    the theme's (~/.config/frameshell/firefox/<theme>/; Default's for a theme without them).
#    Firefox shows the change the next time it starts. A userChrome.css / userContent.css of
#    your own (a file, or a link to somewhere else) stays. A profile that gets the links for
#    the first time (one Firefox made after install.sh ran) also gets the keyboard shortcuts,
#    customKeys.json, unless it has its own. ──
# every Firefox profile in profiles.ini (~/.mozilla/firefox, or ~/.config/mozilla/firefox
# for profiles made by Firefox 147 and later)
firefox_profiles() {
    local base
    for base in "$HOME/.mozilla/firefox" "$CFG/mozilla/firefox"; do
        [[ -f $base/profiles.ini ]] || continue
        awk -v base="$base" '
            function out() { if (path != "") print (rel == "0" ? path : base "/" path) }
            /^\[/ { out(); path = ""; rel = "1"; profile = ($0 ~ /^\[Profile/); next }
            profile && /^Path=/ { path = substr($0, 6) }
            profile && /^IsRelative=/ { rel = substr($0, 12) }
            END { out() }' "$base/profiles.ini"
    done
}
FF="$CFG/frameshell/firefox"
ffdir="$FF/Default"
[[ $name != Default && -d $FF/$name ]] && ffdir="$FF/$name"
if [[ -d $ffdir ]]; then
    while IFS= read -r profile; do
        [[ -n $profile && -d $profile ]] || continue
        ours=0
        met=0                                               # it had our links before
        for f in userChrome.css userContent.css; do
            [[ -f $ffdir/$f ]] || continue
            dst="$profile/chrome/$f"
            if [[ -L $dst ]]; then
                target="$(readlink "$dst")"
                [[ $target == "$FF"/* ]] || continue        # a link of your own
                ours=1
                met=1
                [[ $target == "$ffdir/$f" ]] && continue    # already the theme's
            elif [[ -e $dst ]]; then
                continue                                    # a file of your own
            fi
            mkdir -p "$profile/chrome" && ln -sfn "$ffdir/$f" "$dst" && ours=1
        done
        # Firefox only reads the two files with this setting on (user.js: read at every start)
        if ((ours)) && ! grep -qs 'toolkit.legacyUserProfileCustomizations.stylesheets' "$profile/user.js"; then
            printf '%s\n' 'user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);' >>"$profile/user.js"
        fi
        # a copy (Firefox rewrites it when you change a shortcut in about:keyboard)
        if ((ours && !met)) && [[ -f $FF/customKeys.json && ! -e $profile/customKeys.json ]]; then
            cp "$FF/customKeys.json" "$profile/customKeys.json"
        fi
    done < <(firefox_profiles)
fi

# ── remember it for the shell ──
mkdir -p "$STATE"
[[ "$(cat "$STATE/theme" 2>/dev/null)" == "$name" ]] || printf '%s\n' "$name" >"$STATE/theme"
exit 0
