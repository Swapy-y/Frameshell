#!/usr/bin/env python3
# ═══════════════════════════════════════════════════════════════════════════
#  palettes.py - the app themes' colours of the shell's colour themes, made
#  from the themes themselves (config/quickshell/frame/Config.qml, `themes`).
#
#  Default (Frame) and Noir have hand-made palettes (make-themes.py,
#  Kvantum/make-frame.py). Every other theme in Config.qml gets its GTK, Qt,
#  Kvantum, Firefox and kitty colours from here: the shell's colours of the
#  theme, plus three it has no use for itself (EXTRA below: green, links,
#  visited links). The rules are the ones the Frame palettes follow - applied
#  to Default's colours they give Frame's (check() below).
#
#  Used by make-themes.py (GTK, Qt, Firefox, kitty) and Kvantum/make-frame.py.
#  A new theme in Config.qml: add its EXTRA colours here and run both again.
# ═══════════════════════════════════════════════════════════════════════════
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
CONFIG = os.path.join(ROOT, 'config', 'quickshell', 'frame', 'Config.qml')

# themes with hand-made palettes (not made here)
HANDMADE = ('Default', 'Noir')

# the colours a theme's own palette has besides the shell's: success (green), links,
# visited links - from each theme's published palette
EXTRA = {
    'Catppuccin Mocha': dict(GREEN='#a6e3a1', LINK='#89b4fa', VISITED='#b4befe'),   # Green, Blue, Lavender
    'Everblush': dict(GREEN='#8ccf7e', LINK='#67b0e8', VISITED='#c47fd5'),
    'Everforest': dict(GREEN='#a7c080', LINK='#7fbbb3', VISITED='#d699b6'),
    'Rose Pine': dict(GREEN='#9ccfd8', LINK='#c4a7e7', VISITED='#ebbcba'),          # Foam, Iris, Rose
    'Gruvbox': dict(GREEN='#a9b665', LINK='#7daea3', VISITED='#d3869b'),            # Gruvbox Material
    'Kanagawa': dict(GREEN='#98bb6c', LINK='#7e9cd8', VISITED='#957fb8'),           # springGreen, crystalBlue, oniViolet
    'Nord': dict(GREEN='#a3be8c', LINK='#88c0d0', VISITED='#b48ead'),               # nord14, nord8, nord15
    'Tokyo Night': dict(GREEN='#9ece6a', LINK='#7aa2f7', VISITED='#bb9af7'),
    # only for check(): Frame's own
    'Default': dict(GREEN='#8fd694', LINK='#6aa3d9', VISITED='#b48ead'),
}


def slug(name):
    """The name in file and folder names: Frame-<slug>, Frame<slug>, frame-<slug lower>.conf"""
    return re.sub(r'\s+', '', name)


def themes():
    """The themes of Config.qml, in its order: [{'name': ..., key: '#rrggbb', ...}]"""
    text = open(CONFIG).read()
    start = re.search(r'property\s+var\s+themes\s*:\s*\[', text).end() - 1
    body = re.sub(r'//[^\n]*', '', text[start:])
    depth = 0
    for i, c in enumerate(body):
        depth += (c == '[') - (c == ']')
        if depth == 0:
            body = body[:i + 1]
            break
    out = []
    for entry in re.findall(r'\{(.*?)\}', body, re.S):
        out.append({m.group(1): m.group(2) for m in re.finditer(r'(\w+)\s*:\s*"([^"]*)"', entry)})
    return out


def theme(name):
    all_ = themes()
    found = next((t for t in all_ if t['name'] == name), None)
    if found is None:
        raise SystemExit('Config.qml has no theme "%s"' % name)
    return dict(all_[0], **found)       # a colour a theme leaves out is Default's


def generated():
    """The names of the themes made here"""
    return [t['name'] for t in themes() if t['name'] not in HANDMADE]


