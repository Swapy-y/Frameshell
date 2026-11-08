-- ╭──────────────────────────────────────────────────────────────────────────╮
-- │  Frame - Hyprland config (Lua, Hyprland 0.55 or newer)                    │
-- │                                                                          │
-- │  Lives in  ~/.config/hypr/hyprland.lua                                    │
-- │  The shell lives in  ~/.config/quickshell/frame  (settings: Config.qml)   │
-- ╰──────────────────────────────────────────────────────────────────────────╯
--
-- How to read this file
--   * Every section has a banner like the one above. Lines starting with "--" are comments.
--   * The things you are most likely to change are in the PROGRAMS and SETTINGS sections.
--   * Windows float inside the frame with a strip of wallpaper around them, like the concept:
--         WINDOW_GAP = 15   space around every window and between two windows (SETTINGS below;
--                           the slider "Window gap" in the Settings app, Appearance, once you move it)
--     Border width and corner radius of the windows are NOT set here: the border's width
--     comes from the shell's Settings app (Appearance), the corners from cornerRadius in the
--     shell's Config.qml, so frame, panels and windows always match (see "BORDER AND
--     CORNERS" below). Change them there; it applies live.
--     A maximized window (SUPER + F) keeps the gap and the rounded corners; F11 covers the whole
--     screen (see FULLSCREEN_LIKE_TILE).
--
-- Main keys (SUPER is the Windows key) - Hyprland's defaults, the full list is in KEYBINDINGS
--   SUPER + R           app launcher               SUPER + Space    app switcher (hold SUPER)
--   SUPER + Q / E / B   terminal / files / browser SUPER + C        close window
--   SUPER + F           maximize                   F11              fullscreen
--   SUPER + H           minimize                   SUPER + V        toggle floating
--   SUPER + arrows      focus                      SUPER + SHIFT + arrows   move window
--   SUPER + Left/Right  at the screen edge they go on to the workspace left / right
--   SUPER + 1…5         workspace                  SUPER + SHIFT + 1…5   move window there
--   SUPER + S           scratchpad                 SUPER + SHIFT + S     move window to it
--   SUPER + Escape      lock                       SUPER + M        log out (asks first)
--   SUPER + CTRL + arrows   wallpaper (Left/Right) and colour theme (Up/Down) switcher
--   SUPER + .           emoji picker               SUPER + \        on-screen keyboard


--------------------
---- PROGRAMS   ----
--------------------

local terminal    = "kitty"
local fileManager = "nautilus"
local homeFolder  = fileManager .. " --new-window"               -- "Open home folder": a new window, at home
local browser     = "firefox"
local textEditor  = "gnome-text-editor --new-window"             -- GNOME Text Editor: a new window (not the open one)

local qs          = "qs -c frame"                                -- the Quickshell config named "frame"
local launcher    = qs .. " ipc call launcher toggle"            -- the shell's own app launcher
-- screenshots: the shell's own screenshot screen (modules/Screenshot.qml), started at once with an
-- event on Hyprland's socket; saved to ~/Pictures/Screenshots + copied (scripts/screenshot.sh), a
-- click on the "Screenshot saved" notification shows the file in the file manager
local screenshot      = hl.dsp.event("frameshell-screenshot area")
local screenshot_full = hl.dsp.event("frameshell-screenshot screen")
-- the shell's emoji picker (modules/EmojiPicker.qml) and on-screen keyboard (modules/OnScreenKeyboard.qml)
local emoji_toggle    = hl.dsp.event("frameshell-emoji toggle")
local keyboard_toggle = hl.dsp.event("frameshell-osk toggle")
-- the lock screen: the Pixie login screen, drawn by Quickshell (hyprlock if that ever fails)
local lockscreen  = 'bash "${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/frame/scripts/lock.sh"'
-- log out: the shell asks "Log out?" first, then closes every app and the login screen comes back
-- (scripts/power.sh; run directly when the shell is not running)
local logout      = qs .. ' ipc call ui logout || bash "${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/frame/scripts/power.sh" logout'


--------------------
---- SETTINGS   ----
--------------------

-- Space in screen pixels (the unit of rounding and of the shell) between the frame and a window,
-- and between two windows. 0 = windows touch the frame and each other. This is the gap until you
-- move the slider in the shell's Settings app (Appearance, "Window gap", 5 - 20 px): that one is
-- kept in ~/.local/state/frameshell/appearance.json ("windowGap") and counts from then on (read
-- when Hyprland starts, below; a move of the slider applies at once: frameshell_gap).
local WINDOW_GAP = 15

