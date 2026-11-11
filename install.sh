#!/usr/bin/env bash
# ╭──────────────────────────────────────────────────────────────────────────╮
# │  Frame — installer for CachyOS (and other Arch-based systems)             │
# │  Hyprland + Quickshell desktop · run it as your normal user, not root     │
# ╰──────────────────────────────────────────────────────────────────────────╯
#
#   ./install.sh                 packages + NVIDIA setup + config files (asks before big steps)
#   ./install.sh --yes           don't ask, answer "yes" to everything
#   ./install.sh --no-packages   only copy the config files (no pacman / AUR / NVIDIA / i2c / Bluetooth / login / boot)
#   ./install.sh --no-nvidia     skip the NVIDIA checks
#   ./install.sh --no-icons      don't offer to download the YAMIS icon pack
#   ./install.sh --no-login      leave the login screen alone (no SDDM / Pixie)
#   ./install.sh --no-boot       leave the boot screen alone (no Plymouth theme)
#   ./install.sh --dry-run       print what would be done, change nothing
#
# Off unless you ask for them (also with --yes):
#   ./install.sh --grub          hide the GRUB boot menu, quiet boot (edits /etc/default/grub)
#   ./install.sh --english-locale   make the whole system English (US): /etc/locale.conf
#   ./install.sh --firefox-keys  the author's Firefox shortcuts (Ctrl+X closes a tab, Ctrl+W
#                                opens one, Ctrl+Q / Ctrl+E back / forward ...)
#
# Your existing configs are never deleted: they are moved to ~/.config/frame-backup-<date>/.

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$CFG/frame-backup-$STAMP"

YES=0
DRY=0
NOCONF=()
ME="$(id -un)"
DO_PACKAGES=1
DO_NVIDIA=1
DO_ICONS=1
DO_LOGIN=1
DO_BOOT=1
DO_GRUB=0
DO_LOCALE=0
DO_FIREFOX_KEYS=0

for arg in "$@"; do
    case "$arg" in
    -y | --yes) YES=1; NOCONF=(--noconfirm) ;;
    --dry-run) DRY=1 ;;
    --no-packages) DO_PACKAGES=0 ;;
    --no-nvidia) DO_NVIDIA=0 ;;
    --no-icons) DO_ICONS=0 ;;
    --no-login) DO_LOGIN=0 ;;
    --no-boot) DO_BOOT=0 ;;
    --grub) DO_GRUB=1 ;;
    --english-locale) DO_LOCALE=1 ;;
    --firefox-keys) DO_FIREFOX_KEYS=1 ;;
    -h | --help)
        sed -n '2,/^# Your existing configs/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
        exit 0
        ;;
    *)
        echo "unknown option: $arg (try --help)" >&2
        exit 2
        ;;
    esac
done

# ── helpers ──────────────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
    B=$'\e[1m'; G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; N=$'\e[0m'
else
    B=""; G=""; Y=""; R=""; N=""
fi
say() { printf '%s==>%s %s\n' "$G$B" "$N" "$*"; }
note() { printf '    %s\n' "$*"; }
warn() { printf '%s!!%s  %s\n' "$Y$B" "$N" "$*" >&2; WARNINGS+=("$*"); }
die() { printf '%sxx%s  %s\n' "$R$B" "$N" "$*" >&2; exit 1; }
WARNINGS=()

# run a command (or just show it with --dry-run)
run() {
    if ((DRY)); then
        printf '    [dry-run] %s\n' "$*"
        return 0
    fi
    "$@"
}

# ask "question" [default y|n]  ->  0 = yes
ask() {
    local q="$1" def="${2:-y}" reply
    if ((YES)); then return 0; fi
    if ((DRY)); then return 0; fi
    if [[ ! -t 0 ]]; then
        [[ $def == y ]]
        return
    fi
    if [[ $def == y ]]; then
        read -r -p "    $q [Y/n] " reply
        [[ -z $reply || $reply =~ ^[Yy] ]]
    else
        read -r -p "    $q [y/N] " reply
        [[ $reply =~ ^[Yy] ]]
    fi
}

SUDO=()
need_sudo() {
    if [[ $EUID -eq 0 ]]; then
        SUDO=()
    elif command -v sudo >/dev/null 2>&1; then
        SUDO=(sudo)
    else
        die "sudo is required for this step (install it, or use --no-packages)."
    fi
}

[[ $EUID -eq 0 ]] && die "Run this as your normal user (it uses sudo only where needed)."
[[ -d $HERE/config/quickshell/frame ]] || die "Run it from the unpacked frameshell folder (config/quickshell/frame not found next to install.sh)."

pkg_available() { pacman -Si "$1" >/dev/null 2>&1; }
pkg_installed() { pacman -Qi "$1" >/dev/null 2>&1; }

# ── 0. what are we on? ───────────────────────────────────────────────────────
say "Frame installer"
if ((DO_PACKAGES)); then
    if ! command -v pacman >/dev/null 2>&1; then
        warn "pacman not found — this installer targets CachyOS / Arch. Copying the config files only."
        DO_PACKAGES=0
    elif ! grep -qiE 'arch|cachyos' /etc/os-release 2>/dev/null; then
        warn "This does not look like Arch/CachyOS (/etc/os-release). Continuing anyway."
    fi
fi

# ── 1. packages ──────────────────────────────────────────────────────────────
MISSING=()      # not found in the official repos
AUR_HELPER=""

# An AUR helper for the packages only the AUR has (the mouse cursor, VS Code, Vesktop).
# A helper that no longer starts (paru-bin / yay-bin built against an older pacman:
# "libalpm.so.NN: cannot open shared object file") counts as missing and is replaced.
# Order: the distribution's own build (CachyOS has paru and yay in its repos, always built
# for the current pacman), else paru built from the AUR source against this pacman.
ensure_aur_helper() {
    if [[ -n $AUR_HELPER ]]; then
        "$AUR_HELPER" --version >/dev/null 2>&1 && return 0
        local owner
        owner="$(pacman -Qqo "$AUR_HELPER" 2>/dev/null)"
        warn "$(basename "$AUR_HELPER") is installed but does not start (it was built for an older pacman)${owner:+ - package $owner}."
        if [[ -n $owner ]] && ask "Replace $owner with a working build?"; then
            run "${SUDO[@]}" pacman -Rdd --noconfirm "$owner" || return 0
            AUR_HELPER=""
        else
            AUR_HELPER=""
            return 0
        fi
    fi
    local h
    for h in paru yay; do
        if pkg_available "$h"; then
            say "Installing the AUR helper $h from your repos"
            if run "${SUDO[@]}" pacman -S --needed "${NOCONF[@]}" "$h"; then
                AUR_HELPER="$(command -v "$h" || true)"
                ((DRY)) && AUR_HELPER="$h"
                [[ -n $AUR_HELPER ]] && return 0
            fi
        fi
    done
    if [[ $EUID -eq 0 ]]; then
        warn "No AUR helper, and AUR packages can't be built as root: run ./install.sh as your normal user."
        return 0
    fi
    say "No AUR helper found: paru can be built from its AUR source (takes a few minutes)."
    ask "Build and install paru now?" || return 0
    if ((DRY)); then
        note "[dry-run] pacman -S base-devel git; git clone https://aur.archlinux.org/paru.git; makepkg -si"
        AUR_HELPER="paru"
        return 0
    fi
    "${SUDO[@]}" pacman -S --needed --noconfirm base-devel git || return 0
    local tmp
    tmp="$(mktemp -d)"
    if git clone --depth 1 --quiet https://aur.archlinux.org/paru.git "$tmp/paru" &&
        (cd "$tmp/paru" && makepkg -si --needed --noconfirm); then
        AUR_HELPER="$(command -v paru || true)"
    fi
    rm -rf "$tmp"
    [[ -n $AUR_HELPER ]] || warn "Building paru failed (see the output above)."
}

