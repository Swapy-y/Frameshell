#!/usr/bin/env bash
# about.sh - what the Settings app's About card shows (the System page, modules/Settings.qml):
# the system, the shell and the hardware, one "key<TAB>value" per line (a key can come more than
# once: "gpu", one line per graphics card). Whatever can't be found is left out.

say() { [ -n "$2" ] && printf '%s\t%s\n' "$1" "$2"; }

# the operating system (/etc/os-release: PRETTY_NAME "CachyOS Linux", LOGO "cachyos")
if [ -r /etc/os-release ]; then
    say os "$(. /etc/os-release; printf '%s' "${PRETTY_NAME:-$NAME}")"
    say logo "$(. /etc/os-release; printf '%s' "$LOGO")"
fi
say kernel "$(uname -sr)"
say arch "$(uname -m)"
say host "$(cat /proc/sys/kernel/hostname 2>/dev/null || uname -n)"

# what draws the desktop: Hyprland ("Hyprland 0.56.2 built from branch ..."), Quickshell
say hyprland "$(hyprctl version 2>/dev/null | head -n 1)"
say quickshell "$(qs --version 2>/dev/null | head -n 1)"

# the processor: its name and how many threads
cpu=$(sed -n 's/^model name[[:space:]]*:[[:space:]]*//p' /proc/cpuinfo 2>/dev/null | head -n 1)
[ -n "$cpu" ] || cpu=$(LC_ALL=C lscpu 2>/dev/null | sed -n 's/^Model name:[[:space:]]*//p' | head -n 1)
say cpu "$cpu"
say threads "$(nproc 2>/dev/null)"

# the memory (kB) and the disk the system is on (bytes: size, free)
say memory "$(sed -n 's/^MemTotal:[[:space:]]*\([0-9]*\).*/\1/p' /proc/meminfo 2>/dev/null)"
say disk "$(df -B1 --output=size,avail / 2>/dev/null | tail -n 1 | awk '{print $1 " " $2}')"

# the graphics cards: "vendor<TAB>device" from lspci ("NVIDIA Corporation", "AD104 [GeForce RTX
# 4070]"); without lspci only who made it (the PCI vendor id)
if command -v lspci >/dev/null 2>&1; then
    # lspci -mm: 01:00.0 "VGA compatible controller" "NVIDIA Corporation" "AD104 [GeForce RTX 4070]" ...
    lspci -mm 2>/dev/null | awk -F'"' '$2 ~ /^(VGA compatible controller|3D controller|Display controller)$/ { print "gpu\t" $4 "\t" $6 }'
else
    for v in /sys/class/drm/card[0-9]*/device/vendor; do
        [ -r "$v" ] && printf 'gpuVendor\t%s\n' "$(cat "$v")"
    done | sort -u
fi
exit 0