-- What fullscreen (F11, and an app's own fullscreen: a video, a game) looks like.
-- false = real fullscreen: the window covers the whole screen (no frame, notch or bottom bar,
--         no gap, square corners). SUPER + F (maximize) keeps the frame, the gap and the
--         rounded corners.
-- true  = fullscreen never covers the frame: the window fills the window area and keeps the
--         WINDOW_GAP around it and its rounded corners, looking exactly like a single tile
--         (notch, frame and bottom bar stay visible), the same as SUPER + F.
--         The app is still told it is fullscreen, so videos and browsers hide their own UI.
local FULLSCREEN_LIKE_TILE = false

-- Mouse cursor: Simp1e Adw Dark (AUR package xcursor-simp1e-adw-dark, install.sh installs it).
-- The name is the theme's folder in /usr/share/icons. Size 24 = the usual size.
local CURSOR_THEME = "Simp1e-Adw-Dark"
local CURSOR_SIZE  = 24


-------------------------------------------
---- BORDER, CORNERS AND SHADOWS        ----
-------------------------------------------

-- The window border, the window corners and the window shadows use the same settings as the
-- shell. The width of the ring around every window (border_size) is set with a slider in the
-- shell's Settings app (Appearance, "Window border"), which keeps it in
-- ~/.local/state/frameshell/appearance.json ("windowBorder"; 2 until you change it). The
-- others are read from ~/.config/quickshell/frame/Config.qml:
--     cornerRadius   -> rounding    (the window corners)
--     shadows        -> window shadows on / off (with the shell's own shadows)
--     shadowStrength -> how dark the window shadows are
-- So there is ONE place to change them: the Settings app / Config.qml. Saving Config.qml reloads
-- the shell, and the shell passes the new values straight on to Hyprland (modules/HyprSync.qml),
-- no reload needed; so does a move of the slider. If a file cannot be read, the defaults below
-- are used.
local function shell_setting(name, fallback, kind)       -- kind: "int" (default), "real", "bool"
    kind = kind or "int"
    local ok, value = pcall(function()
        local base = os.getenv("XDG_CONFIG_HOME") or ((os.getenv("HOME") or "") .. "/.config")
        local file = io.open(base .. "/quickshell/frame/Config.qml", "r")
        if not file then
            return nil
        end
        local text = "\n" .. (file:read("a") or "")
        file:close()
        local raw = text:match("\n%s*property%s+" .. kind .. "%s+" .. name .. "%s*:%s*([%w%.%-]+)")
        if kind == "bool" then
            if raw == "true" then
                return true
            elseif raw == "false" then
                return false
            end
            return nil
        end
        return tonumber(raw)
    end)
    if ok and value ~= nil then
        return value
    end
    return fallback
end

-- a number, true / false or a text the shell's Settings app keeps in
-- ~/.local/state/frameshell/<file> (fallback: until it is set there)
local function shell_state(file_name, name, fallback)
    local ok, value = pcall(function()
        local base = os.getenv("XDG_STATE_HOME") or ((os.getenv("HOME") or "") .. "/.local/state")
        local file = io.open(base .. "/frameshell/" .. file_name, "r")
        if not file then
            return nil
        end
        local text = file:read("a") or ""
        file:close()
        if type(fallback) == "string" then
            return text:match('"' .. name .. '"%s*:%s*"([^"]*)"')
        end
        local raw = text:match('"' .. name .. '"%s*:%s*([%w%.%-]+)')
        if raw == "true" then
            return true
        elseif raw == "false" then
            return false
        end
        return tonumber(raw)
    end)
    if ok and value ~= nil and type(value) == type(fallback) then
        return value
    end
    return fallback
end

local WINDOW_BORDER   = shell_state("appearance.json", "windowBorder", 2)
do      -- the Settings app's "Window gap" (-1 or missing: never moved, WINDOW_GAP above stays)
    local gap = shell_state("appearance.json", "windowGap", -1)
    if gap >= 0 then
        WINDOW_GAP = math.floor(gap + 0.5)
    end
end

-- The focus and the pointer: the Settings app's Devices page, Mouse ("Focus on cursor", "Cursor
-- follows focus"), kept in ~/.local/state/frameshell/system.json. The shell hands a change to
-- Hyprland right away (modules/HyprSync.qml); this is what Hyprland starts with.
local FOCUS_FOLLOWS_MOUSE  = shell_state("system.json", "focusFollowsMouse", false)
local CURSOR_FOLLOWS_FOCUS = shell_state("system.json", "cursorFollowsFocus", true)

-- Blur: the Settings app's Blur page, kept in ~/.local/state/frameshell/blur.json (the shell
-- hands a change to Hyprland right away). "Apply blur to windows" blurs what is behind
-- see-through windows (it makes no window see-through: that is the app's own setting, e.g.
-- kitty's background_opacity); "Apply blur to shell" makes the frame, the island, the panels
-- and the pop-ups see-through (SHELL_OPACITY) and blurs what is behind them (the layer rule
-- "frame-shell-blur" in WINDOW AND LAYER RULES).
local WINDOW_BLUR     = shell_state("blur.json", "windowBlur", true)
local SHELL_BLUR      = shell_state("blur.json", "shellBlur", false)
local BLUR_SIZE       = shell_state("blur.json", "blurSize", 7)
local BLUR_PASSES     = shell_state("blur.json", "blurPasses", 2)
local BLUR_BRIGHTNESS = shell_state("blur.json", "blurBrightness", 1.0)
local BLUR_CONTRAST   = shell_state("blur.json", "blurContrast", 0.9)
local SHELL_OPACITY   = shell_state("blur.json", "shellOpacity", 0.8)
local WINDOW_ROUNDING = shell_setting("cornerRadius", 30)
local SHADOWS         = shell_setting("shadows", true, "bool")
local SHADOW_STRENGTH = shell_setting("shadowStrength", 0.6, "real")

-- The shadow under every window: soft and even on all sides. The darkness is shadowStrength x
-- these factors (0.6 x 0.6 = 36 %), for the focused window and the others. HyprSync.qml reads
-- the two factors from this file, so change them only here.
-- Keep SHADOW_RANGE close to WINDOW_GAP: the strip of wallpaper between the windows and the
-- notch / frame is only WINDOW_GAP wide, and a much longer shadow darkens it unevenly.
local SHADOW_RANGE    = 20                -- how far it reaches, in screen pixels
local SHADOW_OFFSET   = 0                 -- how much lower than the window
local SHADOW_ACTIVE   = 0.6
local SHADOW_INACTIVE = 0.6

-- "rgba(000000XX)": black with the given opacity (0 ... 1)
local function shadow_color(alpha)
    alpha = math.max(0, math.min(1, alpha))
    return string.format("rgba(000000%02x)", math.floor(alpha * 255 + 0.5))
end


--------------------
---- MONITOR    ----
--------------------

-- One monitor, everything automatic, at its highest refresh rate ("highrr"; "preferred" =
-- the mode the screen suggests, "highres" = its highest resolution). To fix a mode / scale,
-- e.g. for a 4K screen:
--   hl.monitor({ output = "DP-1", mode = "3840x2160@144", position = "0x0", scale = 1.5 })
-- (find the output name with `hyprctl monitors`). The shell scales itself to the screen.
hl.monitor({
    output   = "",
    mode     = "highrr",
    position = "auto",
    scale    = "auto",
})


-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

-- Cursor (see CURSOR_THEME in SETTINGS). Apps read these too - and so does Hyprland itself:
-- it picks its first cursor right after reading this file, so the cursor is Simp1e from the
-- very first moment after you log in.
hl.env("XCURSOR_THEME",   CURSOR_THEME)
hl.env("XCURSOR_SIZE",    tostring(CURSOR_SIZE))
hl.env("HYPRCURSOR_SIZE", tostring(CURSOR_SIZE))
-- Simp1e is an XCursor theme. With hyprcursor on, Hyprland would start with some other
-- (hyprcursor) theme that is installed - a white cursor for about a second, until the
-- "hyprctl setcursor" below. Off: always the XCursor theme above.
hl.config({ cursor = {
    enable_hyprcursor = false,
    no_warps          = not CURSOR_FOLLOWS_FOCUS,  -- false: focusing a window with the keys moves the pointer to it
} })

-- NVIDIA --------------------------------------------------------------------
-- Only on a computer with an NVIDIA card (has_nvidia_gpu below): on AMD / Intel graphics these
-- would break video decoding and OpenGL in X11 apps.
-- Left out on purpose: GBM_BACKEND=nvidia-drm (it crashes Firefox / some Electron apps on
-- several driver versions). With a second (integrated) GPU, pin the one Hyprland should use:
--   hl.env("AQ_DRM_DEVICES", "/dev/dri/card1:/dev/dri/card0")
-- The mouse cursor: NVIDIA's hardware cursor often keeps the default arrow (or flickers /
-- vanishes) under Hyprland, so on an NVIDIA card Hyprland draws the cursor itself. Other
-- GPUs keep the hardware cursor. Force it either way: 0 = hardware, 1 = drawn by Hyprland.
local function has_nvidia_gpu()
    for i = 0, 15 do
        local f = io.open("/sys/class/drm/card" .. i .. "/device/vendor", "r")
        if f then
            local vendor = f:read("l")
            f:close()
            if vendor and vendor:lower() == "0x10de" then
                return true
            end
        end
    end
    return false
end
if has_nvidia_gpu() then
    hl.env("LIBVA_DRIVER_NAME",         "nvidia")   -- video decoding through nvidia-vaapi-driver
    hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
    hl.env("NVD_BACKEND",               "direct")   -- nvidia-vaapi-driver backend
    hl.config({ cursor = { no_hardware_cursors = 1 } })
end

-- Toolkits (Qt, GTK, Electron, Firefox run natively on Wayland) -------------------
hl.env("QT_QPA_PLATFORM",                     "wayland;xcb")
-- qt5ct: Qt 5 apps read ~/.config/qt5ct, Qt 6 apps ~/.config/qt6ct (qt6ct answers to this name too)
hl.env("QT_QPA_PLATFORMTHEME",                "qt5ct")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("GDK_BACKEND",                         "wayland,x11,*")
hl.env("SDL_VIDEODRIVER",                     "wayland,x11")
hl.env("ELECTRON_OZONE_PLATFORM_HINT",        "auto")
hl.env("MOZ_ENABLE_WAYLAND",                  "1")


-------------------
---- AUTOSTART ----
-------------------

hl.on("hyprland.start", function()
    -- the cursor: Hyprland's own (Simp1e is an XCursor theme, setcursor loads it as such) and
    -- the one GTK apps use
    hl.exec_cmd("hyprctl setcursor " .. CURSOR_THEME .. " " .. CURSOR_SIZE)
    hl.exec_cmd("gsettings set org.gnome.desktop.interface cursor-theme " .. CURSOR_THEME ..
        " && gsettings set org.gnome.desktop.interface cursor-size " .. CURSOR_SIZE)
    -- GTK apps: no pasting with the middle mouse button either (see misc.middle_click_paste)
    hl.exec_cmd("gsettings set org.gnome.desktop.interface gtk-enable-primary-paste false")
    -- GTK apps: no minimise / maximise / close buttons in their title bars (Hyprland handles
    -- the windows). gtk-3.0/gtk.css and gtk-4.0/gtk.css hide the ones an app makes anyway.
    hl.exec_cmd("gsettings set org.gnome.desktop.wm.preferences button-layout 'appmenu:'")

    hl.exec_cmd(qs)                                                -- the whole desktop UI (also the notification daemon)
    -- the password dialog for admin rights is the shell's own (modules/PolkitAuth.qml); it starts
    -- hyprpolkitagent by itself if it cannot do the job
    hl.exec_cmd(lockscreen .. " --resident")                       -- the lock screen waits in the background, so locking is instant
    hl.exec_cmd("hypridle")                                        -- locks before suspend; no idle lock / screen off (hypridle.conf)
    hl.exec_cmd("wl-clip-persist --clipboard regular")             -- what you copy stays copied after the app closes
    hl.exec_cmd("wl-paste --type text  --watch cliphist store")    -- clipboard history (the panel on the left edge)
    hl.exec_cmd("wl-paste --type image --watch cliphist store")

    -- Dark mode, the Frame GTK theme (the shell's colours) + icon pack for GTK apps. Done once per install
    -- (install.sh removes the marker file, so a re-install applies it again).
    hl.exec_cmd([[[ -e ~/.local/state/frameshell/gsettings ] || { gsettings set org.gnome.desktop.interface color-scheme prefer-dark && gsettings set org.gnome.desktop.interface gtk-theme Frame && gsettings set org.gnome.desktop.interface icon-theme YAMIS && mkdir -p ~/.local/state/frameshell && touch ~/.local/state/frameshell/gsettings; }]])
end)


-----------------------
---- LOOK AND FEEL ----
-----------------------

-- The shell reserves the frame, its border, the bottom bar and the notch as screen space, so
-- windows never go under them. WINDOW_GAP is added on top of that: the strip of wallpaper you
-- see between the frame and a window, and between two windows.
--
-- gaps_in belongs to one window: each window is pulled in by gaps_in on every side that touches
-- another window, so the space between two neighbours is the "right" half of the left window
-- plus the "left" half of the right one (likewise bottom + top). We split WINDOW_GAP in two
-- whole numbers (7 + 8 = 15), because Hyprland only takes integers and 2 x 7 would be 14.
-- float_gaps does the same for floating windows (and for them in "fullscreen").
local function gap_config(gap)
    local lo = gap // 2
    local hi = gap - lo
    return { gaps_in = { top = lo, left = lo, right = hi, bottom = hi }, gaps_out = gap, float_gaps = gap }
end
local GAPS = gap_config(WINDOW_GAP)

-- The window border colours: activeHint (the focused window) and inactiveHint (the others) of
-- the shell's colour theme in use - each theme in Config.qml (`themes`) has its own. Hyprland
-- starts with the ones of the theme you picked (~/.local/state/frameshell/theme); the theme
-- switcher (SUPER + CTRL + Up / Down) and a save of Config.qml switch them right away (the shell hands
-- them over: modules/HyprSync.qml). A theme that leaves one out gets the first theme's
-- (Default), as in the shell; without Config.qml, the ones below.
local function shell_theme()
    local ok, name = pcall(function()
        local base = os.getenv("XDG_STATE_HOME") or ((os.getenv("HOME") or "") .. "/.local/state")
        local file = io.open(base .. "/frameshell/theme", "r")
        if not file then
            return nil
        end
        local text = file:read("a") or ""
        file:close()
        return text:match("^%s*(.-)%s*$")
    end)
    return ok and name or "Default"
end

-- "#c4c4c4" / "#80c4c4c4" (#AARRGGBB, like Qt) / "#ccc" as Hyprland writes it: "rgba(c4c4c4ff)"
local function hypr_color(hex)
    hex = hex:gsub("^#", "")
    if #hex == 3 then
        hex = hex:gsub("(%x)", "%1%1")
    end
    if #hex == 6 then
        return "rgba(" .. hex:lower() .. "ff)"
    elseif #hex == 8 then
        return "rgba(" .. hex:sub(3):lower() .. hex:sub(1, 2):lower() .. ")"
    end
    return nil
end

-- a colour of the theme `name` in Config.qml, as Hyprland writes it (nil: not found)
local function theme_color(name, key)
    local ok, value = pcall(function()
        local base = os.getenv("XDG_CONFIG_HOME") or ((os.getenv("HOME") or "") .. "/.config")
        local file = io.open(base .. "/quickshell/frame/Config.qml", "r")
        if not file then
            return nil
        end
        local text = file:read("a") or ""
        file:close()
        local start = text:find("property%s+var%s+themes%s*:%s*%[")
        if not start then
            return nil
        end
        -- the list of themes, without its comments; each theme is one { ... }
        local list = text:sub(start):gsub("//[^\n]*", ""):match("%b[]")
        if not list then
            return nil
        end
        local first, found
        for entry in list:gmatch("%b{}") do
            first = first or entry
            if entry:match('[^%w]name%s*:%s*"([^"]*)"') == name then
                found = entry
                break
            end
        end
        local function get(entry)
            local hex = entry and entry:match("[^%w]" .. key .. '%s*:%s*"(#%x+)"')
            return hex and hypr_color(hex)
        end
        return get(found) or get(first)
    end)
    return ok and value or nil
end

local THEME = shell_theme() or "Default"
local BORDERS = {
    active_border   = theme_color(THEME, "activeHint") or "rgba(c4c4c4ff)",
    inactive_border = theme_color(THEME, "inactiveHint") or "rgba(313131ff)",
}

hl.config({
    general = {
        gaps_in     = GAPS.gaps_in,
        gaps_out    = GAPS.gaps_out,                  -- window <-> frame
        float_gaps  = GAPS.float_gaps,                -- the same for floating windows
        border_size = WINDOW_BORDER,                  -- ring around every window = "Window border" in the Settings app (0 = none)

        col = {                                       -- the colours of the shell's theme: activeHint / inactiveHint in Config.qml
            active_border   = BORDERS.active_border,  -- focused window
            inactive_border = BORDERS.inactive_border,
        },

        resize_on_border = true,                      -- drag the gap between tiles to resize
        no_focus_fallback = true,                     -- moving focus past the last window does not wrap around to the
                                                      -- other side (so SUPER + Left / Right can go on to the next workspace)
        allow_tearing    = false,
        layout           = "dwindle",
    },

    decoration = {
        rounding       = WINDOW_ROUNDING,             -- window corners = cornerRadius in Config.qml (30 = 4K, ~13 = 1080p).
                                                      -- The border sits outside it, so a window's outer corner is
                                                      -- cornerRadius + the border's width, like the frame's corners.
        rounding_power = 2,                           -- 2 = a true circle arc

        active_opacity   = 1.0,
        inactive_opacity = 1.0,

        -- soft shadow under every window (on / off and how dark: shadows / shadowStrength in Config.qml)
        shadow = {
            enabled        = SHADOWS and SHADOW_STRENGTH > 0,
            range          = SHADOW_RANGE,
            render_power   = 3,               -- how fast it fades: 1 = slowly ... 4 = quickly
            offset         = { 0, SHADOW_OFFSET },
            color          = shadow_color(SHADOW_STRENGTH * SHADOW_ACTIVE),
            color_inactive = shadow_color(SHADOW_STRENGTH * SHADOW_INACTIVE),
        },
        -- the Settings app's Blur page (BLUR_* above): on while windows or the shell want it
        blur   = {
            enabled    = WINDOW_BLUR or SHELL_BLUR,
            size       = BLUR_SIZE,
            passes     = BLUR_PASSES,
            brightness = BLUR_BRIGHTNESS,
            contrast   = BLUR_CONTRAST,
        },
    },

    dwindle = {
        preserve_split = true,
        force_split    = 2,                           -- new windows always open on the right (or below), wherever the mouse is
    },
    master  = { new_status = "master" },

    animations = { enabled = true },

    misc = {
        force_default_wallpaper    = 0,               -- the shell draws the wallpaper
        background_color           = "rgb(000000)",   -- black until then: after logging in the desktop fades in from black
        disable_hyprland_logo      = true,
        disable_splash_rendering   = true,
        focus_on_activate          = true,            -- apps may ask for focus (a link opened from another app)
        mouse_move_enables_dpms    = true,            -- wake the screen after hypridle switched it off
        key_press_enables_dpms     = true,
        allow_session_lock_restore = true,            -- if the lock screen ever crashes, lock.sh starts hyprlock in its place
        middle_click_paste         = false,           -- no pasting with the middle mouse button (scroll wheel click)
    },

    ecosystem = {
        no_update_news  = true,
        no_donation_nag = true,
    },
})


-----------------------
---- ANIMATIONS    ----
-----------------------

-- The same motion curves the Caelestia shell uses (Material 3 "emphasized" and "standard").
-- Speeds are in units of 100 ms: speed 4 = 400 ms.
hl.curve("emphasizedDecel", { type = "bezier", points = { {0.05, 0.7}, {0.1, 1}   } })  -- things arriving
hl.curve("emphasizedAccel", { type = "bezier", points = { {0.3,  0},   {0.8, 0.15} } })  -- things leaving
hl.curve("standard",        { type = "bezier", points = { {0.2,  0},   {0,   1}   } })  -- everything else

hl.animation({ leaf = "global",           enabled = true, speed = 10, bezier = "standard" })

-- Windows moving and workspaces sliding share one speed and curve: a window moved to another
-- workspace glides to its new place during the slide and must arrive with it (see the
-- "Moving a window to another workspace" part of the keybindings).
local SLIDE_SPEED = 3                  -- 300 ms
local MOVE_CURVE  = "standard"         -- windows moving (a minimized window coming back borrows "emphasizedDecel" for a moment)

-- windows opening / closing / moving (moving also drives the tile <-> fullscreen change)
hl.animation({ leaf = "windowsIn",        enabled = true, speed = 3,  bezier = "emphasizedDecel", style = "popin 88%" })
hl.animation({ leaf = "windowsOut",       enabled = true, speed = 2,  bezier = "emphasizedAccel", style = "popin 88%" })
hl.animation({ leaf = "windowsMove",      enabled = true, speed = SLIDE_SPEED, bezier = MOVE_CURVE })

-- fades and borders
hl.animation({ leaf = "fade",             enabled = true, speed = 2,  bezier = "standard" })
hl.animation({ leaf = "border",           enabled = true, speed = 3,  bezier = "standard" })

-- workspaces: they slide in from the side, without fading ("slidefade 20%" = short slide + fade,
-- enabled = false = instant)
hl.animation({ leaf = "workspaces",       enabled = true, speed = SLIDE_SPEED, bezier = "standard", style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 3,  bezier = "emphasizedDecel", style = "slidefadevert 20%" })

-- layer surfaces of other programs (the shell animates its own layers, see the rules below)
hl.animation({ leaf = "layersIn",         enabled = true, speed = 3,  bezier = "emphasizedDecel", style = "slide" })
hl.animation({ leaf = "layersOut",        enabled = true, speed = 2,  bezier = "emphasizedAccel", style = "slide" })
hl.animation({ leaf = "fadeLayersIn",     enabled = true, speed = 2,  bezier = "standard" })
hl.animation({ leaf = "fadeLayersOut",    enabled = true, speed = 2,  bezier = "standard" })


---------------
---- INPUT ----
---------------

-- The keyboard, the mouse and the touchpad: the Settings app's Devices page, kept in
-- ~/.local/state/frameshell/input.json (the shell hands a change to Hyprland right away,
-- modules/HyprSync.qml). The last value of each line is what Hyprland uses until you set it
-- there - and what the Settings app shows until then (it reads these lines).
local REPEAT_DELAY      = shell_state("input.json", "repeatDelay", 300)         -- a held key repeats after … ms
local REPEAT_RATE       = shell_state("input.json", "repeatRate", 35)          -- … this many times a second
local NUMLOCK           = shell_state("input.json", "numlock", true)
local MOUSE_SPEED       = shell_state("input.json", "mouseSpeed", -0.75)        -- -1.0 … 1.0, 0 = unchanged, below 0 = slower
local MOUSE_ACCEL       = shell_state("input.json", "mouseAcceleration", true)  -- true = "adaptive" (acceleration), false = "flat" (none)
local MOUSE_SCROLL      = shell_state("input.json", "mouseScrollSpeed", 1.0)    -- 0 … 2
local MOUSE_NATURAL     = shell_state("input.json", "mouseNaturalScroll", false)
local TOUCHPAD_TAP      = shell_state("input.json", "touchpadTap", true)
local TOUCHPAD_NATURAL  = shell_state("input.json", "touchpadNaturalScroll", false)
local TOUCHPAD_TYPING   = shell_state("input.json", "touchpadTyping", true)     -- off while you type
local TOUCHPAD_SCROLL   = shell_state("input.json", "touchpadScrollSpeed", 1.0) -- 0 … 2

hl.config({
    input = {
        kb_layout  = "us",
        kb_variant = "",
        kb_model   = "",
        kb_options = "",
        kb_rules   = "",

        numlock_by_default = NUMLOCK,
        repeat_rate        = REPEAT_RATE,
        repeat_delay       = REPEAT_DELAY,

        -- "Focus on cursor" in the Settings app (Devices, Mouse): off = focus changes only when you click
        -- a window, not when the pointer passes over it (2: the window under the pointer still
        -- gets scrolling and hover effects); on = the window under the pointer gets the focus (1)
        follow_mouse                = FOCUS_FOLLOWS_MOUSE and 1 or 2,
        float_switch_override_focus = 0,   -- toggling tiling / floating does not move focus to the pointer either

        -- the mouse (above: MOUSE_…)
        accel_profile  = MOUSE_ACCEL and "adaptive" or "flat",
        sensitivity    = MOUSE_SPEED,
        scroll_factor  = MOUSE_SCROLL,
        natural_scroll = MOUSE_NATURAL,

        -- a touchpad (above: TOUCHPAD_…)
        touchpad = {
            tap_to_click         = TOUCHPAD_TAP,
            natural_scroll       = TOUCHPAD_NATURAL,
            disable_while_typing = TOUCHPAD_TYPING,
            scroll_factor        = TOUCHPAD_SCROLL,
        },
    },
})


---------------------------------
---- FULLSCREEN AND MAXIMIZE ----
---------------------------------

-- Hyprland keeps two fullscreen states per window:
--   internal = what Hyprland does with the window
--   client   = what the app is told
-- with the numbers 0 = normal (a tile), 1 = maximized (fills the window area and keeps the gap,
-- the border and the rounded corners), 2 = fullscreen (covers the whole screen) and, in Hyprland
-- 0.55, 3 = fullscreen that goes back to maximized when it ends (newer versions show it as 2
-- and remember the maximize themselves).
--
-- SUPER + F maximizes (1). F11 goes fullscreen (2) and back; a maximized window comes back
-- maximized. Both states are given to Hyprland and the app alike ("sync_fullscreen"), so when an
-- app asks for fullscreen itself (the button of a video player, a game) or leaves it (Esc in a
-- video), Hyprland follows it.
--
-- FULLSCREEN_LIKE_TILE = true instead keeps fullscreen at internal 1 (inside the frame) and only
-- tells the app 2, so videos and browsers still hide their own controls.

local function set_fullscreen_state(w, internal, client)
    hl.dispatch(hl.dsp.window.fullscreen_state({ window = w, action = "set", internal = internal, client = client }))
end

-- Re-enables "sync_fullscreen". Hyprland switches it off whenever internal and client differ;
-- with it on again, an app that leaves fullscreen by itself (F11, a video player) also puts
-- the window back into its tile.
local function resync_fullscreen(w)
    hl.dispatch(hl.dsp.window.set_prop({ window = w, prop = "sync_fullscreen", value = "1" }))
end

-- true while the window covers the whole screen (internal state 2 or 3). Safe to call on a
-- window that has just been closed.
local function is_real_fullscreen(w)
    local ok, state = pcall(function() return w.fullscreen end)
    return ok and type(state) == "number" and state >= 2
end

-- Which windows were maximized when they went fullscreen, so F11 can put them back
-- maximized (by window address; Hyprland 0.56+ does not show this in the state itself).
local fs_seen     = {}      -- [address] = the last fullscreen state seen (0, 1, 2 or 3)
local fs_from_max = {}      -- [address] = true while a window that was maximized is fullscreen
local blur_hold   = {}      -- [address] = a number while it keeps the real blur after maximize (below)

local function track_fullscreen(w)
    local ok, id, state = pcall(function() return w.address, w.fullscreen end)
    if not ok or type(id) ~= "string" or type(state) ~= "number" then
        return
    end
    if state < 2 then
        fs_from_max[id] = nil           -- out of fullscreen (F11, the app itself, SUPER + F)
    elseif fs_seen[id] == 1 then
        fs_from_max[id] = true          -- maximized -> fullscreen (F11 or the app)
    elseif fs_seen[id] == 0 then
        fs_from_max[id] = nil           -- tile -> fullscreen
    end
    fs_seen[id] = state
end

local function forget_window(w)
    pcall(function()
        local id = w.address
        fs_seen[id] = nil
        fs_from_max[id] = nil
        blur_hold[id] = nil
    end)
end

-- Turns a window that went into real fullscreen into the framed look (FULLSCREEN_LIKE_TILE).
local function fullscreen_to_tile(w)
    if not is_real_fullscreen(w) then
        return
    end
    local client = w.fullscreen_client
    if type(client) ~= "number" or client < 1 then
        client = 2
    end
    set_fullscreen_state(w, 1, client)
    resync_fullscreen(w)
end

-- The other windows under a maximized or fullscreen one. Hyprland stops drawing the other
-- windows of a workspace while one of its windows is maximized (SUPER + F) or fullscreen (F11,
-- a video, a game): they would be covered anyway - but not through a see-through window (a
-- terminal with background_opacity), which then shows only the wallpaper. So they are kept:
-- marked "over fullscreen", as Hyprland marks a window opened on top of a fullscreen one, they
-- are drawn again - still under it (Hyprland draws them first and the maximized / fullscreen
-- window over them), and the pointer and the keys still go to that one. Floating windows are
-- left alone: marked, they would come up over it (as when you focus one) - on a workspace
-- without tiling, where every window floats, SUPER + F maximizes another way for that ("Maximize
-- on a workspace without tiling" below). Hyprland clears the
-- marks at every change of a fullscreen state (in 0.55 after telling this config), so this runs
-- a moment later. With blur, the window must also blur them instead of only the wallpaper (the
-- rule "frame-blur-under-fullscreen" below).
local under_pending = {}            -- [workspace id] = true while a pass is queued

-- the mark: "allowed_over_fullscreen" since Hyprland 0.56, "over_fullscreen" in 0.55
local function marked_over_fullscreen(o)
    local v = o.allowed_over_fullscreen
    if v == nil then
        v = o.over_fullscreen
    end
    return v == true
end

local function keep_windows_under(ws_id)
    local list = hl.get_workspace_windows(ws_id) or {}
    local covered = false
    for _, o in ipairs(list) do
        local ok, state = pcall(function() return o.fullscreen end)
        if ok and type(state) == "number" and state > 0 then
            covered = true
            break
        end
    end
    if not covered then
        return
    end
    for _, o in ipairs(list) do
        pcall(function()
            if o.fullscreen == 0 and not o.floating and not o.hidden and not marked_over_fullscreen(o) then
                hl.dispatch(hl.dsp.window.alter_zorder({ mode = "top", window = o }))
            end
        end)
    end
end

local function windows_under_later(ws)
    local ok, id = pcall(function() return ws.id end)
    if not ok or type(id) ~= "number" or under_pending[id] then
        return
    end
    under_pending[id] = true
    local queued = pcall(hl.timer, function()
        under_pending[id] = nil
        pcall(keep_windows_under, id)
    end, { timeout = 1, type = "oneshot" })
    if not queued then
        under_pending[id] = nil
    end
end

-- A window that stops being maximized or fullscreen still blurs what is really under it while
-- it shrinks back into its tile (the rule "frame-blur-under-fullscreen" below only lasts as
-- long as it is maximized), so the windows under it do not vanish from its blur at once.
-- (A window that has closed reads as nil; naming it in a dispatch shows an error, so it is
-- checked first: a window that closes while maximized gets nothing.)
local function hold_real_blur(w)
    local ok, id, state, mapped = pcall(function() return w.address, w.fullscreen, w.mapped end)
    if not ok or type(id) ~= "string" or state ~= 0 or mapped ~= true then
        return
    end
    local token = (blur_hold[id] or 0) + 1
    blur_hold[id] = token
    hl.dispatch(hl.dsp.window.set_prop({ window = w, prop = "xray", value = "0" }))
    hl.timer(function()
        if blur_hold[id] ~= token then
            return                      -- maximized and back again since: that one ends it
        end
        blur_hold[id] = nil
        pcall(function()
            if w.mapped == true then    -- not closed in the meantime
                hl.dispatch(hl.dsp.window.set_prop({ window = w, prop = "xray", value = "unset" }))
            end
        end)
    end, { timeout = SLIDE_SPEED * 100 + 150, type = "oneshot" })
end

-- Moving tiled windows (SUPER + SHIFT + arrow keys, SUPER + Z), and a
-- window opening between them (the others make room): while they slide over each other, a
-- see-through one shows the windows it passes, blurred - for that moment they blur what is
-- really under them (the rule "frame-blur-moving" below; behind a tiled window Hyprland
-- normally blurs only a stored copy of the wallpaper). It is a tag, "frame-moving", on the
-- tiled windows of the workspace (`ws_id`, else the one you are on): a tag only changes their
-- rules, the windows are not laid out anew. (A window that has closed reads as nil: skipped.)
local moving_tagged = {}               -- address -> window, tagged right now
local moving_count = 0

local function blur_live_while_moving(ws_id)
    if not ws_id then
        local ws = hl.get_active_workspace()
        if not ws then
            return
        end
        ws_id = ws.id
    end
    for _, o in ipairs(hl.get_workspace_windows(ws_id) or {}) do
        pcall(function()
            local id = o.address
            if not o.floating and type(id) == "string" and not moving_tagged[id] then
                hl.dispatch(hl.dsp.window.tag({ window = o, tag = "+frame-moving" }))
                moving_tagged[id] = o
            end
        end)
    end
    moving_count = moving_count + 1
    local n = moving_count
    pcall(hl.timer, function()
        if n ~= moving_count then
            return                      -- moved again since: that one ends it
        end
        local tagged = moving_tagged
        moving_tagged = {}
        for _, o in pairs(tagged) do
            pcall(function()
                if o.mapped == true then
                    hl.dispatch(hl.dsp.window.tag({ window = o, tag = "-frame-moving" }))
                end
            end)
        end
    end, { timeout = SLIDE_SPEED * 100 + 150, type = "oneshot" })
end

-- a window opened on, or moved to, a workspace with a maximized or fullscreen window
hl.on("window.open", function(w)
    pcall(function() windows_under_later(w.workspace) end)
    -- a window opened into the tiles of the workspace you are on: while it grows in and the
    -- others make room, see-through ones show it (and each other) going by
    pcall(function()
        local ws = w.workspace
        local here = hl.get_active_workspace()
        if not w.floating and ws and here and ws.id == here.id then
            blur_live_while_moving(ws.id)
        end
    end)
end)
hl.on("window.move_to_workspace", function(w, ws)
    windows_under_later(ws)
end)

-- Every change of a window's fullscreen state: F11, SUPER + F, and apps going fullscreen on
-- their own (the fullscreen button of a video player, games). Wrapped in pcall so a hiccup can
-- never break the config.
hl.on("window.fullscreen", function(w)
    track_fullscreen(w)
    pcall(function() windows_under_later(w.workspace) end)
    pcall(hold_real_blur, w)
    if not FULLSCREEN_LIKE_TILE or not is_real_fullscreen(w) then
        return                          -- framed look off, or not a window that covers the screen
    end
    pcall(fullscreen_to_tile, w)
    if is_real_fullscreen(w) then
        -- the change did not stick (Hyprland was still busy): try once more shortly
        hl.timer(function()
            pcall(fullscreen_to_tile, w)
        end, { timeout = 60, type = "oneshot" })
    end
end)

hl.on("window.open_early", forget_window)   -- a new window (addresses are reused)
hl.on("window.close", forget_window)

-- SUPER + F: maximize (fills the window area, keeps the gap and the rounded corners) and back
-- to the tile. A fullscreen window becomes maximized.
local function toggle_maximize()
    local w = hl.get_active_window()
    if not w then
        return
    end
    local state = w.fullscreen
    if type(state) ~= "number" then
        return
    end

    if FULLSCREEN_LIKE_TILE then
        -- the framed look: the app is not told it is maximized
        set_fullscreen_state(w, state ~= 0 and 0 or 1, 0)
    elseif state == 1 then
        set_fullscreen_state(w, 0, 0)               -- maximized -> its tile
    else
        set_fullscreen_state(w, 1, 1)               -- tile or fullscreen -> maximized
    end
end

-- F11: fullscreen on / off.
local function toggle_fullscreen()
    local w = hl.get_active_window()
    if not w then
        return
    end
    local state = w.fullscreen
    if type(state) ~= "number" then
        return
    end

    if FULLSCREEN_LIKE_TILE then
        -- the framed look: fill the window area, tell the app it is fullscreen
        if state ~= 0 then
            set_fullscreen_state(w, 0, 0)
        else
            set_fullscreen_state(w, 1, 2)
            resync_fullscreen(w)
        end
        return
    end

    local id = w.address                            -- nil only if the window just closed
    if state >= 2 then
        -- leave fullscreen: back to maximized if it was maximized before, else to its tile
        local back_to_max = state == 3 or (id ~= nil and fs_from_max[id] == true)
        if id ~= nil then
            fs_from_max[id] = nil
        end
        if back_to_max then
            set_fullscreen_state(w, 1, 1)
        else
            hl.dispatch(hl.dsp.window.fullscreen({ window = w, mode = "fullscreen", action = "unset" }))
        end
    else
        -- cover the screen; from maximized it is 3 ("maximized + fullscreen", see above), so
        -- leaving it - with F11 or in the app - goes back to maximized
        if id ~= nil then
            fs_seen[id] = state
            fs_from_max[id] = (state == 1) or nil
        end
        local target = state == 1 and 3 or 2
        set_fullscreen_state(w, target, target)
    end
end


---------------------
---- KEYBINDINGS ----
---------------------

-- Hyprland's default keybinds (the ones in Hyprland's own example config), then the shell's
-- extras on keys the defaults leave free. Every bind has a `description`: the Settings app's
-- Keybinds page lists them from there (hyprctl binds -j), also ones you add yourself.
--
-- The one key that takes a combination away from apps: F11 (fullscreen).

local mod = "SUPER"

-- The app launcher (SUPER + R), the app switcher (SUPER + Space) and the emoji picker (SUPER + .)
-- close when you use any other shortcut --------------------------------------------------
-- The shell tells Hyprland when they open and close (modules/Launcher.qml, Switcher.qml and
-- EmojiPicker.qml call hyprctl dispatch 'frameshell_launcher(true / false)' /
-- 'frameshell_switcher(true / false)' / 'frameshell_emoji(true / false)'), and while one is open
-- every key bind below closes it first, then does what it does.
-- Not their own keys (SUPER + R toggles the launcher, SUPER + Space steps the switcher, SUPER + .
-- toggles the emoji picker), not
-- letting go of SUPER (that ends SUPER + Space, and comes right after SUPER + R) and not the
-- mouse binds: those are off while one is open (mouse_binds below), so a click with SUPER held
-- reaches them too - and closes them, like any click outside them - instead of dragging a window.
-- The shortcut waits until the launcher / switcher has let go of the keyboard: while it holds
-- it (exclusively), Hyprland keeps the focus on it and ignores focusing a window, so SUPER + Left
-- / Right would go to the wrong window or not on to the next workspace. The shell says when it
-- has closed; LAUNCHER_SETTLE ms later the shortcut runs. Should the shell not answer, it
-- runs after LAUNCHER_WAIT ms anyway.
local LAUNCHER_SETTLE = 60
local LAUNCHER_WAIT   = 600
local launcher_open = false
local switcher_open = false
local emoji_open    = false
local launcher_toggle = hl.dsp.exec_cmd(launcher)      -- SUPER + R (bound below)
local waiting = {}            -- shortcuts used while the launcher / switcher was closing, in order
local closing = 0             -- counts the closes (a late fallback of an earlier one does nothing)
-- shortcuts that don't wait (they close the launcher and run at once): SUPER + Space - the
-- switcher takes the keyboard itself, and waiting, a quick tap would let go of SUPER before it is there
local launcher_immediate = {}
-- the switcher's own shortcuts (SUPER + Space): they step it, they don't close it
local switcher_keys = {}

-- what a bind does: a dispatcher or a function
local function run(action)
    if type(action) == "function" then
        action()
    else
        hl.dispatch(action)
    end
end

local function run_waiting()
    local list = waiting
    waiting = {}
    for _, action in ipairs(list) do
        pcall(run, action)
    end
end

-- SUPER + left / right drag (moving / resizing windows, bound below): off while the launcher,
-- the switcher or the emoji picker is open
local mouse_binds = {}
local function update_mouse_binds()
    local on = not launcher_open and not switcher_open and not emoji_open
    for _, b in ipairs(mouse_binds) do
        pcall(function() b:set_enabled(on) end)
    end
end

-- all closed: what was waiting runs
local function closed_now()
    update_mouse_binds()
    if not launcher_open and not switcher_open and not emoji_open and #waiting > 0 then
        hl.timer(run_waiting, { timeout = LAUNCHER_SETTLE, type = "oneshot" })
    end
end

function frameshell_launcher(open)
    return function()
        launcher_open = open == true
        closed_now()
    end
end

function frameshell_switcher(open)
    return function()
        switcher_open = open == true
        closed_now()
    end
end

function frameshell_emoji(open)
    return function()
        emoji_open = open == true
        closed_now()
    end
end

-- close the launcher / switcher (the switcher without switching) / emoji picker, then do `action`
local function close_then(action)
    waiting[#waiting + 1] = action
    if #waiting > 1 then
        return                -- already closing: it runs after the ones before it
    end
    closing = closing + 1
    local n = closing
    if launcher_open then
        hl.exec_cmd(qs .. " ipc call launcher close")
    end
    if switcher_open then
        hl.exec_cmd(qs .. " ipc call switcher cancel")
    end
    if emoji_open then
        hl.dispatch(hl.dsp.event("frameshell-emoji close"))
    end
    hl.timer(function()
        if closing == n and #waiting > 0 then
            launcher_open = false
            switcher_open = false
            emoji_open    = false
            update_mouse_binds()
            run_waiting()
        end
    end, { timeout = LAUNCHER_WAIT, type = "oneshot" })
end

-- hl.bind, closing the launcher / switcher / emoji picker first
local function bind(key, action, opts)
    if opts and (opts.mouse or opts.release) then
        return hl.bind(key, action, opts)
    end
    hl.bind(key, function()
        if switcher_open and switcher_keys[action] then
            run(action)                      -- the switcher's own key: the next app
        elseif action == launcher_toggle and not switcher_open and not emoji_open then
            run(action)                      -- the launcher's own key: open / close it
        elseif action == emoji_toggle and not switcher_open and not launcher_open and #waiting == 0 then
            run(action)                      -- the emoji picker's own key: open / close it
        elseif launcher_immediate[action] then
            if launcher_open then
                launcher_open = false
                hl.exec_cmd(qs .. " ipc call launcher close")
            end
            if emoji_open then
                emoji_open = false
                hl.dispatch(hl.dsp.event("frameshell-emoji close"))
            end
            run(action)
        elseif launcher_open or switcher_open or emoji_open or #waiting > 0 then
            close_then(action)               -- (still waiting ones: after them)
        else
            run(action)
        end
    end, opts)
end

-- the same action on several keys
local function bind_keys(keys, action, opts)
    for _, key in ipairs(keys) do
        bind(key, action, opts)
    end
end

-- Toggle window tiling (per workspace): switched off, every window on the current
-- workspace floats - the size of one tile of four (a 2 x 2 grid) in the middle of the screen -
-- and new windows opened there float the same way. Switch it on again to tile them. A window moved
-- from a tiled workspace to one without tiling floats the same way, and one moved from a
-- workspace without tiling to a tiled one is tiled (move_to_workspace below).
local untiled = {}                     -- workspace id -> true while tiling is off there

-- The shell shows those workspaces' pills a bit lighter (services/Spaces.qml): their numbers go
-- into ~/.local/state/frameshell/untiled, written in one go (a whole new file), whenever they
-- change - and none when Hyprland starts or reloads this file (tiling is on everywhere then).
local UNTILED_FILE = (os.getenv("XDG_STATE_HOME") or ((os.getenv("HOME") or "") .. "/.local/state")) .. "/frameshell/untiled"

local function save_untiled()
    pcall(function()
        local ids = {}
        for id in pairs(untiled) do
            ids[#ids + 1] = id
        end
        table.sort(ids)
        local part = UNTILED_FILE .. ".part"
        local f = io.open(part, "w")
        if not f then
            return                      -- no state folder yet: the shell has not run
        end
        f:write(table.concat(ids, " "), "\n")
        f:close()
        if not os.rename(part, UNTILED_FILE) then
            os.remove(part)
        end
    end)
end
save_untiled()

local function set_floating(w, on)
    hl.dispatch(hl.dsp.window.float({ window = w, action = on and "enable" or "disable" }))
end

local function window_id(w)
    if not w then
        return nil
    end
    local ok, address = pcall(function() return w.address end)
    return ok and address or nil
end

-- where a window is (its final position, also while it is still animating)
local function box_of(w)
    local ok, at, size = pcall(function() return w.at, w.size end)
    if not ok or type(at) ~= "table" or type(size) ~= "table" then
        return nil
    end
    return { x = at.x, y = at.y, w = size.x, h = size.y }
end

-- the size of the screen of monitor `m` in layout pixels (errors if `m` is no monitor)
local function screen_size(m)
    local scale = (type(m.scale) == "number" and m.scale > 0) and m.scale or 1
    local sw, sh = m.width / scale, m.height / scale
    if type(m.transform) == "number" and m.transform % 2 == 1 then
        sw, sh = sh, sw                       -- turned by 90 / 270 degrees
    end
    return sw, sh
end

-- the whole screen of monitor `m` (nil if it can't tell)
local function screen_box(m)
    local ok, b = pcall(function()
        local sw, sh = screen_size(m)
        return { x = m.x, y = m.y, w = math.floor(sw + 0.5), h = math.floor(sh + 0.5) }
    end)
    if ok and b and b.w >= 100 and b.h >= 100 then
        return b
    end
    return nil
end

-- two boxes are the same, give or take 2 px
local function near(a, b)
    return a ~= nil and b ~= nil and math.abs(a.x - b.x) <= 2 and math.abs(a.y - b.y) <= 2
        and math.abs(a.w - b.w) <= 2 and math.abs(a.h - b.h) <= 2
end

-- The window area of monitor `m`: the screen less what the shell reserves (frame, notch,
-- bottom bar) and WINDOW_GAP around it. nil if the monitor can't tell (Hyprland before 0.56:
-- no "reserved").
local function window_area(m)
    local ok, a = pcall(function()
        local r = m.reserved
        if type(r) ~= "table" then
            return nil
        end
        local sw, sh = screen_size(m)
        return {
            x = m.x + (r.left or 0) + WINDOW_GAP,
            y = m.y + (r.top or 0) + WINDOW_GAP,
            w = sw - (r.left or 0) - (r.right or 0) - 2 * WINDOW_GAP,
            h = sh - (r.top or 0) - (r.bottom or 0) - 2 * WINDOW_GAP,
        }
    end)
    return ok and a or nil
end

-- Where a window goes when tiling is off: one tile of four in a 2 x 2 grid (half the window
-- area each way, less the WINDOW_GAP between two tiles), in the middle of the window area of
-- monitor `m`. nil if the monitor can't tell.
local function untiled_box(m)
    local a = window_area(m)
    if not a then
        return nil
    end
    local w = math.floor((a.w - WINDOW_GAP) / 2)
    local h = math.floor((a.h - WINDOW_GAP) / 2)
    if w < 100 or h < 100 then
        return nil
    end
    return { x = math.floor(a.x + (a.w - w) / 2), y = math.floor(a.y + (a.h - h) / 2), w = w, h = h }
end

-- float `w` on box `b` (resize first: it resizes around its centre)
local function float_on(w, b)
    set_floating(w, true)
    if b then
        hl.dispatch(hl.dsp.window.resize({ window = w, x = b.w, y = b.h }))
        hl.dispatch(hl.dsp.window.move({ window = w, x = b.x, y = b.y }))
    end
end

-- Maximize on a workspace without tiling ----------------------------------------------
-- Hyprland draws the other windows under a maximized one only if they are tiled ("the other
-- windows under a maximized or fullscreen one" above); a floating window it can only draw over
-- it, never under it. On a workspace without tiling every window floats, so a see-through
-- maximized window there would show only the wallpaper. So there SUPER + F maximizes a window
-- as a floating window: it gets the size and the place of a maximized one (the window area
-- less the ring around the window: the same gap and rounded corners) and comes to the front;
-- the other windows stay where they are, under it, and show through. SUPER + F again puts it
-- back where it was; dragged or resized with the mouse it is a plain window again (SUPER + F
-- then maximizes it again). Hyprland and the app don't count it as maximized: a window that
-- opens there opens over it. F11 there works the same way ("Fullscreen on a workspace without
-- tiling" below).
local float_max = {}        -- [address] = { x, y, w, h }: where SUPER + F puts it back

-- where a maximized window is on monitor `m` (nil if the monitor can't tell)
local function max_box(m)
    local a = window_area(m)
    if not a then
        return nil
    end
    local ok, v = pcall(hl.get_config, "general.border_size")
    local ring = (ok and type(v) == "number" and v >= 0) and v or WINDOW_BORDER
    local b = {
        x = math.floor(a.x + ring + 0.5), y = math.floor(a.y + ring + 0.5),
        w = math.floor(a.w - 2 * ring + 0.5), h = math.floor(a.h - 2 * ring + 0.5),
    }
    if b.w < 100 or b.h < 100 then
        return nil
    end
    return b
end

-- true while `w` floats maximized like that (by where it is: also after a reload of this file)
local function at_max_box(w)
    local ok, yes = pcall(function()
        return w.floating and w.fullscreen == 0 and near(box_of(w), max_box(w.monitor))
    end)
    return ok and yes == true
end

-- `b` if its middle is in the window area of monitor `m` (else nil: it was on another screen)
local function on_screen(m, b)
    local a = b and window_area(m)
    if not a then
        return nil
    end
    local cx, cy = b.x + b.w / 2, b.y + b.h / 2
    if cx < a.x or cx > a.x + a.w or cy < a.y or cy > a.y + a.h then
        return nil
    end
    return b
end

-- maximize `w` like that; `back` = where SUPER + F puts it back (default: where it is now).
-- false if the monitor can't tell where (then nothing changes).
local function float_maximize(w, back)
    local b = max_box(w.monitor or hl.get_active_monitor())
    local id = window_id(w)
    if not b or not id then
        return false
    end
    float_max[id] = back or box_of(w)
    float_on(w, b)
    hl.dispatch(hl.dsp.window.alter_zorder({ mode = "top", window = w }))
    return true
end

-- SUPER + F again: back where it was - or, not known (or on another screen by now), in the
-- middle like a new window
local function float_unmaximize(w)
    local id = window_id(w)
    local m = w.monitor or hl.get_active_monitor()
    local back = on_screen(m, id and float_max[id])
    if id then
        float_max[id] = nil
    end
    float_on(w, back or untiled_box(m))
end

-- From fullscreen (F11) or Hyprland's own maximize to the maximize above. It goes back (SUPER + F)
-- to where it floated before - if it was maximized like this before, to where it was before that
-- (still remembered) - else to `fallback` or the middle. false if the monitor can't tell (then it
-- stays as it is).
local function float_max_from_fullscreen(w, fallback)
    local m = w.monitor or hl.get_active_monitor()
    local mb = max_box(m)
    if not mb then
        return false
    end
    local was_floating = w.floating
    set_fullscreen_state(w, 0, 0)
    local back
    local b = was_floating and box_of(w)
    if b and at_max_box(w) then
        back = float_max[window_id(w) or ""]
    elseif b and b.w >= 100 and b.h >= 100 and b.w <= mb.w and b.h <= mb.h then
        back = b
    end
    return float_maximize(w, back or fallback or untiled_box(m))
end

-- The Settings app's "Window gap" slider (Appearance): the shell runs this with the new gap
-- (modules/HyprSync.qml), and the tiles - and Hyprland's maximize - move to it at once. A
-- window maximized on a workspace without tiling (floating, above) is fitted to the new window
-- area too; new windows there (the middle box) get it from now on.
function frameshell_gap(px)
    px = tonumber(px)
    if not px then
        return
    end
    px = math.max(0, math.floor(px + 0.5))
    if px == WINDOW_GAP then
        return
    end
    local maxed = {}            -- maximized like that with the old gap
    pcall(function()
        for _, w in ipairs(hl.get_windows() or {}) do
            if w.workspace and untiled[w.workspace.id] and at_max_box(w) then
                maxed[#maxed + 1] = w
            end
        end
    end)
    WINDOW_GAP = px
    hl.config({ general = gap_config(px) })
    for _, w in ipairs(maxed) do
        pcall(function()
            float_on(w, max_box(w.monitor or hl.get_active_monitor()))
        end)
    end
end

-- Fullscreen on a workspace without tiling ---------------------------------------------
-- The same for F11 there: Hyprland's fullscreen would hide every other window too. So there F11
-- makes the window a floating window over the whole screen - no border, square corners, in
-- front - and tells the app it is fullscreen (a browser or a video player hides its own
-- controls); the other windows stay under it and show through. Hyprland hides the shell
-- (frame, notch, bottom bar, notifications) only for its own fullscreen, so the shell is told to
-- hide on that screen meanwhile ("ui cover" below; the app switcher and the launcher still
-- open). F11 again, or the app leaving fullscreen by itself (Esc in a video), puts it back:
-- maximized if it was maximized, else where it was; SUPER + F makes it maximized. (Unlike
-- Hyprland's fullscreen it does not keep the screen on.) Apps that go fullscreen by themselves
-- (a game, the fullscreen button of a video) still get Hyprland's fullscreen, as everywhere -
-- for games it is smoother (nothing else is drawn).
local float_fs = {}         -- [address] = { back = box, max = true / false } while it covers the screen

-- true while `w` covers the screen like that (by where it is: also after a reload of this file)
local function covers_screen(w)
    local ok, yes = pcall(function()
        return w.floating and w.fullscreen == 0 and (w.fullscreen_client or 0) >= 2
            and near(box_of(w), screen_box(w.monitor))
    end)
    return ok and yes == true
end

local function in_float_fs(w)
    local id = window_id(w)
    return (id ~= nil and float_fs[id] ~= nil) or covers_screen(w)
end

-- The shell hides its overlay on the screens listed (Ui.coveredScreens, modules/Overlay.qml) - at
-- once, as Hyprland hides it for its own fullscreen: an event on Hyprland's event socket, which
-- the shell listens to anyway (modules/UiIpc.qml), "custom>>frameshell-cover DP-1 HDMI-A-1"
-- (none: "frameshell-cover"). Worked out from the windows (the active workspace of each screen),
-- told only when it changes.
local cover_sent = nil      -- the list last told to the shell
local cover_pending = false

local function cover_now()
    local names = {}
    for _, m in ipairs(hl.get_monitors() or {}) do
        pcall(function()
            local ws = m.active_workspace
            if not ws or not untiled[ws.id] then
                return
            end
            for _, o in ipairs(hl.get_workspace_windows(ws.id) or {}) do
                if o.hidden ~= true and covers_screen(o) then
                    names[#names + 1] = m.name
                    return
                end
            end
        end)
    end
    table.sort(names)
    local list = table.concat(names, " ")
    if list ~= cover_sent then
        cover_sent = list
        hl.dispatch(hl.dsp.event("frameshell-cover " .. list))
    end
end

local function cover_later()
    if cover_pending then
        return
    end
    cover_pending = true
    local queued = pcall(hl.timer, function()
        cover_pending = false
        pcall(cover_now)
    end, { timeout = 1, type = "oneshot" })
    if not queued then
        cover_pending = false
    end
end

-- for events that come often (focus, workspace): only while something covers a screen
local function cover_maybe()
    if next(float_fs) ~= nil or (cover_sent ~= nil and cover_sent ~= "") then
        cover_later()
    end
end

-- the shell asks for the list when it starts (a restart while a screen is covered)
function frameshell_cover_sync()
    return function()
        cover_sent = nil
        pcall(cover_now)
    end
end
pcall(hl.timer, function() pcall(cover_now) end, { timeout = 1000, type = "oneshot" })   -- after a reload

-- no border, square corners, no shadow
local function fs_props(w, on)
    local function set(prop, value)
        hl.dispatch(hl.dsp.window.set_prop({ window = w, prop = prop, value = on and value or "unset" }))
    end
    set("border_size", "0")
    set("rounding", "0")
    set("no_shadow", "1")
end

-- F11 there. false if the monitor can't tell its size (then nothing changes).
local function float_fullscreen(w)
    local m = w.monitor or hl.get_active_monitor()
    local sb, id = screen_box(m), window_id(w)
    if not sb or not id then
        return false
    end
    local rec = { back = box_of(w), max = at_max_box(w) }
    fs_props(w, true)
    float_on(w, sb)
    set_fullscreen_state(w, 0, 2)       -- the app is told it is fullscreen ...
    resync_fullscreen(w)                -- ... and may leave it by itself (Esc in a video)
    hl.dispatch(hl.dsp.window.alter_zorder({ mode = "top", window = w }))
    float_fs[id] = rec                  -- last: the steps above must not read as "it left"
    pcall(cover_now)                    -- the shell hides at once, with the window growing
    return true
end

-- F11 again (or the app left fullscreen): back maximized if it was maximized, else where it was
-- (or the middle). `to_max` (SUPER + F): maximized either way.
local function float_unfullscreen(w, to_max)
    local id = window_id(w)
    local rec = id and float_fs[id]
    if id then
        float_fs[id] = nil              -- first: the steps below must not read as "it left"
    end
    local m = w.monitor or hl.get_active_monitor()
    local back = on_screen(m, rec and rec.back)
    fs_props(w, false)
    set_fullscreen_state(w, 0, 0)
    if rec and rec.max then
        float_on(w, max_box(m) or back or untiled_box(m))   -- SUPER + F still puts it back as before
    elseif to_max then
        if not float_maximize(w, back or untiled_box(m)) then
            float_on(w, back or untiled_box(m))
        end
    else
        float_on(w, back or untiled_box(m))
    end
    pcall(cover_now)                    -- the shell is back at once, with the window shrinking
end

-- the app left fullscreen by itself (Esc in a video), or Hyprland's fullscreen it went into from
-- there has ended: put it back. Only its "client" state changes then, which Hyprland reports
-- as a change of its rules, not of its fullscreen.
local function fs_left_later(w)
    local id = window_id(w)
    local rec = id and float_fs[id]
    if not rec or rec.leaving then
        return
    end
    local ok, state, client = pcall(function() return w.fullscreen, w.fullscreen_client end)
    if not ok or state ~= 0 or client ~= 0 then
        return
    end
    rec.leaving = true
    pcall(hl.timer, function()
        if float_fs[id] == rec then
            pcall(float_unfullscreen, w)
        end
    end, { timeout = 1, type = "oneshot" })
end

hl.on("window.update_rules", fs_left_later)
hl.on("window.fullscreen", function(w)
    fs_left_later(w)
    cover_maybe()
end)
hl.on("window.close", function(w)
    pcall(function() float_fs[w.address] = nil end)
    cover_maybe()
end)
hl.on("window.move_to_workspace", cover_maybe)
hl.on("workspace.active", cover_maybe)

-- SUPER + F: there like that, elsewhere Hyprland's maximize (toggle_maximize above)
local function maximize_key()
    local w = hl.get_active_window()
    if not w then
        return
    end
    local ok, here, state = pcall(function()
        return w.workspace ~= nil and untiled[w.workspace.id] == true, w.fullscreen
    end)
    local done = false
    if ok and here and in_float_fs(w) then
        pcall(float_unfullscreen, w, true)                      -- covering the screen -> maximized
        done = true
    elseif ok and here and state == 0 then
        if at_max_box(w) then
            pcall(float_unmaximize, w)
            done = true
        else
            local ok2, res = pcall(float_maximize, w)
            done = ok2 and res == true
        end
    elseif ok and here and type(state) == "number" and state >= 2 and not FULLSCREEN_LIKE_TILE then
        local ok2, res = pcall(float_max_from_fullscreen, w)   -- fullscreen -> maximized
        done = ok2 and res == true
    end
    if not done then
        toggle_maximize()
    end
end

-- F11: there like that, elsewhere Hyprland's fullscreen (toggle_fullscreen above)
local function fullscreen_key()
    local w = hl.get_active_window()
    if not w then
        return
    end
    local ok, here, state = pcall(function()
        return w.workspace ~= nil and untiled[w.workspace.id] == true, w.fullscreen
    end)
    local done = false
    if ok and here and not FULLSCREEN_LIKE_TILE then
        if in_float_fs(w) then
            pcall(float_unfullscreen, w)
            done = true
        elseif state == 0 then
            local ok2, res = pcall(float_fullscreen, w)
            done = ok2 and res == true
        end
    end
    if not done then
        toggle_fullscreen()
    end
end

-- A window that gets Hyprland's maximize there anyway (F11 back to maximized, a maximized window
-- that was fullscreen when tiling went off) is turned into this one a moment later.
local function hypr_max_untiled(w)
    local ok, yes = pcall(function()
        return w.mapped == true and w.fullscreen == 1 and (w.fullscreen_client or 0) < 2
            and w.workspace ~= nil and untiled[w.workspace.id] == true
            and max_box(w.monitor) ~= nil
    end)
    return ok and yes == true
end

hl.on("window.fullscreen", function(w)
    if not hypr_max_untiled(w) then
        return
    end
    pcall(hl.timer, function()
        if hypr_max_untiled(w) then
            pcall(float_max_from_fullscreen, w)
        end
    end, { timeout = 1, type = "oneshot" })
end)

-- With a window maximized or covering the screen like that, a window you go to with the keys
-- (SUPER + arrow keys) or pick in the app switcher, the dock or the island comes to the front -
-- as it does over Hyprland's maximize. (Not one the pointer moves onto: that one is in front
-- already.) And a click / drag may have changed what covers a screen.
local FOCUS_BY_KEY, FOCUS_BY_DISPATCH = 2, 3    -- Hyprland's focus reasons (keybind, focus dispatch)

hl.on("window.active", function(w, reason)
    cover_maybe()
    if reason ~= FOCUS_BY_KEY and reason ~= FOCUS_BY_DISPATCH then
        return
    end
    pcall(hl.timer, function()
        pcall(function()
            local ws = w.workspace
            if w.mapped ~= true or not w.floating or not ws or not untiled[ws.id] then
                return
            end
            for _, o in ipairs(hl.get_workspace_windows(ws.id) or {}) do
                if at_max_box(o) or covers_screen(o) then
                    hl.dispatch(hl.dsp.window.alter_zorder({ mode = "top", window = w }))
                    return
                end
            end
        end)
    end, { timeout = 1, type = "oneshot" })
end)

local function toggle_workspace_tiling()
    local ws = hl.get_active_workspace()
    if not ws then
        return
    end
    local off = not untiled[ws.id]
    untiled[ws.id] = off or nil
    save_untiled()
    local box = off and untiled_box(hl.get_active_monitor())
    local maximize, fullscreen = {}, {}
    for _, w in ipairs(hl.get_workspace_windows(ws.id) or {}) do
        if off then
            -- every window into the middle; a maximized one stays maximized (as a floating
            -- window, "Maximize on a workspace without tiling" above) until you end that
            pcall(function()
                if hypr_max_untiled(w) then
                    float_max_from_fullscreen(w, box or nil)
                elseif not w.floating then
                    float_on(w, w.fullscreen == 0 and box or nil)
                end
            end)
        elseif w.floating then
            -- tiled again; one maximized or covering the screen like that gets Hyprland's
            -- maximize / fullscreen (below)
            if in_float_fs(w) then
                local rec = float_fs[window_id(w) or ""]
                fullscreen[#fullscreen + 1] = { w = w, max = rec ~= nil and rec.max == true }
                pcall(float_unfullscreen, w)
            elseif at_max_box(w) then
                maximize[#maximize + 1] = w
            end
            pcall(set_floating, w, false)
        end
    end
    for _, w in ipairs(maximize) do
        pcall(set_fullscreen_state, w, 1, FULLSCREEN_LIKE_TILE and 0 or 1)
    end
    for _, f in ipairs(fullscreen) do
        if f.max then
            pcall(set_fullscreen_state, f.w, 1, 1)    -- maximized first: F11 goes back to it
            pcall(set_fullscreen_state, f.w, 3, 3)
        else
            pcall(set_fullscreen_state, f.w, 2, 2)
        end
    end
end

-- windows that float on their own (dialogs, pickers: floating as they open), by address -
-- a minimized one comes back floating, whatever workspace it was on (frameshell_restore)
local floats_on_own = {}

-- a window opened there (that would be tiled) floats in the middle too; dialogs and helpers
-- that float on their own keep their size
hl.on("window.open", function(w)
    pcall(function()
        floats_on_own[w.address] = w.floating or nil
    end)
    local ok, id = pcall(function() return w.workspace and w.workspace.id end)
    if ok and id and untiled[id] and not w.floating then
        pcall(function()
            local m = w.monitor or hl.get_active_monitor()
            float_on(w, w.fullscreen == 0 and untiled_box(m) or nil)
        end)
    end
end)

-- A window opening into the tiles of a workspace with a maximized window (SUPER + F): Hyprland
-- ends that maximize anyway once the new window is in (misc:on_focus_under_fullscreen), but it
-- places the new window first - and while a window is maximized, Hyprland does not update the
-- tiles' sizes (a window closed or minimized beside it leaves its tile half the size), so the
-- new window could open under it instead of beside it. Ended first, the new window opens where
-- it would without the maximize: on the right (below only in a tall tile). Not for a window
-- that opens floating (a dialog stays over the maximized one), and not for F11.
hl.on("window.open_early", function(w)
    pcall(function()
        if w.floating then
            return
        end
        local ws = w.workspace
        if not ws or untiled[ws.id] then
            return
        end
        for _, o in ipairs(hl.get_workspace_windows(ws.id) or {}) do
            pcall(function()
                if o.address ~= w.address and not o.floating and o.fullscreen == 1
                    and (o.fullscreen_client or 0) < 2 then
                    set_fullscreen_state(o, 0, 0)
                end
            end)
        end
    end)
end)

hl.on("workspace.removed", function(ws)
    local ok, id = pcall(function() return ws.id end)
    if ok and id and untiled[id] then
        untiled[id] = nil              -- a new workspace with the same number starts tiled again
        save_untiled()
    end
end)

-- App switcher on SUPER + Space (drawn by the shell). Hold SUPER and tap Space to walk through
-- the apps (most recently used first); let go of SUPER to switch. The shell notices the SUPER
-- release itself once it holds the keyboard; the release binds below cover the moment before.
-- They only call the shell when Space was really pressed, not after every SUPER shortcut.
local switching = false

local function switcher_next()
    switching = true
    hl.exec_cmd(qs .. " ipc call switcher next")
end

local function switcher_release()
    if switching then
        switching = false
        hl.exec_cmd(qs .. " ipc call switcher release")
    end
end
launcher_immediate[switcher_next] = true
switcher_keys[switcher_next] = true


-- Workspace to the left / right at the edge of the screen ------------------------
-- SUPER + Left / Right focus the window to the left / right, and when there is no window
-- that way (you are at the edge of the screen, or the workspace is empty) they go on to the
-- workspace to the left / right.
-- SUPER + SHIFT + Left / Right do the same for moving: they move the window left / right, and when it
-- is already at the edge (no window beside it that way) they carry it on to the workspace to
-- the left / right, and you go with it. A floating window (every window on a workspace
-- without tiling) is carried on to the workspace to the left / right at once.
-- Both stop at workspace 1 and at workspaceMax (Config.qml, 5: the last workspace).
local WORKSPACE_MAX = math.max(1, math.min(10, shell_setting("workspaceMax", 5)))

-- the workspace number `step` away from the current one, or nil past 1 / WORKSPACE_MAX
local function workspace_beside(step)
    local ws = hl.get_active_workspace()
    local target = ((ws and ws.id) or 1) + step
    if target >= 1 and target <= WORKSPACE_MAX then
        return target
    end
    return nil
end

local function focus_or_workspace(direction, step)
    local before = window_id(hl.get_active_window())
    if before then
        hl.dispatch(hl.dsp.focus({ direction = direction }))
        if window_id(hl.get_active_window()) ~= before then
            return                                   -- there was a window that way
        end
    end
    local target = workspace_beside(step)
    if target then
        hl.dispatch(hl.dsp.focus({ workspace = target }))
    end
end

-- true when another tiled window of the same workspace sits beside `w` in that direction
local function tile_beside(w, direction)
    local me = box_of(w)
    local ok, ws = pcall(function() return w.workspace end)
    if not me or not ok or not ws then
        return false
    end
    for _, o in ipairs(hl.get_workspace_windows(ws.id) or {}) do
        local b = window_id(o) ~= window_id(w) and not o.floating and box_of(o)
        if b and b.y < me.y + me.h and b.y + b.h > me.y then        -- they overlap vertically
            if direction == "left" and b.x + b.w <= me.x + 1 then
                return true
            elseif direction == "right" and b.x >= me.x + me.w - 1 then
                return true
            end
        end
        if b and b.x < me.x + me.w and b.x + b.w > me.x then        -- they overlap horizontally
            if direction == "up" and b.y + b.h <= me.y + 1 then
                return true
            elseif direction == "down" and b.y >= me.y + me.h - 1 then
                return true
            end
        end
    end
    return false
end

-- Moving a window to another workspace ----------------------------------------------
-- On its own, Hyprland puts the window on the other workspace at once: for a frame or two it
-- is gone from the screen, then it flies back in from the edge with the new workspace (and
-- grows / moves to its new tile on top of that), so it runs ahead of everything else.
-- Here it stays on screen and glides from where it is to where it will be, while the
-- workspaces slide - same curve, same 300 ms, so it arrives together with them.
--
-- Where it lands: on the side it comes from. Moved to a workspace on the right it takes the
-- left-most place there (beside the left-most window, on its left); moved to the left, the
-- right-most place. On an empty workspace it fills the screen as usual.
--
-- How: the window becomes a pinned floating window exactly where it is (pinned windows don't
-- slide with the workspaces, so nothing moves yet), the view goes to the other workspace, the
-- window is tiled there for a moment to learn its place and comes straight back, then glides
-- there. If one window is there already, it makes room at the same time (it floats for that
-- moment, at its own place). The moment the slide is over both are tiled for good, right
-- where they already are, so nothing moves any more. (With two or more windows there, they
-- make room right after the slide: floating them would lose your split sizes.)
-- A floating window keeps its place on the screen, like Hyprland does. Fullscreen and
-- maximized windows move the plain way (Hyprland can't pin them).
-- carrying: window address -> {
--   target, tiled (was it tiled), side ("l" / "r": the side of the other windows it takes),
--   center_y (where it came from), others (tiled windows already there), anchor (address of
--   the one window making room, when there is exactly one), n (latest move), queue }
local carrying = {}
local move_or_workspace                -- (below) SUPER + SHIFT + Left / Right

-- A quick SUPER + SHIFT + Left / Right while the window is still on its way that can't be done right
-- away (two or more windows there) waits until it has settled, so it is never lost.
local function run_queue(id, q)
    while #q > 0 do
        local w = hl.get_active_window()
        if not w or window_id(w) ~= id then
            return                     -- you switched to another window meanwhile
        end
        local item = table.remove(q, 1)
        move_or_workspace(item[1], item[2])
        local rec = carrying[id]
        if rec then                    -- it set off to another workspace: the rest waits for that
            for _, it in ipairs(q) do
                table.insert(rec.queue, it)
            end
            return
        end
    end
end

-- the tiled windows of workspace `ws` (but `skip`), each { win, id, box }
local function tiled_windows(ws, skip)
    local out = {}
    for _, o in ipairs(hl.get_workspace_windows(ws) or {}) do
        local oid = window_id(o)
        local b = oid ~= skip and not o.floating and box_of(o)
        if b then
            out[#out + 1] = { win = o, id = oid, box = b }
        end
    end
    return out
end

-- Moving a tiled window within its workspace (SUPER + SHIFT + arrow keys).
-- Dwindle moves a window by taking it out and putting it in again just past its edge, so:
-- * nothing beside it that way: it stays (dwindle would turn it into a strip along that edge)
-- * when the windows on that side can only be the other half of its split, it swaps places
--   with them as a whole ("swapsplit": the two halves of its split change sides) - e.g. a
--   window on the left beside a column of two, or one at the bottom under a row of two
-- * otherwise dwindle moves it, as before
-- Returns false when there was nothing that way (SUPER + SHIFT + Left / Right then go on to the next
-- workspace).
--
-- The other half of its split (its "partner"): the windows in a rectangle as tall as the window
-- (moving left / right) or as wide (up / down), from the window to the far edge of some window
-- that way, with every other window either completely in it or completely out of it. The real
-- partner is always such a rectangle; when there is exactly one on that side and none on the
-- three others, that one is it. Otherwise it is unclear (two windows above two others look the
-- same split either way), and dwindle moves it.
local OPPOSITE = { left = "right", right = "left", up = "down", down = "up" }
local ACROSS = { left = { "up", "down" }, right = { "up", "down" }, up = { "left", "right" }, down = { "left", "right" } }

-- a box in "move" coordinates: u along the move (growing that way), v across it
local function to_uv(b, direction)
    if direction == "right" then
        return b.x, b.x + b.w, b.y, b.y + b.h
    elseif direction == "left" then
        return -(b.x + b.w), -b.x, b.y, b.y + b.h
    elseif direction == "down" then
        return b.y, b.y + b.h, b.x, b.x + b.w
    end
    return -(b.y + b.h), -b.y, b.x, b.x + b.w                  -- up
end

-- how many such rectangles there are on the `direction` side of box `me` (`others`: the boxes of
-- the other tiled windows there)
local function partners_on(me, others, direction)
    local T = 2
    local u1, u2, v1, v2 = to_uv(me, direction)
    local fars = {}
    for _, b in ipairs(others) do
        local a1, a2, c1, c2 = to_uv(b, direction)
        if a1 >= u2 - T and c1 < v2 - T and c2 > v1 + T then     -- that way, and level with it
            fars[#fars + 1] = a2
        end
    end
    table.sort(fars)
    local count, last = 0, nil
    for _, far in ipairs(fars) do
        if last == nil or far > last + T then
            last = far
            local inside, clean = 0, true
            for _, b in ipairs(others) do
                local a1, a2, c1, c2 = to_uv(b, direction)
                if a1 >= u2 - T and a2 <= far + T and c1 >= v1 - T and c2 <= v2 + T then
                    inside = inside + 1
                elseif not (a2 <= u1 + T or a1 >= far - T or c2 <= v1 + T or c1 >= v2 - T) then
                    clean = false               -- this one sticks out of the rectangle
                    break
                end
            end
            if clean and inside > 0 then
                count = count + 1
            end
        end
    end
    return count
end

local function move_within(w, direction)
    if not tile_beside(w, direction) then
        return false
    end
    local me = box_of(w)
    local ok, ws = pcall(function() return w.workspace.id end)
    local others = {}
    for _, t in ipairs(ok and tiled_windows(ws, window_id(w)) or {}) do
        others[#others + 1] = t.box
    end
    local swap = me ~= nil and partners_on(me, others, direction) == 1
        and partners_on(me, others, OPPOSITE[direction]) == 0
        and partners_on(me, others, ACROSS[direction][1]) == 0
        and partners_on(me, others, ACROSS[direction][2]) == 0
    -- also always clear: a window as tall as all the windows (left / right) - or as wide (up /
    -- down) - at the edge it moves away from (its partner can only be on the side it moves to,
    -- e.g. the left one of three columns)
    if me and not swap and #others > 0 then
        local T = 2
        local e = { l = me.x, t = me.y, r = me.x + me.w, b = me.y + me.h }
        for _, b in ipairs(others) do
            e.l, e.t = math.min(e.l, b.x), math.min(e.t, b.y)
            e.r, e.b = math.max(e.r, b.x + b.w), math.max(e.b, b.y + b.h)
        end
        local tall = me.y <= e.t + T and me.y + me.h >= e.b - T
        local wide = me.x <= e.l + T and me.x + me.w >= e.r - T
        swap = (direction == "right" and tall and me.x <= e.l + T)
            or (direction == "left" and tall and me.x + me.w >= e.r - T)
            or (direction == "down" and wide and me.y <= e.t + T)
            or (direction == "up" and wide and me.y + me.h >= e.b - T)
    end
    blur_live_while_moving()
    if swap then
        hl.dispatch(hl.dsp.layout("swapsplit"))
    else
        hl.dispatch(hl.dsp.window.move({ direction = direction }))
    end
    return true
end

-- the move keys: a tiled window as above; a floating one goes to that edge of the screen
local function move_key(direction)
    return function()
        local w = hl.get_active_window()
        if not w then
            return
        end
        local ok, floating = pcall(function() return w.floating end)
        if ok and floating then
            hl.dispatch(hl.dsp.window.move({ direction = direction }))
        else
            pcall(move_within, w, direction)
        end
    end
end

-- the tiled window on workspace `ws` at the edge facing where the moved window comes from:
-- the left-most one when `side` is "l", the right-most when "r" (nil: no tiled windows)
local function edge_window(ws, side, skip, center_y)
    local best, best_edge, best_dy
    for _, t in ipairs(tiled_windows(ws, skip)) do
        local b = t.box
        local edge = side == "l" and b.x or -(b.x + b.w)
        local dy = math.abs(b.y + b.h / 2 - center_y)
        if best == nil or edge < best_edge - 1 or (math.abs(edge - best_edge) <= 1 and dy < best_dy) then
            best, best_edge, best_dy = b, edge, dy
        end
    end
    return best
end

-- put a floating window exactly on box `b` (resize first: it resizes around its centre)
local function place(w, b)
    hl.dispatch(hl.dsp.window.resize({ window = w, x = b.w, y = b.h }))
    hl.dispatch(hl.dsp.window.move({ window = w, x = b.x, y = b.y }))
end

-- Tile `w` into the active workspace on the given side of its edge window - or, with `split`
-- "d", under it (the edge window keeps the top half). Dwindle splits the tile under the mouse
-- pointer, so the pointer is put on that window for this moment (and then back where it was:
-- you don't see it move), and "preselect" picks the side.
local function tile_at_side(w, id, side, center_y, split)      -- w: window object or "address:0x…"
    local ws = hl.get_active_workspace()
    local anchor = ws and edge_window(ws.id, side, id, center_y)
    local cursor = anchor and hl.get_cursor_pos()
    if anchor then
        hl.dispatch(hl.dsp.cursor.move({ x = anchor.x + anchor.w / 2, y = anchor.y + anchor.h / 2 }))
        hl.dispatch(hl.dsp.layout("preselect " .. (split or side)))
    end
    set_floating(w, false)
    if cursor then
        hl.dispatch(hl.dsp.cursor.move({ x = cursor.x, y = cursor.y }))
    end
end

-- 5. settle in the moment the slide (or the last glide) is over: unpin it and tile it for
-- good - right where it already is - then any quick presses that had to wait
local carry_count = 0
local function schedule_settle(id, rec)
    carry_count = carry_count + 1
    local n = carry_count
    rec.n = n
    hl.timer(function()
        local r = carrying[id]
        if not r or r.n ~= n then
            return                     -- moved again meanwhile: that move settles it
        end
        carrying[id] = nil
        local sel = "address:" .. id
        local target = r.target
        pcall(function()
            hl.dispatch(hl.dsp.window.pin({ window = sel, action = "disable" }))
            if r.anchor then
                pcall(set_floating, "address:" .. r.anchor, false)   -- first: it is the one split
            end
            local ws = hl.get_active_workspace()
            if ws and ws.id ~= target then
                -- you went on to yet another workspace during the slide: it stays where it was sent
                hl.dispatch(hl.dsp.window.move({ window = sel, workspace = target, follow = false }))
                if r.tiled and not untiled[target] then
                    hl.dispatch(hl.dsp.window.float({ window = sel, action = "disable" }))
                end
            else
                if r.tiled and not untiled[target] then
                    tile_at_side(sel, id, r.side, r.center_y, r.split)
                end
                run_queue(id, r.queue)
            end
        end)
    end, { timeout = SLIDE_SPEED * 100 + 10, type = "oneshot" })
end

-- SUPER + SHIFT + Left / Right while it is still on its way, with one window there: to its other side,
-- at once (it glides on from where it is, the other window with it)
local function swap_sides(w, id, rec)
    local side = rec.side == "l" and "r" or "l"
    pcall(function()
        hl.dispatch(hl.dsp.window.pin({ window = w, action = "disable" }))
        if rec.anchor then
            pcall(set_floating, "address:" .. rec.anchor, false)
        end
        tile_at_side(w, id, side, rec.center_y)
        local new = box_of(w)
        local a = rec.anchor and hl.get_window("address:" .. rec.anchor)
        local room = a and box_of(a)
        set_floating(w, true)
        hl.dispatch(hl.dsp.window.pin({ window = w, action = "enable" }))
        if new then
            place(w, new)
        end
        if room then
            set_floating(a, true)
            place(a, room)
        end
        rec.side = side
    end)
    schedule_settle(id, rec)
end

local function move_to_workspace(w, target)
    if not w or not target then
        return
    end
    local id = window_id(w)
    local ok, current, fullscreen, floating = pcall(function()
        return w.workspace and w.workspace.id, w.fullscreen, w.floating
    end)
    if not ok or current == target then
        return
    end
    local rec = carrying[id or ""]
    -- covering the screen as a floating window (F11 with tiling off here), to a workspace with
    -- tiling: out of it first, like below
    if id and rec == nil and untiled[current] == true and untiled[target] ~= true and in_float_fs(w) then
        pcall(float_unfullscreen, w)
    end
    -- maximized / fullscreen, to the other kind of workspace (tiling on there and off here, or
    -- off there and on here): out of it first, then it fits in there like any window - tiled,
    -- or floating in the middle. To the same kind it stays maximized / fullscreen (below).
    if id and fullscreen ~= 0 and rec == nil and (untiled[current] == true) ~= (untiled[target] == true) then
        pcall(set_fullscreen_state, w, 0, 0)
        local ok2, fs2, fl2 = pcall(function() return w.fullscreen, w.floating end)
        if ok2 then
            fullscreen, floating = fs2, fl2
        end
    end
    local old = box_of(w)
    if not id or not old or (fullscreen ~= 0 and rec == nil) then
        hl.dispatch(hl.dsp.window.move({ window = w, workspace = target }))
        return
    end
    -- tiled there if it was tiled here - or floats here only because tiling is off here
    local tiled = (rec and rec.tiled) or (rec == nil and (not floating or untiled[current] == true))
    -- into a workspace without tiling, a window that was tiled floats in the middle (untiled_box) -
    -- also one that was only on its way through a tiled workspace (moved on before it settled
    -- there: it is the size of its tile there, not of where it came from)
    local was_tiled = (rec and (rec.was_tiled or (rec.tiled and not untiled[current])))
        or (rec == nil and not floating)
    local side = target > current and "l" or "r"      -- the side it comes in from
    local center_y = old.y + old.h / 2

    -- settling in (5.) is scheduled first, so the windows are always unpinned and tiled again,
    -- even if a step below fails
    local me = { target = target, tiled = tiled, was_tiled = was_tiled, side = side, center_y = center_y,
                 others = 0, queue = rec and rec.queue or {} }
    carrying[id] = me
    schedule_settle(id, me)

    pcall(function()
        -- 1. pinned floating window, exactly where it is
        if rec == nil then
            set_floating(w, true)
            place(w, old)
            hl.dispatch(hl.dsp.window.pin({ window = w, action = "enable" }))
        elseif rec.anchor then
            -- moved on before it settled: the window that was making room tiles back
            pcall(set_floating, "address:" .. rec.anchor, false)
        end

        -- 2. the view goes to the other workspace (the pinned window comes along)
        hl.dispatch(hl.dsp.focus({ workspace = target }))

        -- 3. its place there: tile it for a moment, read the place, back to where it is on screen
        local new = old
        if tiled and not untiled[target] then
            hl.dispatch(hl.dsp.window.pin({ window = w, action = "disable" }))
            local others = tiled_windows(target, id)
            me.others = #others
            -- two windows there (side by side): it goes under the one at the edge it comes in
            -- from - the right one moving left, the left one moving right - instead of a third
            -- narrow column beside them
            me.split = #others == 2 and "d" or nil
            tile_at_side(w, id, side, center_y, me.split)
            new = box_of(w) or old
            local room = #others == 1 and box_of(others[1].win)   -- where the one window there goes
            set_floating(w, true)
            place(w, old)
            hl.dispatch(hl.dsp.window.pin({ window = w, action = "enable" }))
            if room then
                -- it makes room during the slide: floating for that moment, from its own place
                local a = others[1]
                set_floating(a.win, true)
                place(a.win, a.box)
                place(a.win, room)
                me.anchor = a.id
            end
        elseif was_tiled and untiled[target] then
            -- tiling is off there: it floats, the size of one tile of four, in the middle
            new = untiled_box(hl.get_active_monitor()) or old
        end

        -- 4. glide there during the slide
        place(w, new)
        hl.dispatch(hl.dsp.focus({ window = w }))
    end)

end

-- Minimize: Hyprland has no minimized state, so the window goes to a hidden workspace
-- ("special:minimized"). Click it in the bottom bar or in the island, or pick it with
-- SUPER + Space, and it comes back to the workspace you are on (frameshell_restore below).
-- Remembered for that: whether it is a window that tiles - tiled, or floating only because
-- tiling is off on its workspace - or one that floats on its own (floats_on_own: a dialog), and
-- whether tiling was off on its workspace (for a maximized / fullscreen one) and whether it was
-- maximized there (as a floating window: "Maximize on a workspace without tiling").
-- It only fades out, where it is. On its own Hyprland would slide a tiled window to its tile in
-- the hidden workspace (to the left or right) while it fades, so a tiled window floats there
-- instead, in its own place and size (it gets its tile back when it comes back). A floating or
-- maximized one stays where it is anyway; one covering the screen (F11, tiling off) is put back
-- over the screen for its fade.
local minimized = {}                   -- address -> { tiles = true / false, untiled = true / false, max = true / false }

local function minimize()
    local w = hl.get_active_window()
    if w then
        local box, from_fs                      -- where it fades out
        pcall(function()
            if w.fullscreen == 0 then
                from_fs = w.floating and in_float_fs(w)
                if not w.floating or from_fs then
                    box = box_of(w)
                end
            end
        end)
        if in_float_fs(w) then
            pcall(float_unfullscreen, w)        -- covering the screen (F11, tiling off): it comes back without
        end
        local rec
        pcall(function()
            local ws = w.workspace
            local id = window_id(w)
            local off = ws ~= nil and untiled[ws.id] == true
            rec = { tiles = not floats_on_own[id] and (not w.floating or off), untiled = off,
                    max = off and at_max_box(w) }
            minimized[id] = rec
        end)
        hl.dispatch(hl.dsp.window.move({ window = w, workspace = "special:minimized", follow = false }))
        -- (a dialog covering the screen keeps its own place: it comes back where it is in the hidden workspace)
        if box and not (from_fs and not (rec and rec.tiles)) then
            pcall(function()
                if not (w.workspace and w.workspace.name == "special:minimized") then
                    return                      -- it did not go (a pinned window)
                end
                if not w.floating then
                    set_floating(w, true)
                end
                if w.floating then
                    place(w, box)
                end
            end)
        end
    end
end

hl.on("window.close", function(w)
    pcall(function()
        minimized[window_id(w)] = nil
        floats_on_own[window_id(w)] = nil
        float_max[window_id(w)] = nil
    end)
end)

-- Bringing back a minimized window ----------------------------------------------------
-- The shell calls this when you pick a minimized window (app switcher, bottom bar, island):
--   hyprctl dispatch 'frameshell_restore("0x…")'
-- It comes back the way an app opens: on the workspace you are on, on the right like a new
-- window, fading in and growing from 88 % to its full size from the middle (like "windowsIn":
-- popin 88 %, same curve and time) while the other windows make room. On its own Hyprland
-- would slide it over from where it was hidden (the whole screen), so it seemed to open on
-- the left and then move to the right.
-- Like a new window it fits the workspace it comes back to: a window that tiles is tiled
-- there - also one that floated because tiling was off where it was minimized - or, with
-- tiling off there, floats the size of one tile of four in the middle (untiled_box). A window
-- that floats on its own keeps its size. A maximized / fullscreen one stays so on a workspace
-- like the one it was minimized on (tiling on, or off); on the other kind it fits in the same
-- way (out of maximize / fullscreen first).
-- How: the window is made invisible with its animations off, put in its place and shrunk to
-- 88 % (it jumps there unseen); a moment later its animations are back on and it grows and
-- fades in.
local POPIN = 0.88
local restore_count = 0

function frameshell_restore(address)
    return function()
        local sel = "address:" .. address
        local w = hl.get_window(sel)
        local ws = hl.get_active_workspace()
        if not w or not ws then
            return
        end
        local ok, current = pcall(function() return w.workspace and w.workspace.id end)
        if ok and current == ws.id then
            hl.dispatch(hl.dsp.focus({ window = sel }))   -- it is here already
            return
        end
        restore_count = restore_count + 1
        local n = restore_count
        local box, tiled

        -- 2. (scheduled first, so the window never stays invisible) grow and fade in
        hl.timer(function()
            pcall(hl.dispatch, hl.dsp.window.set_prop({ window = sel, prop = "no_anim", value = "unset" }))
            pcall(hl.dispatch, hl.dsp.window.set_prop({ window = sel, prop = "opacity", value = "1" }))
            pcall(function()
                if box then
                    -- the curve new windows open with, for this one movement
                    hl.animation({ leaf = "windowsMove", enabled = true, speed = SLIDE_SPEED, bezier = "emphasizedDecel" })
                    if tiled then
                        blur_live_while_moving()   -- the others make room, as for a new window
                        set_floating(sel, false)
                    else
                        place(sel, box)
                    end
                    hl.timer(function()
                        if restore_count == n then
                            hl.animation({ leaf = "windowsMove", enabled = true, speed = SLIDE_SPEED, bezier = MOVE_CURVE })
                        end
                    end, { timeout = SLIDE_SPEED * 100 + 40, type = "oneshot" })
                end
                hl.dispatch(hl.dsp.focus({ window = sel }))
            end)
        end, { timeout = 30, type = "oneshot" })

        -- 1. unseen: onto this workspace, read its place, shrink to 88 % in the middle of it
        pcall(function()
            -- does it tile? (not remembered - minimized before Hyprland reloaded this file: yes,
            -- unless it is known to float on its own)
            local key = window_id(w)
            local rec = minimized[key]
            minimized[key] = nil
            local tiles = not floats_on_own[key]
            if rec then
                tiles = rec.tiles
            end
            hl.dispatch(hl.dsp.window.set_prop({ window = sel, prop = "no_anim", value = "1" }))
            hl.dispatch(hl.dsp.window.set_prop({ window = sel, prop = "opacity", value = "0" }))
            hl.dispatch(hl.dsp.window.move({ window = sel, workspace = ws.id, follow = false }))
            local here = hl.get_window(sel)
            if here and here.fullscreen ~= 0 and rec and rec.untiled ~= (untiled[ws.id] == true) then
                set_fullscreen_state(sel, 0, 0)    -- the other kind of workspace: out of maximize / fullscreen
                here = hl.get_window(sel)
            end
            local b
            if here and here.fullscreen == 0 then
                tiled = tiles and not untiled[ws.id]
                if tiled then
                    set_floating(sel, false)       -- its tile here (one that floated is tiled now)
                    b = box_of(hl.get_window(sel) or here)
                elseif tiles then
                    -- tiling off here: like a new window - or maximized again, if it was maximized
                    -- on a workspace without tiling
                    local m = hl.get_active_monitor()
                    b = (rec and rec.max and rec.untiled and max_box(m)) or untiled_box(m)
                end
                b = b or box_of(here)
            end
            if b then
                set_floating(sel, true)
                place(sel, {
                    x = b.x + b.w * (1 - POPIN) / 2, y = b.y + b.h * (1 - POPIN) / 2,
                    w = b.w * POPIN, h = b.h * POPIN,
                })
                box = b
            end
        end)
    end
end

-- The shell calls this to bring a window to the front (the dock, the island, the app switcher):
--   hyprctl dispatch 'frameshell_activate("0x…")'
-- A minimized one comes back (frameshell_restore), any other is focused. Hyprland itself decides
-- which, not the shell: the shell's picture of where a window is can be a moment late, and
-- focusing a window that is still in the hidden workspace would show that workspace.
function frameshell_activate(address)
    return function()
        local sel = "address:" .. address
        local w = hl.get_window(sel)
        if not w then
            return
        end
        local ok, name = pcall(function() return w.workspace and w.workspace.name end)
        if ok and name == "special:minimized" then
            frameshell_restore(address)()
        else
            hl.dispatch(hl.dsp.focus({ window = sel }))
        end
    end
end

-- The hidden workspace of the minimized windows is never shown. Hyprland shows a special
-- workspace over the one you are on when a window in it is focused, and new windows would then
-- open in it - a layer of tiles over your windows. Should that ever happen, it is closed again.
hl.on("workspace.special_active", function(ws, mon)
    local ok, name = pcall(function() return ws and ws.name end)
    if ok and name == "special:minimized" and mon then
        hl.timer(function()
            pcall(function()
                local shown = mon.active_special_workspace
                if shown and shown.name == "special:minimized" then
                    mon:set_special_workspace()
                end
            end)
        end, { timeout = 1, type = "oneshot" })
    end
end)

move_or_workspace = function(direction, step)
    local w = hl.get_active_window()
    if not w then
        return
    end
    local id = window_id(w)
    local rec = carrying[id or ""]
    if rec then
        -- still on its way (pressed again quickly): do the step right away where possible
        if rec.tiled and not untiled[rec.target] and rec.others <= 1 then
            if rec.others == 1 and (direction == "right") == (rec.side == "l") then
                swap_sides(w, id, rec)          -- the other window is that way: to its other side
            else
                local target = workspace_beside(step)   -- nothing that way: on to the next workspace
                if target then
                    move_to_workspace(w, target)
                end
            end
        else
            table.insert(rec.queue, { direction, step })   -- right after it settles
        end
        return
    end
    local carry
    if w.fullscreen ~= 0 then
        carry = true                                 -- fullscreen / maximized: nothing beside it
    elseif w.floating then
        carry = true                                 -- floating: straight to the workspace beside
    else
        carry = not move_within(w, direction)        -- nothing beside it that way: on to the next workspace
    end
    local target = carry and workspace_beside(step)
    if target then
        move_to_workspace(w, target)
    end
end


-- ── Hyprland's default keybinds ─────────────────────────────────────────────
-- The same keys as Hyprland's own example config (example/hyprland.lua), wired to the
-- shell's apps and features where it has its own (launcher, log out confirmation).

bind(mod .. " + Q", hl.dsp.exec_cmd(terminal),              { description = "Open a terminal" })
bind(mod .. " + C", hl.dsp.window.close(),                   { description = "Close window" })
bind(mod .. " + M", hl.dsp.exec_cmd(logout),                 { description = "Log out" })
bind(mod .. " + E", hl.dsp.exec_cmd(homeFolder),             { description = "Open the file manager" })
bind(mod .. " + V", hl.dsp.window.float({ action = "toggle" }), { description = "Toggle floating window" })
bind(mod .. " + R", launcher_toggle,                         { description = "Open the launcher" })
bind(mod .. " + P", hl.dsp.window.pseudo(),                  { description = "Pseudotile window" })
bind(mod .. " + J", hl.dsp.layout("togglesplit"),            { description = "Toggle window split" })   -- dwindle only

-- Move focus with SUPER + arrow keys. Left / Right go on to the workspace beside it when there
-- is no window that way (the edge of the screen, or an empty workspace).
bind(mod .. " + left",  function() focus_or_workspace("left", -1) end, { description = "Focus window left, at the edge: workspace to the left" })
bind(mod .. " + right", function() focus_or_workspace("right", 1) end, { description = "Focus window right, at the edge: workspace to the right" })
bind(mod .. " + up",    hl.dsp.focus({ direction = "up" }),            { description = "Focus window up" })
bind(mod .. " + down",  hl.dsp.focus({ direction = "down" }),          { description = "Focus window down" })

-- SUPER + 1…5 switches workspace, SUPER + SHIFT + 1…5 moves the window there (and follows it).
-- Only up to the last workspace (WORKSPACE_MAX = workspaceMax in Config.qml, 5); with 10,
-- workspace 10 is on the 0 key.
for i = 1, WORKSPACE_MAX do
    local key = i % 10
    bind(mod .. " + " .. key,           hl.dsp.focus({ workspace = i }), { description = "Switch to workspace " .. i })
    bind(mod .. " + SHIFT + " .. key,   function() move_to_workspace(hl.get_active_window(), i) end, { description = "Move window to workspace " .. i })
end

-- The special workspace (scratchpad)
bind(mod .. " + S",         hl.dsp.workspace.toggle_special("magic"),             { description = "Show / hide the scratchpad" })
bind(mod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }),  { description = "Move window to the scratchpad" })

-- Scroll through existing workspaces with SUPER + mouse wheel
bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }), { description = "Next workspace (scroll)" })
bind(mod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }), { description = "Prev workspace (scroll)" })


-- ── Frameshell's extras (on keys Hyprland's defaults leave free) ─────────────
bind(mod .. " + space",     switcher_next,                  { description = "Switch between open windows" })
bind(mod .. " + Escape",    hl.dsp.exec_cmd(lockscreen),    { description = "Lock the screen" })
bind(mod .. " + B",         hl.dsp.exec_cmd(browser),       { description = "Open a web browser" })
bind(mod .. " + N",         hl.dsp.exec_cmd(textEditor),    { description = "Open the text editor" })
bind(mod .. " + F",         maximize_key,                   { description = "Maximize window" })
bind("F11",                 fullscreen_key,                 { description = "Fullscreen window" })
bind(mod .. " + H",         minimize,                       { description = "Minimize window" })
bind(mod .. " + Z", function()
    blur_live_while_moving()
    hl.dispatch(hl.dsp.window.swap({ next = true }))
end, { description = "Swap window" })

-- letting go of SUPER finishes SUPER + Space. `transparent` is required: without it the
-- SUPER + Space bind "shadows" the release bind.
bind_keys({ "SUPER + SUPER_L", "SUPER + SUPER_R" }, switcher_release,
    { release = true, transparent = true, non_consuming = true, ignore_mods = true })

-- Move windows: SUPER + SHIFT + arrow keys. Left / Right carry the window on to the workspace
-- beside it when it is already at the edge. Up / Down: not on a workspace without tiling - its
-- windows float there.
local function move_vertical(direction)
    local move = move_key(direction)
    return function()
        local ws = hl.get_active_workspace()
        if ws and untiled[ws.id] then
            return
        end
        move()
    end
end
bind(mod .. " + SHIFT + left",  function() move_or_workspace("left", -1) end, { description = "Move window left, at the edge: to the workspace to the left" })
bind(mod .. " + SHIFT + right", function() move_or_workspace("right", 1) end, { description = "Move window right, at the edge: to the workspace to the right" })
bind(mod .. " + SHIFT + up",    move_vertical("up"),   { description = "Move window up" })
bind(mod .. " + SHIFT + down",  move_vertical("down"), { description = "Move window down" })

-- Screens (more than one monitor)
bind(mod .. " + ALT + left",  hl.dsp.focus({ monitor = "l" }), { description = "Switch to output left" })
bind(mod .. " + ALT + right", hl.dsp.focus({ monitor = "r" }), { description = "Switch to output right" })
bind(mod .. " + ALT + up",    hl.dsp.focus({ monitor = "u" }), { description = "Switch to output up" })
bind(mod .. " + ALT + down",  hl.dsp.focus({ monitor = "d" }), { description = "Switch to output down" })

-- Window tiling on / off for the whole workspace (Next = Page Down)
bind(mod .. " + Next", toggle_workspace_tiling, { description = "Toggle window tiling" })

bind(mod .. " + comma",     hl.dsp.exec_cmd(qs .. " ipc call ui calendar"),   { description = "Calendar" })
-- the emoji picker: type to search, Enter or a click puts the emoji into the text field you were
-- in (and copies it)
bind(mod .. " + period",    emoji_toggle,                                     { description = "Emoji picker" })
-- the on-screen keyboard: a click on a key types into the focused window; it floats over the
-- windows near the bottom of the screen and does not take the keyboard, so you can click the
-- windows behind it
bind(mod .. " + backslash", keyboard_toggle,                                  { description = "On-screen keyboard" })
-- the wallpaper switcher in the island: previous / next wallpaper
bind(mod .. " + CTRL + left",  hl.dsp.exec_cmd(qs .. " ipc call wallpaper prev"), { description = "Previous wallpaper" })
bind(mod .. " + CTRL + right", hl.dsp.exec_cmd(qs .. " ipc call wallpaper next"), { description = "Next wallpaper" })
-- the theme switcher (the same place): Up = the next colour theme (to the right), Down = the previous one
bind(mod .. " + CTRL + up",    hl.dsp.exec_cmd(qs .. " ipc call theme next"),     { description = "Next colour theme" })
bind(mod .. " + CTRL + down",  hl.dsp.exec_cmd(qs .. " ipc call theme prev"),     { description = "Previous colour theme" })
-- (released Hyprland has no reload dispatcher yet, hl.dsp.reload_config only exists in git builds)
bind(mod .. " + SHIFT + R", hl.dsp.exec_cmd("hyprctl reload"),                { description = "Reload Hyprland config" })

-- mouse: SUPER + left / right drag moves / resizes a window
-- (off while the launcher or the app switcher is open: a click with SUPER held then closes it,
-- see update_mouse_binds)
mouse_binds[#mouse_binds + 1] = bind(mod .. " + mouse:272",  hl.dsp.window.drag(),   { mouse = true, description = "Move window (drag)" })
mouse_binds[#mouse_binds + 1] = bind(mod .. " + mouse:273",  hl.dsp.window.resize(), { mouse = true, description = "Resize window (drag)" })

-- Screenshots (the shell's screenshot screen, modules/Screenshot.qml). Delete these two if
-- you want Print to do nothing.
--   Print        the screen freezes: drag over an area (move it, drag its edges, right drag
--                resizes it), middle-click for the pencil / line / arrow / rectangle / text;
--                Enter saves it to
--                ~/Pictures/Screenshots and copies it, Esc cancels
--   Shift+Print  the screen the pointer is on, saved and copied the same way
-- Then a "Screenshot saved" notification: click it to see the file in Nautilus.
bind("Print",         screenshot,      { description = "Screenshot: area" })
bind("SHIFT + Print", screenshot_full, { description = "Screenshot: screen → file + clipboard" })

-- While the screenshot screen is open (its window, "frame-screenshot") no shortcut works - not
-- even SUPER + drag: Hyprland switches to a set of shortcuts of its own ("submap") with only
-- an emergency way out, SUPER + CTRL + ALT + Escape. It goes back the moment that window closes
-- - also if the shell should crash. (One window per screen: back when the last one closes.)
hl.define_submap("frame-screenshot", function()
    hl.bind("SUPER + CTRL + ALT + Escape", hl.dsp.submap("reset"), { description = "Leave the screenshot screen's shortcuts" })
end)
local shot_layers = 0

local function is_shot_layer(ls)
    local ok, ns = pcall(function() return ls.namespace end)
    return ok and ns == "frame-screenshot"
end

hl.on("layer.opened", function(ls)
    if is_shot_layer(ls) then
        shot_layers = shot_layers + 1
        if shot_layers == 1 then
            pcall(hl.dispatch, hl.dsp.submap("frame-screenshot"))
        end
    end
end)
hl.on("layer.closed", function(ls)
    if is_shot_layer(ls) then
        shot_layers = math.max(0, shot_layers - 1)
        if shot_layers == 0 then
            pcall(hl.dispatch, hl.dsp.submap("reset"))
        end
    end
end)

-- Volume / media keys of the keyboard (they also work on the lock screen: `locked`).
-- Delete this block if your keyboard handles them some other way.
-- (Every shortcut's `description` is what the Settings app's Keybinds page shows for it.)
bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true, description = "Volume up" })
bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true, description = "Volume down" })
bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, description = "Mute the sound" })
bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, description = "Mute the microphone" })
bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true, description = "Next track" })
bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "Play / pause" })
bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "Play / pause" })
bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true, description = "Previous track" })
-- Laptop screen brightness keys (Hyprland's defaults; a desktop monitor is set with the slider
-- in the top-left corner of the frame, over DDC/CI)
bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), { locked = true, repeating = true, description = "Brightness up" })
bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), { locked = true, repeating = true, description = "Brightness down" })