install_packages() {
    need_sudo
    AUR_HELPER="$(command -v paru || command -v yay || true)"

    say "System update (recommended before installing — Arch does not support partial upgrades)"
    if ask "Run 'pacman -Syu' now?"; then
        run "${SUDO[@]}" pacman -Syu "${NOCONF[@]}"
    else
        warn "Skipped the system update; the package database may be stale."
    fi

    local -a want=(
        # desktop
        hyprland hyprlock hypridle hyprpolkitagent xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
        quickshell kitty
        # apps
        nautilus gvfs ffmpegthumbnailer file-roller firefox gnome-text-editor celluloid mission-center
        # audio / media / hardware keys
        pipewire pipewire-pulse pipewire-alsa wireplumber pavucontrol playerctl brightnessctl ddcutil
        # Wi-Fi and Bluetooth (the lists under the island talk to NetworkManager and BlueZ)
        networkmanager bluez bluez-utils
        # screenshots, clipboard, notifications, helpers (python: the emoji picker puts the emoji into
        # text fields, scripts/emoji-insert.py, and the Settings app's app icons, scripts/icon-index.py;
        # wtype: it types the emoji into apps that don't have those; pciutils: lspci, the graphics on
        # the Settings app's About card)
        git hyprpicker wl-clipboard wl-clip-persist cliphist libnotify jq polkit xdg-utils xdg-user-dirs wtype python pciutils
        # the file dialogs of the quick note's Save button and the Settings app's wallpaper "Add"
        zenity
        # theming + fonts
        # (qt6-svg / qt5-svg are needed to show the SVG icons; papirus-icon-theme is the fallback behind YAMIS;
        #  adwaita-icon-theme: the Settings app's other app icons; Kvantum draws Qt 5 and Qt 6 apps with
        #  the Frame theme, qt5ct / qt6ct point them at it)
        qt6-wayland qt6-svg qt6ct qt5-wayland qt5-svg qt5ct kvantum kvantum-qt5
        adw-gtk-theme gnome-themes-extra papirus-icon-theme adwaita-icon-theme dconf gsettings-desktop-schemas
        ttf-jetbrains-mono-nerd noto-fonts noto-fonts-emoji fontconfig
    )
    # the mouse cursor (Simp1e Adw Dark) - from a repo if yours has it (e.g. chaotic-aur), otherwise the AUR below
    # (log out needs nothing extra: scripts/power.sh closes the apps itself, without hyprshutdown's window)
    local -a optional=(xcursor-simp1e-adw-dark)

    local -a ok=()
    local p
    for p in "${want[@]}"; do
        if pkg_installed "$p"; then
            continue
        elif pkg_available "$p"; then
            ok+=("$p")
        else
            MISSING+=("$p")
        fi
    done
    for p in "${optional[@]}"; do
        if ! pkg_installed "$p" && pkg_available "$p"; then ok+=("$p"); fi
    done

    if ((${#ok[@]})); then
        say "Installing from the official repos: ${ok[*]}"
        run "${SUDO[@]}" pacman -S --needed "${NOCONF[@]}" "${ok[@]}" ||
            warn "pacman reported a problem — see the output above. Re-run the installer after fixing it."
    else
        say "All repo packages are already installed."
    fi

    # anything the repos did not have (quickshell on older mirrors, …) + the AUR apps
    local -a aur=("${MISSING[@]}")
    pkg_installed visual-studio-code-bin || pkg_installed code || aur+=(visual-studio-code-bin)
    pkg_installed vesktop-bin || pkg_installed vesktop || aur+=(vesktop-bin)
    pkg_installed xcursor-simp1e-adw-dark || aur+=(xcursor-simp1e-adw-dark)
    # quickshell must come from somewhere: try the git version if the repo one is missing
    if ! pkg_installed quickshell && ! pkg_available quickshell; then
        aur=("${aur[@]/quickshell/quickshell-git}")
    fi

    if ((${#aur[@]})); then
        ensure_aur_helper
        if [[ -n $AUR_HELPER ]]; then
            say "From the AUR (via $(basename "$AUR_HELPER")): ${aur[*]}"
            if ask "Install these AUR packages now?"; then
                for p in "${aur[@]}"; do
                    run "$AUR_HELPER" -S --needed "${NOCONF[@]}" "$p" ||
                        warn "Could not install '$p' from the AUR — install it yourself later (the rest still works)."
                done
            else
                warn "Skipped AUR packages: ${aur[*]}"
            fi
        else
            warn "No working AUR helper (paru/yay), so these were not installed: ${aur[*]}. Install paru, then run ./install.sh again (without --no-packages)."
        fi
    fi
}

# ── 2. NVIDIA ────────────────────────────────────────────────────────────────
has_nvidia() { grep -qsx '0x10de' /sys/class/drm/card*/device/vendor; }

nvidia_setup() {
    if ! has_nvidia; then
        say "No NVIDIA GPU detected — skipping NVIDIA setup"
        return
    fi
    say "NVIDIA GPU detected"
    need_sudo

    if ! pkg_installed nvidia-utils; then
        warn "No NVIDIA driver installed."
        if command -v chwd >/dev/null 2>&1; then
            note "CachyOS can pick the right driver for your card: 'sudo chwd -a'"
            if ask "Run it now?"; then run "${SUDO[@]}" chwd -a || warn "chwd failed — install the driver manually (RTX 20xx+: nvidia-open-dkms nvidia-utils)."; fi
        else
            note "RTX 20xx or newer:  sudo pacman -S nvidia-open-dkms nvidia-utils linux-headers"
            note "older cards need the legacy packages — see the Arch wiki page 'NVIDIA'."
        fi
    fi

    # DRM modesetting is mandatory for Wayland
    local ms
    ms="$(cat /sys/module/nvidia_drm/parameters/modeset 2>/dev/null || echo unknown)"
    if [[ $ms != Y ]] && ! grep -rqs 'nvidia[-_]drm.*modeset=1' /etc/modprobe.d /usr/lib/modprobe.d /proc/cmdline 2>/dev/null; then
        say "Enabling NVIDIA DRM modesetting (/etc/modprobe.d/frame-nvidia.conf)"
        if ((DRY)); then
            note "[dry-run] write 'options nvidia_drm modeset=1'"
        else
            echo 'options nvidia_drm modeset=1' | "${SUDO[@]}" tee /etc/modprobe.d/frame-nvidia.conf >/dev/null
        fi
        NEED_REBOOT=1
        if command -v mkinitcpio >/dev/null 2>&1; then
            ask "Rebuild the initramfs now (mkinitcpio -P)?" && run "${SUDO[@]}" mkinitcpio -P
        elif command -v dracut >/dev/null 2>&1; then
            note "dracut system: rebuild your initramfs the way CachyOS tells you to (e.g. 'sudo dracut-rebuild')."
        fi
    else
        note "DRM modesetting already enabled."
    fi

    # suspend / resume support
    local s
    for s in nvidia-suspend nvidia-resume nvidia-hibernate; do
        if systemctl list-unit-files "$s.service" 2>/dev/null | grep -q "$s.service"; then
            run "${SUDO[@]}" systemctl enable "$s.service" >/dev/null 2>&1 || true
        fi
    done

    # hardware video decoding (Firefox, mpv…) — optional
    if ! pkg_installed libva-nvidia-driver && ! pkg_installed nvidia-vaapi-driver; then
        if pkg_available libva-nvidia-driver; then
            run "${SUDO[@]}" pacman -S --needed "${NOCONF[@]}" libva-nvidia-driver || true
        elif pkg_available nvidia-vaapi-driver; then
            run "${SUDO[@]}" pacman -S --needed "${NOCONF[@]}" nvidia-vaapi-driver || true
        fi
    fi
}

# ── 3. monitor brightness over DDC (the brightness slider of the shell) ───────
i2c_setup() {
    say "Monitor brightness over DDC/CI (ddcutil): i2c-dev + group 'i2c'"
    need_sudo
    if ((DRY)); then
        note "[dry-run] write /etc/modules-load.d/frame-i2c.conf, group i2c, udev rule"
        return
    fi
    echo 'i2c-dev' | "${SUDO[@]}" tee /etc/modules-load.d/frame-i2c.conf >/dev/null
    getent group i2c >/dev/null || "${SUDO[@]}" groupadd --system i2c
    id -nG "$ME" | tr ' ' '\n' | grep -qx i2c || {
        "${SUDO[@]}" usermod -aG i2c "$ME"
        NEED_REBOOT=1
    }
    echo 'KERNEL=="i2c-[0-9]*", GROUP="i2c", MODE="0660"' | "${SUDO[@]}" tee /etc/udev/rules.d/45-frame-i2c.rules >/dev/null
    "${SUDO[@]}" modprobe i2c-dev 2>/dev/null || true
    "${SUDO[@]}" udevadm control --reload 2>/dev/null || true
    "${SUDO[@]}" udevadm trigger --subsystem-match=i2c-dev 2>/dev/null || true
}

# ── 3b. Wi-Fi and Bluetooth (the buttons in the island) ───────────────────────
radio_setup() {
    say "Wi-Fi and Bluetooth for the island's lists"
    need_sudo
    # Bluetooth: BlueZ has to run (installed above as bluez)
    if ((DRY)); then
        note "[dry-run] systemctl enable --now bluetooth.service"
    elif [[ -z $(systemctl list-unit-files --no-legend bluetooth.service 2>/dev/null) ]]; then
        warn "bluetooth.service not found (is the 'bluez' package installed?): the Bluetooth list stays empty until it runs."
    elif systemctl is-enabled --quiet bluetooth.service 2>/dev/null && systemctl is-active --quiet bluetooth.service 2>/dev/null; then
        note "bluetooth.service is already running."
    else
        run "${SUDO[@]}" systemctl enable --now bluetooth.service ||
            warn "Could not start bluetooth.service: sudo systemctl enable --now bluetooth"
    fi
    # Wi-Fi: the list talks to NetworkManager (CachyOS uses it by default). Not
    # switched on here: another network service may be in charge of the connection.
    if ((!DRY)) && ! systemctl is-active --quiet NetworkManager.service 2>/dev/null; then
        warn "NetworkManager is not running, so the Wi-Fi list can't show networks. To use it: turn off your current network service (iwd, systemd-networkd …), then sudo systemctl enable --now NetworkManager"
    fi
}

# ── 4. icon pack: Yet Another Monochrome Icon Set (YAMIS) ──────────────────────
# YAMIS is made by DIRN (KDE Store, GPL-3). It is NOT bundled in this folder: with your
# OK this step downloads it from a GitHub mirror (about 2.4 MB) into ~/.local/share/icons/YAMIS.
# Already have it (in ~/.local/share/icons or /usr/share/icons)? Then nothing is downloaded.
YAMIS_REPO="https://github.com/googIyEYES/YAMIS.git"
YAMIS_TARBALL="monochrome-icon-theme.tar.gz"

# The archive may only create files inside a YAMIS/ folder, and its links must stay inside it.
# (The listings are read into variables first: with `set -o pipefail`, a `tar | grep -q`
# pipeline can report failure for the wrong reason.)
yamis_archive_is_safe() {
    local t="$1" names details
    names="$(tar -tzf "$t" 2>/dev/null)" || return 1
    [[ -n $names ]] || return 1
    grep -qvE '^YAMIS(/|$)' <<<"$names" && return 1       # something outside YAMIS/
    grep -q '\.\./' <<<"$names" && return 1                 # a ".." in a path
    details="$(tar -tvzf "$t" 2>/dev/null)" || return 1
    awk '/^l/ { i = index($0, " -> "); tgt = substr($0, i + 4); if (tgt ~ /^\// || tgt ~ /\.\./) bad = 1 } END { exit bad }' <<<"$details" || return 1
    return 0
}

install_yamis() {
    say "Icon pack: Yet Another Monochrome Icon Set (YAMIS)"
    if [[ -f $DATA/icons/YAMIS/index.theme || -f /usr/share/icons/YAMIS/index.theme ]]; then
        note "YAMIS is already installed."
        return
    fi
    if ! command -v git >/dev/null 2>&1 || ! command -v tar >/dev/null 2>&1; then
        warn "git or tar is missing, so YAMIS was not downloaded. Copy the theme folder to $DATA/icons/YAMIS yourself."
        return
    fi
    note "YAMIS is not bundled (GPL-3, by DIRN). Download it from $YAMIS_REPO ?"
    if ! ask "Download and install YAMIS now?"; then
        warn "Skipped YAMIS: apps use Papirus-Dark icons until the theme is in $DATA/icons/YAMIS."
        return
    fi
    if ((DRY)); then
        note "[dry-run] git clone $YAMIS_REPO, check the archive, unpack it into $DATA/icons/"
        return
    fi

    local tmp
    tmp="$(mktemp -d)"
    if git clone --depth 1 --quiet "$YAMIS_REPO" "$tmp/repo" 2>/dev/null && [[ -f $tmp/repo/$YAMIS_TARBALL ]]; then
        if yamis_archive_is_safe "$tmp/repo/$YAMIS_TARBALL"; then
            mkdir -p "$DATA/icons"
            if tar -xzf "$tmp/repo/$YAMIS_TARBALL" -C "$DATA/icons"; then
                command -v gtk-update-icon-cache >/dev/null 2>&1 && gtk-update-icon-cache -qf -t "$DATA/icons/YAMIS" 2>/dev/null
                note "Installed to $DATA/icons/YAMIS"
            else
                warn "Could not unpack the YAMIS archive."
            fi
        else
            warn "The YAMIS archive has an unexpected layout, so it was not installed."
        fi
    else
        warn "Could not download YAMIS (offline?). Apps use Papirus-Dark icons until the theme is in $DATA/icons/YAMIS."
    fi
    rm -rf "$tmp"
}

# ── 5. config files ──────────────────────────────────────────────────────────
CURSOR_THEME="Simp1e-Adw-Dark"      # must match CURSOR_THEME in hyprland.lua
# wallpapers earlier versions installed and this one no longer has (file:sha256)
RETIRED_WALLPAPERS=(waves.png:d0f02170190780643c6bae3665eb46754d1b3ef395ef61e473cbea036efd6f4e
    black-hole.png:2b6f65aa79e64bcdf9f4482d81d9f861a7e821b67c3a41caa9e5d8f0ae417e29
    dark-waves.png:a8ddd8c5112442ccdc12487ecbb2b847f6f2acd8185fffd2c02e38f323e0b1a5)

# The folder the cursor package really installed (the configs need its exact name).
# find_cursor_theme [folders to look in]  (default: your icons, then the system's)
find_cursor_theme() {
    local base dir name
    (($#)) || set -- "$DATA/icons" "$HOME/.icons" /usr/share/icons
    for base in "$@"; do
        for dir in "$base"/*/; do
            dir="${dir%/}"
            name="${dir##*/}"
            if [[ -d $dir/cursors && ${name,,} == "${CURSOR_THEME,,}" ]]; then
                printf '%s\n' "$name"
                return 0
            fi
        done
    done
    return 1
}

setup_cursor() {
    local found
    if found="$(find_cursor_theme)"; then
        if [[ $found != "$CURSOR_THEME" ]] && ((!DRY)); then
            note "The cursor theme folder is called '$found' - using that name in the configs"
            sed -i "s/$CURSOR_THEME/$found/g" "$CFG/hypr/hyprland.lua" "$CFG/gtk-3.0/settings.ini" "$CFG/gtk-4.0/settings.ini"
        fi
    else
        warn "Cursor theme $CURSOR_THEME not found (AUR package xcursor-simp1e-adw-dark): run ./install.sh without --no-packages, or 'paru -S xcursor-simp1e-adw-dark', then log out and back in. Until then you get the default cursor."
        found="$CURSOR_THEME"
    fi
    # inside a running Hyprland: switch to it now (Hyprland loads its cursor at login)
    if [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] && find_cursor_theme >/dev/null && ((!DRY)); then
        local size
        size="$(sed -n 's/^local CURSOR_SIZE *= *\([0-9][0-9]*\).*/\1/p' "$CFG/hypr/hyprland.lua" 2>/dev/null | head -n 1)"
        hyprctl setcursor "$found" "${size:-24}" >/dev/null 2>&1
        gsettings set org.gnome.desktop.interface cursor-theme "$found" >/dev/null 2>&1
    fi
    # for apps that only look at the "default" cursor theme (XWayland, older toolkits)
    local f="$DATA/icons/default/index.theme"
    if ((DRY)); then
        note "[dry-run] write $f (Inherits=$found, Size=24)"
        return 0
    fi
    backup "$f"
    mkdir -p "${f%/*}"
    printf '[Icon Theme]\nName=Default\nComment=Default cursor theme (set by frameshell)\nInherits=%s\nSize=24\n' "$found" >"$f"
}
# The whole computer's default cursor (/usr/share/icons/default/index.theme): Simp1e as
# well. Out of the box that file (package default-cursors) says "Inherits=Adwaita", so
# everything without a cursor theme of its own shows Adwaita: the login screen, other
# users, programs started outside your session. (Your session sets its cursor itself.)
# A pacman hook sets it again after an update of default-cursors put Adwaita back.
CURSOR_SCRIPT=/usr/local/lib/frameshell/default-cursor.sh
CURSOR_HOOK=/etc/pacman.d/hooks/zz-frameshell-cursor.hook
system_cursor_default() {
    local found f=/usr/share/icons/default/index.theme hook owner
    # other users and the login screen can only use it from /usr/share/icons
    if ! found="$(find_cursor_theme /usr/share/icons)"; then
        found="$(find_cursor_theme)" || return 0      # not installed at all: setup_cursor said so
        warn "$found is only in your home folder, so the login screen keeps the default cursor: install it for the whole computer ('paru -S xcursor-simp1e-adw-dark') and run ./install.sh again."
        return 0
    fi
    hook="$(printf '%s\n' \
        "# Written by frameshell's install.sh: keeps the computer's default mouse cursor" \
        "# $found when an update of default-cursors puts its own" \
        "# /usr/share/icons/default/index.theme back. Delete this file to stop that." \
        "" \
        "[Trigger]" \
        "Operation = Install" \
        "Operation = Upgrade" \
        "Operation = Remove" \
        "Type = Path" \
        "Target = usr/share/icons/default/index.theme" \
        "Target = usr/share/icons/$found/*" \
        "" \
        "[Action]" \
        "Description = Keeping the default mouse cursor $found (frameshell)..." \
        "When = PostTransaction" \
        "Exec = $CURSOR_SCRIPT $found")"
    # all three already in place: nothing to do (no sudo question)
    if grep -qsx "Inherits=$found" "$f" && grep -qsx "Size=24" "$f" && cmp -s "$HERE/extras/default-cursor/default-cursor.sh" "$CURSOR_SCRIPT" &&
        [[ "$(cat "$CURSOR_HOOK" 2>/dev/null)" == "$hook" ]]; then
        note "The computer's default cursor is $found already."
        return 0
    fi
    if ((DRY)); then
        [[ -f $f ]] || note "[dry-run] pacman -S default-cursors ($f comes with it)"
        note "[dry-run] install $CURSOR_SCRIPT and $CURSOR_HOOK, then set $f to Inherits=$found, Size=24"
        return 0
    fi
    need_sudo
    # only the package's own file is changed (one of our own there would block that package)
    if [[ ! -f $f ]] && pkg_available default-cursors; then
        run "${SUDO[@]}" pacman -S --needed "${NOCONF[@]}" default-cursors
    fi
    if [[ ! -f $f ]]; then
        warn "No $f (package default-cursors), so the computer's default cursor was not changed: 'sudo pacman -S default-cursors', then run ./install.sh again."
        return 0
    fi
    if [[ -e /usr/share/icons/default/cursors ]]; then
        warn "/usr/share/icons/default/cursors exists: its cursors win over the default theme ($found). Check 'pacman -Qo /usr/share/icons/default/cursors'."
    fi
    owner="$(pacman -Qoq "$f" 2>/dev/null)" || owner=""
    if "${SUDO[@]}" install -Dm755 "$HERE/extras/default-cursor/default-cursor.sh" "$CURSOR_SCRIPT" &&
        "${SUDO[@]}" mkdir -p "${CURSOR_HOOK%/*}" &&
        printf '%s\n' "$hook" | "${SUDO[@]}" tee "$CURSOR_HOOK" >/dev/null &&
        "${SUDO[@]}" "$CURSOR_SCRIPT" "$found" >/dev/null && grep -qsx "Inherits=$found" "$f" && grep -qsx "Size=24" "$f"; then
        note "The computer's default cursor is now $found, size 24 ($f)."
        [[ -e $f.frameshell-backup ]] && note "The one before is next to it: $f.frameshell-backup"
        note "A pacman hook keeps it that way after updates${owner:+ of $owner} ($CURSOR_HOOK)."
    else
        warn "Could not set the computer's default cursor in $f (see README.md, 'The mouse cursor')."
    fi
}

# The whole system in English (US): /etc/locale.conf is just "LANG=en_US.UTF-8"
# (the old one stays next to it as locale.conf.frameshell-backup). Takes effect at the
# next login / reboot.
system_locale() {
    local f=/etc/locale.conf line="LANG=en_US.UTF-8"
    [[ "$(cat "$f" 2>/dev/null)" == "$line" ]] && return 0
    if ((DRY)); then
        note "[dry-run] write $f: $line"
        return 0
    fi
    need_sudo
    # the language must exist on the system, or apps fall back to plain "C"
    if ! locale -a 2>/dev/null | grep -qix 'en_US\.utf-\{0,1\}8'; then
        "${SUDO[@]}" sed -i 's/^#[[:space:]]*\(en_US\.UTF-8 UTF-8\)/\1/' /etc/locale.gen
        grep -qx 'en_US.UTF-8 UTF-8' /etc/locale.gen || printf 'en_US.UTF-8 UTF-8\n' | "${SUDO[@]}" tee -a /etc/locale.gen >/dev/null
        "${SUDO[@]}" locale-gen >/dev/null || warn "locale-gen failed: run 'sudo locale-gen' yourself."
    fi
    [[ -e $f && ! -e $f.frameshell-backup ]] && "${SUDO[@]}" cp -p "$f" "$f.frameshell-backup"
    if printf '%s\n' "$line" | "${SUDO[@]}" tee "$f" >/dev/null; then
        note "System language: English (US) ($f: $line). Takes effect after a reboot."
    else
        warn "Could not write $f."
    fi
}

backup() {
    local p="$1" rel
    [[ -e $p || -L $p ]] || return 0
    rel="${p#"$CFG"/}"
    if ((DRY)); then
        note "[dry-run] back up $p"
        return 0
    fi
    mkdir -p "$BACKUP/$(dirname "$rel")"
    mv "$p" "$BACKUP/$rel"
    BACKED_UP=1
}

# every Firefox profile in profiles.ini (~/.mozilla/firefox, or ~/.config/mozilla/firefox for
# profiles made by Firefox 147 and later) - the same as in scripts/theme.sh
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

put() { # put <source file> <destination file> [mode]
    local src="$1" dst="$2" mode="${3:-644}"
    backup "$dst"
    run install -Dm"$mode" "$src" "$dst"
}

install_configs() {
    say "Installing config files (existing ones go to $BACKUP)"

    # Hyprland (Lua). An old hyprland.conf would only be confusing next to it.
    put "$HERE/config/hypr/hyprland.lua" "$CFG/hypr/hyprland.lua"
    put "$HERE/config/hypr/hypridle.conf" "$CFG/hypr/hypridle.conf"
    if [[ $CFG != "$HOME/.config" ]] && ((!DRY)); then
        # hypridle.conf names the lock script by its path
        sed -i "s|~/.config/|$CFG/|g" "$CFG/hypr/hypridle.conf"
    fi
    put "$HERE/config/hypr/hyprlock.conf" "$CFG/hypr/hyprlock.conf"
    backup "$CFG/hypr/hyprland.conf"

    # the shell
    backup "$CFG/quickshell/frame"
    run mkdir -p "$CFG/quickshell"
    run cp -a "$HERE/config/quickshell/frame" "$CFG/quickshell/frame"
    run chmod +x "$CFG/quickshell/frame/scripts/"*.sh

    # the shell's Settings app in the launcher (SUPER + R, "Settings") and its icon
    put "$HERE/config/applications/frame-settings.desktop" "$DATA/applications/frame-settings.desktop"
    put "$HERE/config/quickshell/frame/assets/icons/frame-settings.svg" "$DATA/icons/hicolor/scalable/apps/frame-settings.svg"

    # apps
    # rofi's config, installed by earlier versions (the shell has its own launcher): moved to
    # the backup folder - only the files that are ours
    local rasi
    for rasi in config.rasi frame.rasi; do
        if grep -qs -m1 '^/\* Frame - rofi' "$CFG/rofi/$rasi"; then
            backup "$CFG/rofi/$rasi"
        fi
    done
    # kitty: one config per colour theme (frame.conf = Default, frame-noir.conf, frame-mocha.conf);
    # kitty.conf is a link to the one of the shell's theme (scripts/theme.sh switches it, below)
    put "$HERE/config/kitty/frame.conf" "$CFG/kitty/frame.conf"
    put "$HERE/config/kitty/frame-noir.conf" "$CFG/kitty/frame-noir.conf"
    put "$HERE/config/kitty/frame-mocha.conf" "$CFG/kitty/frame-mocha.conf"
    if [[ -L $CFG/kitty/kitty.conf && "$(readlink "$CFG/kitty/kitty.conf")" == frame*.conf ]]; then
        run rm -f "$CFG/kitty/kitty.conf"       # the link an earlier install made
    else
        backup "$CFG/kitty/kitty.conf"
    fi
    run ln -s frame.conf "$CFG/kitty/kitty.conf"
    # Firefox: userChrome.css and userContent.css for each colour theme; scripts/theme.sh links
    # every profile's chrome/ ones to the shell's theme (below, and for a profile Firefox makes
    # later at the next start of the shell). The ones a profile has now go to the backup folder.
    local t f profile
    for t in Default Noir Mocha; do
        for f in userChrome.css userContent.css; do
            put "$HERE/config/firefox/$t/$f" "$CFG/frameshell/firefox/$t/$f"
        done
    done
    # Firefox's keyboard shortcuts (customKeys.json, next to the chrome folder) - only with
    # --firefox-keys: copied into every profile - Firefox rewrites the file when you change a
    # shortcut (about:keyboard), so it is a copy, not a link; another one a profile has goes to
    # the backup folder. A profile Firefox makes later gets it at the next start of the shell
    # (scripts/theme.sh, only while ~/.config/frameshell/firefox/customKeys.json is there).
    if ((DO_FIREFOX_KEYS)); then
        put "$HERE/config/firefox/customKeys.json" "$CFG/frameshell/firefox/customKeys.json"
    fi
    while IFS= read -r profile; do
        [[ -n $profile && -d $profile ]] || continue
        for f in userChrome.css userContent.css; do
            [[ -L $profile/chrome/$f && "$(readlink "$profile/chrome/$f")" == "$CFG/frameshell/firefox"/* ]] ||
                backup "$profile/chrome/$f"
        done
        if ((DO_FIREFOX_KEYS)) && ! cmp -s "$HERE/config/firefox/customKeys.json" "$profile/customKeys.json"; then
            backup "$profile/customKeys.json"
            run install -m644 "$HERE/config/firefox/customKeys.json" "$profile/customKeys.json"
        fi
    done < <(firefox_profiles)
    put "$HERE/config/fish/config.fish" "$CFG/fish/config.fish"
    put "$HERE/config/fastfetch/config.jsonc" "$CFG/fastfetch/config.jsonc"
    # Thunar's settings, installed by earlier versions (the file manager is Nautilus now):
    # moved to the backup folder
    backup "$CFG/xfce4/xfconf/xfce-perchannel-xml/thunar.xml"
    put "$HERE/config/gtk-3.0/settings.ini" "$CFG/gtk-3.0/settings.ini"
    put "$HERE/config/gtk-4.0/settings.ini" "$CFG/gtk-4.0/settings.ini"
    install_gtk_theme
    install_qt_theme
    put "$HERE/config/fontconfig/fonts.conf" "$CFG/fontconfig/fonts.conf"

    # Clarity City (also bundled inside the shell, installing it makes hyprlock / GTK use it too)
    say "Installing the Clarity City font"
    run mkdir -p "$DATA/fonts/frame"
    run cp -f "$HERE"/config/quickshell/frame/assets/fonts/*.otf "$HERE/config/quickshell/frame/assets/fonts/LICENSE-ClarityCity.txt" "$DATA/fonts/frame/"
    command -v fc-cache >/dev/null 2>&1 && run fc-cache -f "$DATA/fonts" >/dev/null 2>&1

    # wallpapers: SUPER + CTRL + Left / Right switches between the pictures in this folder.
    # The bundled ones are added; a picture of yours with the same name is kept.
    # (services/Wallpapers.qml lists them by name, `bundled`: the Settings app does not
    # offer to remove them.)
    local wdir="$DATA/frameshell/wallpapers" w old="$DATA/frameshell/wallpaper.png" sum
    run mkdir -p "$wdir"
    for w in "$HERE"/wallpapers/*; do
        [[ -e $wdir/${w##*/} ]] || run install -m644 "$w" "$wdir/${w##*/}"
    done
    # pictures an earlier version brought and this one doesn't: removed - but only if the
    # file is still exactly that picture (a picture of yours with the same name stays)
    for w in "${RETIRED_WALLPAPERS[@]}"; do
        [[ -f $wdir/${w%%:*} ]] || continue
        sum="$(sha256sum "$wdir/${w%%:*}")"
        [[ ${sum%% *} == "${w#*:}" ]] && run rm -f "$wdir/${w%%:*}"
    done
    # your own wallpaper from an earlier version (one picture in ~/.local/share/frameshell):
    # it joins the others as my-wallpaper.png and stays on screen
    if [[ -f $old ]] && ! cmp -s "$old" "$HERE/wallpapers/meadow.png"; then
        if [[ ! -e $wdir/my-wallpaper.png ]]; then
            run cp -p "$old" "$wdir/my-wallpaper.png"
            note "Your wallpaper is one of the choices now: $wdir/my-wallpaper.png"
        fi
        if [[ ! -s $STATE/frameshell/wallpaper ]] && ((!DRY)); then
            mkdir -p "$STATE/frameshell"
            printf '%s\n' "$wdir/my-wallpaper.png" >"$STATE/frameshell/wallpaper"
        fi
    fi

    # mouse cursor
    setup_cursor

    # let hyprland.lua apply the GTK dark-theme gsettings once on the next login
    run rm -f "$STATE/frameshell/gsettings"
    run mkdir -p "$HOME/Pictures/Screenshots"
    default_file_manager
    default_video_player
    default_code_apps
    rename_apps
}

# The "Frame" GTK themes (themes/Frame, Frame-Noir, Frame-Mocha - the shell's Default, Noir and
# Mocha colour themes): adw-gtk3-dark's shapes in the shell's colours, for GTK 3 apps (pavucontrol,
# file pickers ...) and plain GTK 4 apps. libadwaita apps (Nautilus ...) never load a theme; they get
# the same colours from ~/.config/gtk-4.0/gtk.css. The shell switches between them (scripts/theme.sh).
install_gtk_theme() {
    local t
    run mkdir -p "$DATA/themes"
    for t in Frame Frame-Noir Frame-Mocha; do
        backup "$DATA/themes/$t"
        run cp -a "$HERE/themes/$t" "$DATA/themes/$t"
    done
    put "$HERE/config/gtk-4.0/gtk.css" "$CFG/gtk-4.0/gtk.css"
    # gtk.css finds colors.css by a relative path: fix it up for non-default XDG folders
    local def="../../.local/share/themes/Frame/gtk-4.0/colors.css" rel css
    rel="$(realpath -sm --relative-to="$CFG/gtk-4.0" "$DATA/themes/Frame/gtk-4.0/colors.css")"
    if [[ -n $rel && $rel != "$def" ]] && ((!DRY)); then
        css="$(<"$CFG/gtk-4.0/gtk.css")"
        printf '%s\n' "${css//"$def"/"$rel"}" >"$CFG/gtk-4.0/gtk.css"
    fi
    # GTK 3's own file: only hides the title-bar buttons. An old one (Gradience, adw-colors ...)
    # would paint over the theme: it goes to the backup folder.
    put "$HERE/config/gtk-3.0/gtk.css" "$CFG/gtk-3.0/gtk.css"
    if [[ ! -f /usr/share/themes/adw-gtk3-dark/gtk-3.0/gtk.css ]]; then
        warn "adw-gtk3-dark is not installed (package adw-gtk-theme): the Frame GTK theme is built on it, GTK apps look unstyled until it is."
    fi
    # GTK apps that are running switch right away (the next login sets it anyway)
    if ((!DRY)) && command -v gsettings >/dev/null 2>&1 && busctl --user status >/dev/null 2>&1; then
        gsettings set org.gnome.desktop.interface gtk-theme Frame >/dev/null 2>&1 || true
    fi
}

# Qt 5 and Qt 6 apps: the Kvantum style with the Frame themes (themes/Kvantum/Frame, FrameNoir,
# FrameMocha), their palettes, YAMIS and Clarity City - qt5ct for Qt 5, qt6ct for Qt 6 (hyprland.lua
# points Qt at them)
install_qt_theme() {
    local v t c
    run mkdir -p "$CFG/Kvantum"
    for t in Frame FrameNoir FrameMocha; do
        backup "$CFG/Kvantum/$t"
        run cp -a "$HERE/themes/Kvantum/$t" "$CFG/Kvantum/$t"
    done
    put "$HERE/config/Kvantum/kvantum.kvconfig" "$CFG/Kvantum/kvantum.kvconfig"
    for v in 5 6; do
        put "$HERE/config/qt${v}ct/qt${v}ct.conf" "$CFG/qt${v}ct/qt${v}ct.conf"
        for c in frame frame-noir frame-mocha; do
            put "$HERE/config/qt${v}ct/colors/$c.conf" "$CFG/qt${v}ct/colors/$c.conf"
        done
        if ((!DRY)); then
            # qt5ct / qt6ct want absolute paths
            sed -i "s|~/.config/|$CFG/|g" "$CFG/qt${v}ct/qt${v}ct.conf"
        fi
    done
    # the shell's colour theme picked earlier (SUPER + CTRL + Up / Down): GTK and Qt apps follow it
    # again (the files above are the Default theme's)
    if ((!DRY)) && [[ -s $STATE/frameshell/theme && -f $CFG/quickshell/frame/scripts/theme.sh ]]; then
        bash "$CFG/quickshell/frame/scripts/theme.sh" "$(head -n1 "$STATE/frameshell/theme")" || true
    fi
}

# ~/.config/hyprland-mimeapps.list (if some tool made one) wins over ~/.config/mimeapps.list,
# where xdg-mime writes: take the lines matching the pattern out of it. The original file goes
# to the backup folder once per run.
drop_hyprland_mime_lines() { # drop_hyprland_mime_lines <grep -E pattern>
    local hl="$CFG/hyprland-mimeapps.list" kept
    [[ -f $hl ]] && grep -qE "$1" "$hl" || return 0
    if ((DRY)); then
        note "[dry-run] remove the lines matching $1 from $hl"
        return 0
    fi
    kept="$(grep -vE "$1" "$hl")"
    if [[ -e $BACKUP/hyprland-mimeapps.list ]]; then
        printf '%s\n' "$kept" >"$hl"
    else
        backup "$hl"
        printf '%s\n' "$kept" >"$hl"
    fi
}

# Celluloid (a GTK front end for mpv) opens videos: every video type it can play, plus the
# few video formats filed under application/ (Matroska, Flash video, RealMedia, DVDs).
# Music and streams keep whatever opens them now.
default_video_player() {
    say "Making Celluloid the default video player"
    local desktop="" d types=() t
    for d in io.github.celluloid_player.Celluloid.desktop celluloid.desktop; do
        if [[ -e /usr/share/applications/$d ]]; then
            desktop="$d"
            break
        fi
    done
    if [[ -z $desktop ]]; then
        warn "Celluloid's menu entry was not found, so it is not the default video player yet (install celluloid and run ./install.sh again)."
        return
    fi
    if ! command -v xdg-mime >/dev/null 2>&1; then
        warn "xdg-mime is missing (package xdg-utils), so videos may not open in Celluloid."
        return
    fi
    # the types from Celluloid's own menu entry, so new ones come with updates
    while IFS= read -r t; do
        case "$t" in
        video/* | application/x-matroska | application/x-flash-video | application/x-extension-mp4 | \
            application/vnd.rn-realmedia | application/vnd.rn-realmedia-vbr | x-content/video-dvd)
            types+=("$t") ;;
        esac
    done < <(sed -n 's/^MimeType=//p' "/usr/share/applications/$desktop" | head -n 1 | tr ';' '\n')
    if ((${#types[@]} == 0)); then
        warn "Celluloid's menu entry lists no video types, so it was not made the default video player."
        return
    fi
    run xdg-mime default "$desktop" "${types[@]}"
    note "Celluloid opens ${#types[@]} video types."
    drop_hyprland_mime_lines '^(video/|application/x-matroska=|application/x-flash-video=|application/x-extension-mp4=|application/vnd\.rn-realmedia(-vbr)?=|x-content/video-dvd=)'
}

# Code opens in VS Code, plain text (.txt, logs, READMEs) in GNOME Text Editor. The type names are
# the freedesktop ones (see /usr/share/mime/types); config/mime/frameshell-code.xml adds the
# code files the system doesn't know (.tsx, .vue, .zig, Dockerfile ...), which would otherwise
# count as plain text, and config files (.conf, .ini, .env, .gitignore, .bashrc ...), which are
# text/x-config there.
CODE_TYPES=(
    # C family, JVM, .NET, systems languages
    text/x-csrc text/x-chdr text/x-c++src text/x-c++hdr text/x-objcsrc text/x-objc++src
    text/x-csharp text/x-java text/x-kotlin text/x-scala text/x-groovy text/x-gradle
    text/x-go text/rust text/x-zig text/x-swift text/x-dsrc text/x-nim text/x-nimscript
    text/x-crystal text/x-vala text/x-genie text/x-opencl-src text/x-verilog text/x-vhdl
    text/x-svsrc text/x-svhdr text/x-fortran text/x-pascal text/x-adasrc text/x-cobol
    # scripting and functional languages
    text/x-python text/x-python3 application/x-ruby application/x-perl application/x-php
    text/x-lua text/tcl text/julia text/x-r text/x-matlab text/x-sagemath
    text/x-haskell text/x-literate-haskell text/x-ocaml text/x-erlang text/x-elixir
    text/x-scheme text/x-common-lisp text/x-emacs-lisp text/x-basic text/x-vb text/vbscript
    application/vnd.dart application/x-awk application/x-m4 text/x-vim
    # shells
    application/x-shellscript application/x-csh application/x-fishscript
    application/x-powershell application/x-bat
    # web
    text/html text/htmlh application/xhtml+xml text/css text/x-scss text/x-sass
    text/javascript application/javascript application/x-javascript text/x-jsx
    text/x-typescript text/x-tsx text/x-vue text/x-svelte text/x-twig application/x-asp
    text/x-graphql
    # data, markup and build files
    application/json application/json5 application/ld+json application/schema+json
    text/x-jsonc application/x-ipynb+json application/xml text/xml application/xml-dtd
    application/xslt+xml application/yaml application/x-yaml application/toml
    application/sql text/x-protobuf text/markdown text/x-rst text/org text/x-tex
    text/x-bibtex text/x-typst text/x-makefile text/x-cmake text/x-meson text/x-scons
    text/x-dockerfile text/x-nix text/x-terraform text/x-rpm-spec text/x-systemd-unit
    text/x-qml text/x-blueprint application/x-gtk-builder application/x-designer
    application/x-desktop text/x-patch text/x-reject text/x-gettext-translation
    text/x-gettext-translation-template text/vnd.trolltech.linguist text/x-idl
    text/x-devicetree-source application/x-godot-shader application/x-code-workspace
    # config files
    text/x-config text/x-dbus-service text/x-iptables
)
TEXT_TYPES=(text/plain text/x-log text/x-readme text/x-authors text/x-copying text/x-credits
    text/x-changelog text/x-install text/x-todo-txt text/x-nfo)

# the first menu entry found
first_desktop() { # first_desktop <name.desktop> ...
    local d
    for d in "$@"; do
        [[ -e /usr/share/applications/$d ]] && { printf '%s\n' "$d"; return 0; }
    done
    return 1
}

default_code_apps() {
    say "Code files open in VS Code, text files in GNOME Text Editor"
    if ! command -v xdg-mime >/dev/null 2>&1; then
        warn "xdg-mime is missing (package xdg-utils), so code and text files keep their apps."
        return
    fi
    # the extra code file types
    put "$HERE/config/mime/frameshell-code.xml" "$DATA/mime/packages/frameshell-code.xml"
    if command -v update-mime-database >/dev/null 2>&1; then
        run update-mime-database "$DATA/mime" >/dev/null
    fi
    local code text re
    if code="$(first_desktop code.desktop code-oss.desktop codium.desktop visual-studio-code.desktop)"; then
        run xdg-mime default "$code" "${CODE_TYPES[@]}"
    else
        warn "VS Code's menu entry was not found, so code files keep their apps (install visual-studio-code-bin and run ./install.sh again)."
    fi
    if text="$(first_desktop org.gnome.TextEditor.desktop)"; then
        run xdg-mime default "$text" "${TEXT_TYPES[@]}"
    else
        warn "GNOME Text Editor's menu entry was not found, so .txt files keep their app (install gnome-text-editor and run ./install.sh again)."
    fi
    # the same lines in a Hyprland-only list would win: take them out
    re="$(printf '%s\n' "${CODE_TYPES[@]}" "${TEXT_TYPES[@]}" | sed 's/[.+]/\\&/g' | paste -sd '|')"
    drop_hyprland_mime_lines "^($re)="
}

# App names: four apps go by plain names everywhere - the launcher, the app switcher, the
# bottom bar and other apps' menus. For each one its own menu entry (the .desktop file in
# /usr/share/applications) is copied to ~/.local/share/applications with only the name
# changed (that copy wins over the original). An app whose entry already has the name
# (Nautilus is "Files", GNOME Text Editor "Text Editor") keeps its own entry. The copies are
# made again on every install, from the apps' current entries.
APP_NAMES=(
    "io.missioncenter.MissionCenter:System Monitor"
    "kitty:Terminal"
    "org.gnome.Nautilus:Files"
    "org.gnome.TextEditor:Text Editor"
)
APP_NAME_MARK="# frameshell (install.sh):"

rename_apps() {
    say "App names: Mission Center -> System Monitor, kitty -> Terminal, Nautilus -> Files, GNOME Text Editor -> Text Editor"
    local pair id name src own d cur tmp
    local -a dirs=()
    IFS=: read -ra dirs <<<"${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
    for pair in "${APP_NAMES[@]}"; do
        id="${pair%%:*}" name="${pair#*:}"
        own="$DATA/applications/$id.desktop"
        # the app's own entry
        src=""
        for d in "${dirs[@]}"; do
            [[ $d == "$DATA" ]] && continue
            if [[ -f $d/applications/$id.desktop ]]; then
                src="$d/applications/$id.desktop"
                break
            fi
        done
        # a copy made by an earlier install is not needed when the app is gone or already has the name
        if [[ -z $src ]]; then
            app_name_copy "$own" && run rm -f "$own"
            warn "No menu entry $id.desktop (is the app installed?), so it is not called \"$name\" yet: install it and run ./install.sh again."
            continue
        fi
        # its name (the Name= line of [Desktop Entry], not of its actions)
        cur="$(awk '/^\[/ { main = ($0 == "[Desktop Entry]") } main && /^Name[ \t]*=/ { sub(/^Name[ \t]*=[ \t]*/, ""); print; exit }' "$src")"
        if [[ $cur == "$name" ]]; then
            app_name_copy "$own" && run rm -f "$own"
            note "$name: already called that."
            continue
        fi
        # a copy of your own goes to the backup folder
        app_name_copy "$own" || backup "$own"
        if ((DRY)); then
            note "[dry-run] $own: $src with the name \"$name\""
            continue
        fi
        mkdir -p "$DATA/applications"
        tmp="$(mktemp "$DATA/applications/.$id.XXXXXX")" || {
            warn "Could not write $own."
            continue
        }
        if {
            printf '%s %s with the name "%s".\n' "$APP_NAME_MARK" "$src" "$name"
            printf '# Made again every time install.sh runs (APP_NAMES there). Delete this file to get the name "%s" back.\n' "$cur"
            # the [Desktop Entry] name becomes the new one; its translations go (they would
            # show the old name in another language); actions keep their names
            awk -v name="$name" '
                /^\[/ { main = ($0 == "[Desktop Entry]") }
                main && /^Name\[/ { next }
                main && /^Name[ \t]*=/ { print "Name=" name; next }
                { print }
            ' "$src"
        } >"$tmp" && chmod 644 "$tmp" && mv -f "$tmp" "$own"; then
            note "$cur is called \"$name\" now."
        else
            rm -f "$tmp"
            warn "Could not write $own."
        fi
    done
}

# a copy made by rename_apps (it starts with its mark)
app_name_copy() { # app_name_copy <file>
    local first=""
    [[ -f $1 ]] || return 1
    IFS= read -r first <"$1" || true
    [[ $first == "$APP_NAME_MARK"* ]]
}

# Nautilus is the file manager everywhere: folders open in it ("open folder" in any app,
# xdg-open ~/Downloads) and "Show in folder" / "show the file" requests go to it.
default_file_manager() {
    say "Making Nautilus the default file manager"
    local desktop="" d
    for d in org.gnome.Nautilus.desktop nautilus.desktop; do
        if [[ -e /usr/share/applications/$d ]]; then
            desktop="$d"
            break
        fi
    done
    if [[ -z $desktop ]]; then
        warn "Nautilus's menu entry was not found, so it is not the default file manager yet (install nautilus and run ./install.sh again)."
        return
    fi
    # folders (written to ~/.config/mimeapps.list)
    if command -v xdg-mime >/dev/null 2>&1; then
        run xdg-mime default "$desktop" inode/directory
    else
        warn "xdg-mime is missing (package xdg-utils), so folders may not open in Nautilus."
    fi
    # a Hyprland-only list (~/.config/hyprland-mimeapps.list) would win over that one
    drop_hyprland_mime_lines '^inode/directory='
    # "show this file in the file manager" (D-Bus FileManager1): Nautilus, also when other
    # file managers are installed; the session bus reads it again right away
    put "$HERE/config/dbus/org.freedesktop.FileManager1.service" "$DATA/dbus-1/services/org.freedesktop.FileManager1.service"
    if ((!DRY)) && command -v busctl >/dev/null 2>&1; then
        busctl --user call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus ReloadConfig >/dev/null 2>&1 || true
    fi
}

# ── 6. login screen: SDDM with the Pixie theme ───────────────────────────────
# Pixie (github.com/xCaptaiN09/pixie-sddm, MIT, by xCaptaiN09) is bundled in
# extras/pixie-sddm. The lock screen of the shell reads the same theme folder,
# so the login screen and the lock screen look the same.
PIXIE_DIR=/usr/share/sddm/themes/pixie
SDDM_CONF=/etc/sddm.conf.d/zz-frameshell.conf     # "zz": read last, so it wins over other files there

# height in pixels of the first connected screen (its preferred mode), e.g. 2160
screen_height() {
    local s m
    for s in /sys/class/drm/card*-*/status; do
        [[ $(cat "$s" 2>/dev/null) == connected ]] || continue
        m="$(head -n1 "${s%/status}/modes" 2>/dev/null)"
        if [[ $m =~ ^[0-9]+x([0-9]+) ]]; then
            printf '%s\n' "${BASH_REMATCH[1]}"
            return 0
        fi
    done
    return 1
}

# theme.conf files shipped before (Pixie's original): replaced by the new one,
# any other existing theme.conf has your edits and is kept
OLD_THEME_CONFS=(28e2c74628baf35b6def6c6fd5f3278442fa4a1f9ca6dae5c5170322170ccb0a b7ffa5aa92e019cf11c210b767147d78a5abc48ad1c6e047883beaaa50854d97 4768dcbd3738c74973522f2aeb7df5cdf6978ead057aa633ea38dd4d8589c763 69d5154c7b8e141df200730439b72dee70fece25ff96faaebd37c164abd95d79 54caa0a9a5d26609b451b3f18a89485f67d0e6176330628d41736c5f078793e2)

# copy a bundled theme folder to a system folder
install_theme_dir() { # install_theme_dir <source folder> <destination folder>
    local src="$1" dst="$2" f rel sum new
    while IFS= read -r -d '' f; do
        rel="${f#"$src"/}"
        if [[ $rel == theme.conf && -e $dst/theme.conf ]]; then
            sum="$(sha256sum "$dst/theme.conf" 2>/dev/null)"
            sum="${sum%% *}"
            new="$(sha256sum "$f")"
            new="${new%% *}"
            if [[ $sum != "$new" && " ${OLD_THEME_CONFS[*]} " != *" $sum "* ]]; then
                note "Keeping your edited $dst/theme.conf; the new one is next to it as theme.conf.new"
                run "${SUDO[@]}" install -Dm644 "$f" "$dst/theme.conf.new" || return 1
                continue
            fi
        fi
        run "${SUDO[@]}" install -Dm644 "$f" "$dst/$rel" || return 1
    done < <(find "$src" -type f ! -name SOURCE.txt -print0)
}

# An earlier frameshell version could log you in by itself (SDDM autologin into a
# session started locked). That is gone: remove its two files if they are still
# there, so SDDM asks for your password again. Only files written by frameshell
# (they start with its comment) are touched.
remove_old_autologin() {
    local f
    local -a old=()
    for f in /etc/sddm.conf.d/zz-frameshell-autologin.conf /usr/local/share/wayland-sessions/frameshell.desktop; do
        grep -qs "Written by frameshell's install.sh" "$f" && old+=("$f")
    done
    ((${#old[@]})) || return 0
    need_sudo
    if run "${SUDO[@]}" rm -f "${old[@]}"; then
        note "Removed the automatic login of an earlier version: SDDM asks for your password again."
    else
        warn "Could not remove ${old[*]} (the automatic login of an earlier version): delete them with sudo."
    fi
}

login_screen_setup() {
    remove_old_autologin
    say "Login screen: SDDM with the Pixie theme (the lock screen looks the same)"
    note "Pixie by xCaptaiN09 (MIT) is bundled in extras/pixie-sddm and goes to $PIXIE_DIR."
    if ! ask "Install it and make it your login screen (from the next boot on)?"; then
        warn "Skipped the login screen. The lock screen still works, with your desktop wallpaper, until Pixie is in $PIXIE_DIR."
        return
    fi
    need_sudo

    # SDDM draws its login screen with X11 (xorg-server); Pixie needs Qt 6 QML + SVG;
    # xsetroot + xrdb are how SDDM gives the login screen its cursor (CursorTheme below):
    # without them it shows the plain default cursor
    local -a pk=()
    local p
    for p in sddm qt6-declarative qt6-svg xorg-server xorg-xsetroot xorg-xrdb; do
        pkg_installed "$p" || pk+=("$p")
    done
    if ((${#pk[@]})); then
        run "${SUDO[@]}" pacman -S --needed "${NOCONF[@]}" "${pk[@]}" || {
            warn "Could not install ${pk[*]}, so the login screen was not changed."
            return
        }
    fi

    install_theme_dir "$HERE/extras/pixie-sddm" "$PIXIE_DIR" || {
        warn "Could not copy the Pixie theme to $PIXIE_DIR."
        return
    }

    # the desktop wallpaper as the background (theme.conf: background=assets/wallpaper.png).
    # SDDM can't read your home folder, so it gets a copy - the wallpaper you picked
    # (~/.local/state/frameshell/wallpaper), else the default. The copy belongs to you:
    # when you pick another wallpaper (SUPER + CTRL + Left / Right) the shell replaces it
    # (scripts/wallpaper.sh), so the login screen always shows your wallpaper.
    local wall="" picked
    picked="$(head -n1 "$STATE/frameshell/wallpaper" 2>/dev/null)"
    for p in "$picked" "$DATA/frameshell/wallpapers/meadow.png" "$HERE/wallpapers/meadow.png"; do
        if [[ -n $p && -f $p ]]; then wall="$p"; break; fi
    done
    if run "${SUDO[@]}" install -Dm644 -o "$ME" -g "$(id -gn)" "$wall" "$PIXIE_DIR/assets/wallpaper.png"; then
        note "Background of the login and lock screen: your desktop wallpaper ($wall). It follows when you switch (SUPER + CTRL + Left / Right)."
    else
        warn "Could not copy the wallpaper to $PIXIE_DIR/assets/wallpaper.png."
    fi

    # the login colours of the shell's colour theme (loginBackground ... in Config.qml): the
    # shell writes them into theme.conf.user, which wins over theme.conf (services/Themes.qml).
    # Like the wallpaper copy, the file belongs to you, so switching themes needs no password.
    if [[ -f $PIXIE_DIR/theme.conf.user && -O $PIXIE_DIR/theme.conf.user ]] ||
        run "${SUDO[@]}" install -m644 -o "$ME" -g "$(id -gn)" /dev/null "$PIXIE_DIR/theme.conf.user"; then
        note "Colours of the login and lock screen: the colour theme's (loginBackground ... in Config.qml)."
    else
        warn "Could not make $PIXIE_DIR/theme.conf.user: the login screen keeps the colours of its theme.conf."
    fi

    # your picture (Pixie shows assets/avatar.jpg; without one - or with an empty one - the first
    # letter of your name). Like the wallpaper's copy, the file is yours: the Settings app's Profile
    # card (System page, "Change picture") replaces it without a password.
    local face=""
    for p in "$HOME/.face" "$HOME/.face.icon"; do
        if [[ -s $p ]]; then face="$p"; break; fi
    done
    if [[ -n $face ]]; then
        run "${SUDO[@]}" install -Dm644 -o "$ME" -g "$(id -gn)" "$face" "$PIXIE_DIR/assets/avatar.jpg"
        note "Your picture ($face) is on the login and lock screen."
    else
        if [[ ! -e $PIXIE_DIR/assets/avatar.jpg ]]; then
            run "${SUDO[@]}" install -Dm644 -o "$ME" -g "$(id -gn)" /dev/null "$PIXIE_DIR/assets/avatar.jpg"
        elif [[ ! -O $PIXIE_DIR/assets/avatar.jpg ]]; then
            run "${SUDO[@]}" chown "$ME:$(id -gn)" "$PIXIE_DIR/assets/avatar.jpg"
        fi
        if [[ ! -s $PIXIE_DIR/assets/avatar.jpg ]]; then
            note "No picture: the login and lock screen show the first letter of your name."
            note "To add one: the Settings app, System page, Change picture."
        fi
    fi

    # Pixie is drawn for 1080p: scale it to the screen (4K -> 2), cursor to match
    local h scale cursor theme
    h="$(screen_height)" || h=1080
    scale="$(awk -v h="$h" 'BEGIN { s = h / 1080; if (s < 1) s = 1; printf "%.2f", s }')"
    scale="${scale%.00}"
    cursor="$(awk -v s="$scale" 'BEGIN { printf "%d", 24 * s + 0.5 }')"
    theme="$(find_cursor_theme)" || theme="$CURSOR_THEME"
    note "Screen height ${h}px: login screen scale $scale, cursor $theme ${cursor}px."

    # keep what other SDDM config files put in GreeterEnvironment (e.g. for a
    # Wayland greeter), with Pixie's scale added
    local f line prev="" genv="QT_SCALE_FACTOR=$scale" item
    local -a items=()
    for f in /usr/lib/sddm/sddm.conf.d/*.conf /etc/sddm.conf.d/*.conf; do
        [[ -f $f && $f != "$SDDM_CONF" ]] || continue
        line="$(grep -sE '^[[:space:]]*GreeterEnvironment=' "$f" | tail -n1)"
        [[ -n $line ]] && prev="${line#*=}"
    done
    IFS=',' read -ra items <<<"$prev"
    for item in "${items[@]}"; do
        item="${item//[[:space:]]/}"
        [[ -n $item && $item != QT_SCALE_FACTOR=* ]] && genv+=",$item"
    done

    local conf
    conf="$(printf '%s\n' \
        "# Written by frameshell's install.sh: the Pixie login screen." \
        "# Delete this file to get SDDM's default look back." \
        "" \
        "[General]" \
        "# Pixie is drawn for a 1080p screen: scale it to this one (2 = 4K)" \
        "GreeterEnvironment=$genv" \
        "# no on-screen keyboard popping up" \
        "InputMethod=" \
        "# Num Lock on, like in Hyprland" \
        "Numlock=on" \
        "" \
        "[Theme]" \
        "Current=pixie" \
        "CursorTheme=$theme" \
        "CursorSize=$cursor")"
    if ((DRY)); then
        note "[dry-run] write $SDDM_CONF:"
        sed 's/^/        /' <<<"$conf"
    else
        "${SUDO[@]}" mkdir -p "${SDDM_CONF%/*}"
        printf '%s\n' "$conf" | "${SUDO[@]}" tee "$SDDM_CONF" >/dev/null
    fi
    if grep -qsE '^[[:space:]]*(Current|GreeterEnvironment)=' /etc/sddm.conf; then
        warn "/etc/sddm.conf has its own 'Current=' or 'GreeterEnvironment=' line, which wins over $SDDM_CONF: remove it to see Pixie at the right size."
    fi
    if grep -qsE '^[[:space:]]*Cursor(Theme|Size)=' /etc/sddm.conf; then
        warn "/etc/sddm.conf has its own 'CursorTheme=' or 'CursorSize=' line, which wins over $SDDM_CONF: remove it to get $theme on the login screen."
    fi

    # first boot: Hyprland and you preselected (SDDM remembers your choice after that)
    local sess=""
    for p in /usr/share/wayland-sessions/hyprland.desktop /usr/share/wayland-sessions/hyprland-uwsm.desktop; do
        if [[ -f $p ]]; then sess="$p"; break; fi
    done
    if [[ -n $sess && ! -s /var/lib/sddm/state.conf ]] && getent passwd sddm >/dev/null; then
        if ((DRY)); then
            note "[dry-run] write /var/lib/sddm/state.conf (session $sess, user $ME)"
        else
            printf '[Last]\nSession=%s\nUser=%s\n' "$sess" "$ME" | "${SUDO[@]}" tee /var/lib/sddm/state.conf >/dev/null
            "${SUDO[@]}" chown sddm:sddm /var/lib/sddm/state.conf 2>/dev/null || true
        fi
    fi

    # make SDDM the login manager (only from the next boot on: the running one is not touched)
    local current=""
    if [[ -L /etc/systemd/system/display-manager.service ]]; then
        current="$(readlink /etc/systemd/system/display-manager.service)"
        current="${current##*/}"
    fi
    if [[ $current == sddm.service ]]; then
        note "SDDM already is your login manager."
        return
    fi
    if [[ -n $current ]]; then
        run "${SUDO[@]}" systemctl disable "$current" || warn "Could not disable $current."
    fi
    if run "${SUDO[@]}" systemctl enable sddm.service || run "${SUDO[@]}" systemctl enable --force sddm.service; then
        LOGIN_SWITCHED="$current"
        [[ -n $current ]] || LOGIN_SWITCHED="none"
        note "From the next boot on, SDDM with Pixie is your login screen."
        [[ -n $current ]] && note "To go back: sudo systemctl disable sddm && sudo systemctl enable $current"
    else
        warn "Could not enable sddm.service. Your old login screen stays${current:+ (}${current}${current:+)}."
        [[ -n $current ]] && run "${SUDO[@]}" systemctl enable "$current"
    fi
}

# ── 7. boot screen: Plymouth theme arch-darwin ──────────────────────────────
# arch-darwin (github.com/armoredvortex/plymouth-theme-arch-darwin, MIT, by
# ArmoredVortex) is bundled in extras/plymouth-arch-darwin.
DARWIN_DIR=/usr/share/plymouth/themes/arch-darwin

disk_is_encrypted() {
    local types
    grep -qsE 'cryptdevice=|rd\.luks|luks\.uuid' /proc/cmdline && return 0
    command -v lsblk >/dev/null 2>&1 || return 1
    types="$(lsblk -rno TYPE 2>/dev/null)"      # (read first: a pipe into grep -q can fail under pipefail)
    grep -qx crypt <<<"$types"
}

boot_splash_setup() {
    say "Boot screen: Plymouth theme 'arch-darwin' instead of the CachyOS one"
    note "arch-darwin by ArmoredVortex (MIT) is bundled in extras/plymouth-arch-darwin and goes to $DARWIN_DIR."
    if ! command -v plymouth-set-default-theme >/dev/null 2>&1; then
        warn "Plymouth is not installed, so there is no boot screen to change (sudo pacman -S plymouth, then run the installer again)."
        return
    fi
    local def=y
    if disk_is_encrypted; then
        note "Your disk is encrypted: arch-darwin has no password box. The password prompt still works,"
        note "but you type it without seeing dots. Say no to keep your current boot screen."
        def=n
    fi
    if ! ask "Install arch-darwin as your boot screen?" "$def"; then
        note "Skipped: the boot screen stays as it is."
        return
    fi
    need_sudo

    install_theme_dir "$HERE/extras/plymouth-arch-darwin" "$DARWIN_DIR" || {
        warn "Could not copy the theme to $DARWIN_DIR."
        return
    }
    run "${SUDO[@]}" plymouth-set-default-theme arch-darwin || {
        warn "plymouth-set-default-theme failed: the boot screen was not changed."
        return
    }

    # the theme is part of the initramfs: build it again
    if command -v limine-mkinitcpio >/dev/null 2>&1; then
        run "${SUDO[@]}" limine-mkinitcpio || warn "limine-mkinitcpio failed — run it again yourself, the new boot screen shows after that."
    elif command -v mkinitcpio >/dev/null 2>&1; then
        if ! grep -qsE '^[[:space:]]*HOOKS=.*\bplymouth\b' /etc/mkinitcpio.conf /etc/mkinitcpio.conf.d/*.conf; then
            warn "'plymouth' is not in the HOOKS of /etc/mkinitcpio.conf, so no boot screen is shown at all (Arch wiki: Plymouth)."
        fi
        run "${SUDO[@]}" mkinitcpio -P || warn "mkinitcpio -P failed — run it again yourself, the new boot screen shows after that."
    elif command -v dracut >/dev/null 2>&1; then
        warn "dracut system: rebuild your initramfs the way CachyOS tells you to (e.g. 'sudo dracut-rebuild') to see the new boot screen."
    else
        warn "No mkinitcpio / dracut found: rebuild your initramfs yourself to see the new boot screen."
    fi
    # (booting with GRUB and splash in /etc/default/grub: the next boot has it)
    grep -qsw splash /proc/cmdline ||
        { [[ -f $GRUB_CFG ]] && grep -qsE '^[[:space:]]*GRUB_CMDLINE_LINUX(_DEFAULT)?=.*\bsplash\b' "$GRUB_FILE"; } ||
        warn "'splash' is not on the kernel command line, so Plymouth stays hidden: add 'quiet splash' to your boot loader's kernel options."
    note "To go back to the CachyOS boot screen: sudo plymouth-set-default-theme -l (lists them), then"
    note "sudo plymouth-set-default-theme <name> and rebuild the initramfs the same way."
}

# ── 7b. GRUB: hide the boot menu (only with --grub) ──────────────────────────
# Changes three settings in /etc/default/grub and leaves everything else in it alone
# (kernel options, encryption, theme, other systems): the menu is hidden
# (GRUB_TIMEOUT_STYLE=hidden; for GRUB_HIDDEN_WAIT seconds Esc still shows it) and the boot
# is quiet, with the boot screen ('quiet splash' added to GRUB_CMDLINE_LINUX_DEFAULT when
# missing). grub.cfg is then made again (grub-mkconfig). The file before the first change
# stays next to it as /etc/default/grub.frameshell-backup.
GRUB_FILE=/etc/default/grub
GRUB_CFG=/boot/grub/grub.cfg
GRUB_HIDDEN_WAIT=1          # seconds GRUB waits for Esc (shows the menu) before it starts

# grub_set <KEY> <value>: KEY=value in $GRUB_FILE - on the line that sets it, else on a
# commented-out one, else on a new line at the end
grub_set() {
    local k="$1" v="$2" e
    e="$(printf '%s' "$k=$v" | sed -e 's/[\\|&]/\\&/g')"
    if grep -qE "^[[:space:]]*$k=" "$GRUB_FILE"; then
        "${SUDO[@]}" sed -i -E "s|^[[:space:]]*$k=.*|$e|" "$GRUB_FILE"
    elif grep -qE "^[[:space:]]*#[[:space:]]*$k=" "$GRUB_FILE"; then
        "${SUDO[@]}" sed -i -E "0,/^[[:space:]]*#[[:space:]]*$k=.*/s||$e|" "$GRUB_FILE"
    else
        printf '%s\n' "$k=$v" | "${SUDO[@]}" tee -a "$GRUB_FILE" >/dev/null
    fi
}

# the kernel options of GRUB_CMDLINE_LINUX_DEFAULT in $GRUB_FILE
grub_cmdline_default() {
    (
        set +u -f
        GRUB_CMDLINE_LINUX_DEFAULT=""
        # shellcheck disable=SC1090
        . "$GRUB_FILE" >/dev/null 2>&1
        printf '%s' "$GRUB_CMDLINE_LINUX_DEFAULT"
    )
}

grub_setup() {
    local f="$GRUB_FILE" cmd add="" w others=0
    say "GRUB: hide the boot menu, quiet boot ($f)"
    if ! command -v grub-mkconfig >/dev/null 2>&1 || [[ ! -f $GRUB_CFG || ! -f $f ]]; then
        note "This computer does not boot with GRUB (no grub-mkconfig, $GRUB_CFG or $f): nothing to change."
        return
    fi
    cmd="$(grub_cmdline_default)"
    for w in quiet splash; do
        [[ " $cmd " == *" $w "* ]] || add+=" $w"
    done
    note "Sets GRUB_TIMEOUT_STYLE=hidden and GRUB_TIMEOUT=$GRUB_HIDDEN_WAIT (press Esc while the computer starts to see the menu)${add:+, adds '${add# }' to the kernel options}. Nothing else in $f changes."
    if ! ask "Change $f like that?" y; then
        note "Skipped: $f stays as it is."
        return
    fi
    if ((DRY)); then
        note "[dry-run] keep $f as $f.frameshell-backup (once), change it, grub-mkconfig -o $GRUB_CFG"
        return
    fi
    need_sudo
    # other systems in the menu (dual boot, found by os-prober)
    others="$("${SUDO[@]}" grep -cE "^[[:space:]]*menuentry .*\(on /dev/" "$GRUB_CFG" 2>/dev/null)" || others=0
    if [[ -e $f && ! -e $f.frameshell-backup ]]; then
        "${SUDO[@]}" cp -p "$f" "$f.frameshell-backup" || {
            warn "Could not keep a copy of $f, so it was left as it is."
            return
        }
    fi
    grub_set GRUB_TIMEOUT_STYLE hidden
    grub_set GRUB_TIMEOUT "$GRUB_HIDDEN_WAIT"
    if [[ -n $add ]]; then
        if [[ $cmd == *"'"* ]]; then
            warn "GRUB_CMDLINE_LINUX_DEFAULT in $f has a ' in it, so 'quiet splash' was not added: add it yourself and run: sudo grub-mkconfig -o $GRUB_CFG"
        else
            cmd="${cmd}${add}"
            grub_set GRUB_CMDLINE_LINUX_DEFAULT "'${cmd# }'"
        fi
    fi
    if "${SUDO[@]}" grub-mkconfig -o "$GRUB_CFG"; then
        note "The boot menu is hidden from the next boot on (Esc while the computer starts shows it)."
    else
        warn "grub-mkconfig failed: run 'sudo grub-mkconfig -o $GRUB_CFG' yourself (the file before is $f.frameshell-backup)."
    fi
    [[ -e $f.frameshell-backup ]] && note "The file before is next to it: $f.frameshell-backup"
    ((others > 0)) && warn "Your boot menu has other systems in it (dual boot): press Esc while the computer starts to pick one, or undo this with: sudo cp $f.frameshell-backup $f && sudo grub-mkconfig -o $GRUB_CFG"
    return 0
}

# frameshell's picks among YAMIS's own icons: kitty shows YAMIS's plain terminal icon,
# Firefox its alternative logo, GNOME Text Editor the plain text-editor icon and Nautilus the file
# manager's folder icon (YAMIS's own today; this keeps it if a later YAMIS draws Nautilus
# differently). The two files are swapped inside the installed theme (the originals go to
# the backup folder); every name linked to them (org.mozilla.firefox ...) follows. Runs on
# every install, also when YAMIS was already there.
YAMIS_SWAPS=("kitty.svg:utilities-terminal.svg" "firefox.svg:firefox.alt.svg" "org.gnome.TextEditor.svg:accessories-text-editor.svg" "org.gnome.Nautilus.svg:system-file-manager.svg")
customize_yamis() {
    local dir="" pre=() pair dst src changed=0
    if [[ -f $DATA/icons/YAMIS/index.theme ]]; then
        dir="$DATA/icons/YAMIS"
    elif [[ -f /usr/share/icons/YAMIS/index.theme ]]; then
        dir="/usr/share/icons/YAMIS"
        need_sudo
        pre=("${SUDO[@]}")
    else
        return 0
    fi
    local apps="$dir/apps/scalable"
    for pair in "${YAMIS_SWAPS[@]}"; do
        dst="$apps/${pair%%:*}" src="$apps/${pair#*:}"
        if [[ ! -f $src ]]; then
            warn "YAMIS has no ${pair#*:}, so ${pair%%:*} keeps its icon."
            continue
        fi
        cmp -s "$src" "$dst" 2>/dev/null && continue        # already swapped
        if ((DRY)); then
            note "[dry-run] use ${pair#*:} as ${pair%%:*} in $apps"
            continue
        fi
        if [[ -e $dst || -L $dst ]]; then
            mkdir -p "$BACKUP/icons-YAMIS"
            cp -P "$dst" "$BACKUP/icons-YAMIS/" && BACKED_UP=1
        fi
        "${pre[@]}" rm -f "$dst" && "${pre[@]}" cp "$src" "$dst" && changed=1
    done
    if ((changed)); then
        note "YAMIS: kitty uses the terminal icon, Firefox the alternative logo, GNOME Text Editor the text-editor icon, Nautilus the folder icon."
        if [[ -f $dir/icon-theme.cache ]] && command -v gtk-update-icon-cache >/dev/null 2>&1; then
            "${pre[@]}" gtk-update-icon-cache -qf -t "$dir" 2>/dev/null
        fi
    fi
}

# ── 8. final check ───────────────────────────────────────────────────────────
final_check() {
    say "Checking for the programs the config uses"
    local c miss=()
    for c in Hyprland hyprctl qs kitty nautilus gnome-text-editor celluloid missioncenter hyprlock hypridle hyprpicker wl-copy wl-paste wl-clip-persist cliphist wpctl playerctl notify-send fc-list kvantummanager zenity; do
        command -v "$c" >/dev/null 2>&1 || miss+=("$c")
    done
    if ((${#miss[@]})); then
        warn "Not found in PATH: ${miss[*]}"
    else
        note "everything is there."
    fi
    command -v firefox >/dev/null 2>&1 || note "optional app not installed: firefox (SUPER+B will do nothing until it is)"
    for c in code vesktop; do
        command -v "$c" >/dev/null 2>&1 || note "optional app not installed: $c"
    done
    # another notification daemon would steal org.freedesktop.Notifications from the shell
    for c in mako dunst swaync; do
        if command -v "$c" >/dev/null 2>&1; then
            warn "'$c' is installed. The shell is the notification daemon — if notifications never show up, run: sudo pacman -Rns $c"
        fi
    done
    if ((!DRY)) && ((DO_ICONS)) && [[ ! -f $DATA/icons/YAMIS/index.theme && ! -f /usr/share/icons/YAMIS/index.theme ]]; then
        warn "The YAMIS icon theme is not installed (see the icon pack step above). Until it is, apps show Papirus-Dark icons."
    fi
    if ((!DRY)) && command -v fc-list >/dev/null 2>&1; then
        local fonts
        fonts="$(fc-list 2>/dev/null)"      # (read first: 'fc-list | grep -q' can fail under pipefail)
        grep -qi 'Clarity City' <<<"$fonts" || warn "Clarity City not found by fontconfig (the shell bundles it, but hyprlock needs it installed): run 'fc-cache -f'."
    fi
}

NEED_REBOOT=0
BACKED_UP=0
LOGIN_SWITCHED=""

if ((DO_PACKAGES)); then
    install_packages
    if ((DO_NVIDIA)); then nvidia_setup; fi
    i2c_setup
    radio_setup
fi
install_configs
if ((DO_ICONS)); then
    install_yamis
    customize_yamis
fi
if ((DO_PACKAGES)); then
    system_cursor_default
    if ((DO_LOCALE)); then system_locale; fi
    if ((DO_LOGIN)); then login_screen_setup; fi
    if ((DO_GRUB)); then grub_setup; fi
    if ((DO_BOOT)); then boot_splash_setup; fi
fi
final_check

printf '\n'
say "Done."
((BACKED_UP)) && note "Your previous configs were moved to: $BACKUP"
if ((${#WARNINGS[@]})); then
    printf '\n%sThings to look at:%s\n' "$Y$B" "$N"
    for w in "${WARNINGS[@]}"; do printf '  - %s\n' "$w"; done
fi
printf '\n'
if ((NEED_REBOOT)); then
    note "Reboot now (the NVIDIA modesetting / i2c group changes only take effect after a restart)."
fi
if [[ -n $LOGIN_SWITCHED ]]; then
    note "The new login screen (SDDM with Pixie) starts with the next boot: reboot and pick 'Hyprland' there."
elif ((!NEED_REBOOT)); then
    note "Log out and choose the 'Hyprland' session on the login screen."
fi
note "Notifications start switched OFF: hover the notch and click the bell to turn them on."
note "Keys (Hyprland's defaults): SUPER+R launcher · SUPER+Q terminal · SUPER+C close · SUPER+Space app switcher · SUPER+Escape lock · full list in README.md"