# ── colour arithmetic ─────────────────────────────────────────────────────────
def rgb(c):
    c = c.lstrip('#')
    if len(c) == 8:                     # #aarrggbb (Qt): the colour part
        c = c[2:]
    return tuple(int(c[i:i + 2], 16) for i in (0, 2, 4))


def hexc(t):
    return '#%02x%02x%02x' % tuple(max(0, min(255, round(v))) for v in t)


def mix(a, b, t):
    """a, moved the fraction t of the way to b"""
    x, y = rgb(a), rgb(b)
    return hexc(tuple(x[i] + (y[i] - x[i]) * t for i in range(3)))


# ── the palettes ──────────────────────────────────────────────────────────────
def base(name):
    t = theme(name)
    e = EXTRA.get(name)
    if e is None:
        raise SystemExit('palettes.py: no EXTRA colours for the theme "%s"' % name)
    bg, card = t['background'], t['cardBackground']
    return dict(
        BG=bg, CARD=card, CTRL=t['controlBackground'], HOVER=t['controlHover'],
        STEP=t['controlDisabled'], BORDER=t['border'], TEXT=t['text'], TEXT2=t['textSecondary'],
        TEXT3=t['textTertiary'], SEL=t['selectionBackground'], ACCENT=t['sliderFill'],
        RED=t['warning'], YELLOW=t['batteryCharging'], ACTIVE=t['windowBorderActive'],
        SIDEBAR=mix(bg, card, 0.625), SIDEBAR2=mix(bg, card, 0.25),
        DARK=mix(bg, '#000000', 0.42), **e)


def gtk(name):
    b = base(name)
    r, g, bl = rgb(b['TEXT'])
    return dict(
        BG=b['BG'], FG=b['TEXT'], ON=b['BG'], ACCENT=b['ACCENT'],
        RED=b['RED'], GREEN=b['GREEN'], YELLOW=b['YELLOW'],
        OUTLINE=b['BORDER'], SIDEBAR=b['SIDEBAR'], SIDEBAR2=b['SIDEBAR2'],
        CARD=b['CARD'], POPOVER=b['BG'], SELECTED=b['STEP'], TEXT_SELECTION=b['SEL'],
        LINK=b['LINK'], VISITED=b['VISITED'],
        INFOBAR=b['CTRL'], INFOBAR_HOVER=b['HOVER'],
        MENU_BORDER=b['BORDER'], TOOLTIP=b['BG'],
        OVERVIEW=b['SIDEBAR'], TOGGLE='rgba(%d, %d, %d, 0.2)' % (r, g, bl),
    )


def qt(name):
    b = base(name)
    return dict(
        FG=b['TEXT'], FILL=b['HOVER'], LIGHT=b['STEP'], MIDLIGHT=mix(b['HOVER'], b['STEP'], 0.22),
        DARK=b['DARK'], MID=b['SIDEBAR'], BG=b['BG'], SHADOW='#000000', HIGHLIGHT=b['SEL'],
        HIGHLIGHT_INACTIVE=b['SEL'], HIGHLIGHT_DISABLED=b['STEP'], LINK=b['LINK'],
        VISITED=b['VISITED'], ALT_BASE=b['SIDEBAR'], TOOLTIP=b['CTRL'], DIM=b['TEXT2'],
        DISABLED=mix(b['TEXT3'], b['TEXT2'], 0.35), FAINT=b['TEXT3'], ACCENT=b['ACCENT'],
    )