--------------------------------
---- WINDOW AND LAYER RULES ----
--------------------------------

-- The shell's own panels animate themselves, so Hyprland must not animate them as well.
hl.layer_rule({
    name    = "frame-no-anim",
    match   = { namespace = "^frame-" },
    no_anim = true,
})

-- Blur (the Settings app's Blur page, BLUR_* above). The shell changes both rules by their
-- names while it runs (modules/HyprSync.qml).
-- "Apply blur to windows" off: no window is blurred (the shell's blur still is)
hl.window_rule({
    name    = "frame-window-blur",
    enabled = not WINDOW_BLUR,
    match   = { class = ".*" },
    no_blur = true,
})
-- "Apply blur to shell" on: the frame, the island, the panels and the pop-ups - only where
-- they are about as solid as their see-through surfaces, so not their soft shadows or the
-- empty middle of the screen
hl.layer_rule({
    name         = "frame-shell-blur",
    enabled      = SHELL_BLUR,
    match        = { namespace = "^frame-(overlay|switcher|launcher|auth|network|confirm|emoji|osk)$" },
    blur         = true,
    ignore_alpha = math.max(0, math.max(0.3, math.min(1, SHELL_OPACITY)) - 0.05),
})

-- A maximized or fullscreen window blurs what is really under it: the other windows, kept
-- there for see-through windows ("the other windows under a maximized or fullscreen one"
-- above). Behind a tiled window Hyprland blurs only a stored copy of the wallpaper
-- (decoration:blur:new_optimizations), as normally nothing else is under one; floating
-- windows already blur what is under them.
hl.window_rule({
    name  = "frame-blur-under-fullscreen",
    match = { fullscreen = true },
    xray  = false,
})
-- ... and while tiled windows slide over each other or make room for a new one ("frame-moving",
-- blur_live_while_moving above)
hl.window_rule({
    name  = "frame-blur-moving",
    match = { tag = "frame-moving" },
    xray  = false,
})

-- The password dialog, the shut down / log out question, the Wi-Fi / Bluetooth card, the app
-- switcher, the launcher and the emoji picker fade and zoom in by themselves; should Hyprland
-- animate them anyway, it may only fade - never slide them in from an edge.
hl.layer_rule({
    name      = "frame-popups-fade",
    match     = { namespace = "^frame-(auth|confirm|network|switcher|launcher|screenshot|emoji)$" },
    no_anim   = true,
    animation = "fade",
})
-- The on-screen keyboard (SUPER + \) is the exception: Hyprland fades it in and out (only a
-- fade, "fadeLayersIn" / "fadeLayersOut" above), so the whole of it - card, keys, shadow and the
-- blur behind it - fades as one. (Faded by the shell, the keys and the see-through card drawn
-- under them fade unevenly, and the blur behind it switches off part of the way.) After the
-- rules above: this one wins.
hl.layer_rule({
    name      = "frame-osk-fade",
    match     = { namespace = "^frame-osk$" },
    no_anim   = false,
    animation = "fade",
})

-- the colour picker (click the block in the top-right corner) freezes the screen at once
hl.layer_rule({
    name    = "hyprpicker-no-anim",
    match   = { namespace = "^hyprpicker$" },
    no_anim = true,
})

-- rofi (the backup launcher) pops up instantly
hl.layer_rule({
    name    = "rofi-no-anim",
    match   = { namespace = "^rofi$" },
    no_anim = true,
})

-- apps may not maximize themselves
hl.window_rule({
    name  = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({
    name  = "fix-xwayland-drags",
    match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
    no_focus  = true,
    no_shadow = true,                     -- invisible helper windows: no shadow floating in the air
})

-- no screen lock / screen off while something is fullscreen (video, games). Only windows that
-- are told they are fullscreen (client state 2, or 3 = maximized + fullscreen): a maximized
-- window (SUPER + F) does not keep the screen on.
for _, client in ipairs({ 2, 3 }) do
    hl.window_rule({
        name  = "idle-inhibit-fullscreen-" .. client,
        match = { fullscreen_state_client = client },
        idle_inhibit = "fullscreen",
    })
end

-- small helper windows float in the middle instead of being tiled
hl.window_rule({
    name  = "float-helpers",
    match = { class = [[^(org\.pulseaudio\.pavucontrol|pavucontrol|nm-connection-editor|blueman-manager|org\.gnome\.Calculator|qt5ct|qt6ct|kvantummanager|nwg-look|xdg-desktop-portal-gtk|.*[Pp]olkit.*)$]] },
    float  = true,
    center = true,
})

-- file dialogs float in the middle, too
hl.window_rule({
    name  = "float-file-dialogs",
    match = { title = [[^(Open File|Open Folder|Save File|Save As|Select.*|Choose.*|File Upload|File Operation Progress|Confirm to replace files|Rename.*)$]] },
    float  = true,
    center = true,
    size   = "900 600",
})

-- Firefox picture-in-picture stays small and on top
hl.window_rule({
    name  = "firefox-pip",
    match = { title = "^(Picture-in-Picture)$" },
    float = true,
    pin   = true,
    size  = "480 270",
})
