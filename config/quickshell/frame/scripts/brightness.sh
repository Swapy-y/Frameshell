#!/usr/bin/env bash
# brightness.sh get          -> prints the brightness in percent (0-100), or -1 if unsupported
# brightness.sh set <0-100>  -> sets the brightness
#
# Laptop panels  : brightnessctl (needs a device in /sys/class/backlight)
# Desktop monitor: ddcutil       (DDC/CI over I2C: needs the i2c-dev module and
#                                  your user in the "i2c" group, install.sh does both)

cmd="${1:-get}"
pct="${2:-}"

have() { command -v "$1" >/dev/null 2>&1; }

backlight_present() {
    compgen -G "/sys/class/backlight/*" >/dev/null 2>&1
}

display="${FRAME_DDC_DISPLAY:-1}"
cache="${XDG_RUNTIME_DIR:-/tmp}/frameshell-ddc-max"

case "$cmd" in
get)
    if have brightnessctl && backlight_present; then
        # device,class,current,percent%,max
        brightnessctl -c backlight -m 2>/dev/null | head -n1 | cut -d, -f4 | tr -d '%'
        exit 0
    fi
    if have ddcutil; then
        out="$(ddcutil --display "$display" getvcp 10 --brief 2>/dev/null)" || {
            echo -1
            exit 0
        }
        # VCP 10 C <current> <max>
        echo "$out" | awk -v cache="$cache" '
            $1 == "VCP" && $2 == "10" && $3 == "C" {
                if ($5 > 0) { print int($4 * 100 / $5 + 0.5); print $5 > cache; found = 1 }
            }
            END { if (!found) print -1 }'
        exit 0
    fi
    echo -1
    ;;
set)
    [[ "$pct" =~ ^[0-9]+$ ]] || exit 1
    ((pct > 100)) && pct=100
    ((pct < 1)) && pct=1
    if have brightnessctl && backlight_present; then
        brightnessctl -c backlight set "${pct}%" >/dev/null 2>&1
        exit 0
    fi
    if have ddcutil; then
        max=100
        [[ -r "$cache" ]] && max="$(head -n1 "$cache")"
        [[ "$max" =~ ^[0-9]+$ ]] || max=100
        ddcutil --display "$display" setvcp 10 "$((pct * max / 100))" --noverify >/dev/null 2>&1
        exit 0
    fi
    exit 1
    ;;
*)
    echo "usage: $0 get|set <percent>" >&2
    exit 2
    ;;
esac