def kvantum(name):
    b = base(name)
    over = lambda p: mix(b['BG'], b['TEXT'], p)        # the text colour at p over the window
    q = qt(name)
    return dict(
        WIN=b['BG'], FILL=b['HOVER'], HOVER=over(0.15), PRESS=over(0.30), TOGGLE=over(0.30),
        SEL=b['STEP'], SEL_INACTIVE=b['CTRL'], ROW_HOVER=b['CARD'], OUTLINE=b['BORDER'],
        ACCENT=b['ACCENT'], ACCENT_HOVER=mix(b['ACCENT'], b['BG'], 0.09), ON_ACCENT=b['BG'],
        DIM=b['TEXT2'], TEXT=b['TEXT'], DISABLED=q['DISABLED'], RED=b['RED'],
        CHECK=over(0.15), CHECK_FOCUS=over(0.23),
        SCROLL=over(0.26), SCROLL_HOVER=over(0.40), SCROLL_PRESS=over(0.60),
        ALT_BASE=b['SIDEBAR'], MID_LIGHT=q['MIDLIGHT'], DARK=b['DARK'], MID=b['SIDEBAR'],
        HIGHLIGHT=b['SEL'], HIGHLIGHT_INACTIVE=b['SEL'],
        LINK=b['LINK'], VISITED=b['VISITED'],
    )


def firefox(name):
    """Default's userChrome.css / userContent.css colour -> this theme's"""
    b = base(name)
    return {
        '#121212': mix(b['BG'], '#000000', 0.30),      # the title bar, the address bar's list
        '#161616': mix(b['BG'], '#000000', 0.15),
        '#1a1a1a': b['BG'],                            # toolbars, the new tab page
        '#222222': b['CARD'],
        '#393939': b['STEP'],                          # the row picked in the address bar's list
        '#ffffff': b['TEXT'],
        '#e6e6e6': mix(b['TEXT'], b['BG'], 0.11),      # toolbar text and icons
        '#e5e5e5': mix(b['TEXT'], b['BG'], 0.11),
        '#9b9b9b': b['TEXT2'],
        '#5a5a5a': b['TEXT3'],
    }


def kitty(name):
    """kitty.conf keys -> this theme's colours (the rest is Default's frame.conf)"""
    b = base(name)
    return {
        'foreground': b['TEXT'], 'background': b['BG'], 'selection_background': b['SEL'],
        'cursor': b['TEXT'], 'cursor_text_color': b['BG'], 'url_color': b['LINK'],
        'active_border_color': b['ACTIVE'], 'inactive_border_color': b['BORDER'],
        'active_tab_foreground': b['TEXT'], 'active_tab_background': b['CTRL'],
        'inactive_tab_foreground': b['TEXT2'], 'inactive_tab_background': b['BG'],
        'tab_bar_background': b['BG'],
        # the real colours of the 16 (the white ones are the shell's prompt: they stay)
        'color2': b['GREEN'], 'color10': b['GREEN'], 'color3': b['YELLOW'], 'color11': b['YELLOW'],
        'color12': b['LINK'], 'color13': b['VISITED'],
    }


def describe(name):
    b = base(name)
    return ('%s windows, %s cards, %s buttons, %s selections, %s text,\n'
            '   %s main buttons with %s text, %s for errors, %s for warnings'
            % (b['BG'], b['CARD'], b['CTRL'], b['STEP'], b['TEXT'], b['ACCENT'], b['BG'], b['RED'], b['YELLOW']))


def check():
    """the rules, applied to Default's colours, must give the hand-made Frame palettes
    (to within 2 of 255 a channel: they were made with white at a few % by eye)"""
    import importlib.util
    spec = importlib.util.spec_from_file_location('mt', os.path.join(HERE, 'make-themes.py'))
    mt = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mt)
    bad = []
    for made, hand in ((gtk('Default'), mt.GTK['Frame']), (qt('Default'), mt.QT['Frame'])):
        for k, v in made.items():
            if not v.startswith('#'):
                continue
            if max(abs(x - y) for x, y in zip(rgb(v), rgb(hand[k]))) > 2:
                bad.append('%s %s != %s' % (k, v, hand[k]))
    return bad


if __name__ == '__main__':
    print('\n'.join(check()) or 'the rules give the Frame palettes')
    for n in generated():
        print(n, slug(n))
