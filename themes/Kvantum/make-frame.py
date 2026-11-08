#!/usr/bin/env python3
# ═══════════════════════════════════════════════════════════════════════════
#  make-frame.py - builds the Frame Kvantum themes (themes/Kvantum/Frame,
#  FrameNoir, FrameMocha) from KvLibadwaita's dark theme: the same shapes, in
#  the colours of the shell's themes (Config.qml: Default, Noir, Mocha).
#
#    git clone https://github.com/GabePoel/KvLibadwaita
#    python3 make-frame.py KvLibadwaita/src/KvLibadwaita Frame
#    python3 make-frame.py KvLibadwaita/src/KvLibadwaita FrameNoir
#    python3 make-frame.py KvLibadwaita/src/KvLibadwaita FrameMocha
#
#  The output folder's name picks the palette below (and names the theme).
#  Only needed to change a theme's colours: edit its palette, run it, copy the
#  folder to ~/.config/Kvantum/. The Qt palettes (config/qt5ct, config/qt6ct
#  colors/*.conf, made by ../make-themes.py) use the same colours.
# ═══════════════════════════════════════════════════════════════════════════
import sys, re, os
import xml.etree.ElementTree as ET
if len(sys.argv) != 3:
    sys.exit('usage: make-frame.py <KvLibadwaita/src/KvLibadwaita> <output folder>')
src, out = sys.argv[1], sys.argv[2]
SVG = 'http://www.w3.org/2000/svg'
for p, u in (('', SVG), ('inkscape', 'http://www.inkscape.org/namespaces/inkscape'),
             ('sodipodi', 'http://sodipodi.sourceforge.net/DTD/sodipodi-0.dtd'), ('xlink', 'http://www.w3.org/1999/xlink'),
             ('rdf', 'http://www.w3.org/1999/02/22-rdf-syntax-ns#'), ('cc', 'http://creativecommons.org/ns#'),
             ('dc', 'http://purl.org/dc/elements/1.1/')):
    ET.register_namespace(p, u)

# ── the palettes (the GTK themes themes/Frame*/gtk-3.0/colors.css use the same) ──
PALETTES = {
    # Default: the shell's greys
    'Frame': dict(
        WIN='#1a1a1a',        # windows, menus, views
        FILL='#313131',       # buttons, entries (white 10 % over the window, as adw-gtk3)
        HOVER='#3c3c3c',      # 15 %
        PRESS='#5f5f5f',      # 30 %
        TOGGLE='#5f5f5f',     # 30 %, like a pressed button
        SEL='#3a3a3a',        # selected rows
        SEL_INACTIVE='#2a2a2a',
        ROW_HOVER='#222222',
        OUTLINE='#313131',
        ACCENT='#ffffff',     # white, with dark marks on it
        ACCENT_HOVER='#e8e8e8',
        ON_ACCENT='#1a1a1a',
        DIM='#8c8c8c',
        TEXT='#ffffff',
        DISABLED='#6a6a6a',
        RED='#ff6b6b',
        CHECK='#3c3c3c',      # an empty checkbox / radio button
        CHECK_FOCUS='#4e4e4e',
        SCROLL='#555555', SCROLL_HOVER='#767676', SCROLL_PRESS='#a3a3a3',
        ALT_BASE='#1f1f1f', MID_LIGHT='#333333', DARK='#0f0f0f', MID='#1f1f1f',
        HIGHLIGHT='#3e3e3e', HIGHLIGHT_INACTIVE='#3e3e3e',   # selected text (textSelection in Config.qml)
        LINK='#6aa3d9', VISITED='#b48ead',
    ),
    # Noir: black #000000 and #060606, a little lighter only where it must show
    'FrameNoir': dict(
        WIN='#000000', FILL='#060606', HOVER='#0d0d0d', PRESS='#1a1a1a', TOGGLE='#1a1a1a',
        SEL='#060606', SEL_INACTIVE='#060606', ROW_HOVER='#060606', OUTLINE='#060606',
        ACCENT='#ffffff', ACCENT_HOVER='#e8e8e8', ON_ACCENT='#000000',
        DIM='#8c8c8c', TEXT='#ffffff', DISABLED='#575757', RED='#ff6b6b',
        CHECK='#1a1a1a', CHECK_FOCUS='#262626',
        SCROLL='#2a2a2a', SCROLL_HOVER='#3a3a3a', SCROLL_PRESS='#5a5a5a',
        ALT_BASE='#060606', MID_LIGHT='#0d0d0d', DARK='#000000', MID='#060606',
        HIGHLIGHT='#222222', HIGHLIGHT_INACTIVE='#222222',
        LINK='#6aa3d9', VISITED='#b48ead',
    ),
    # Mocha: Catppuccin Mocha (catppuccin.com/palette), the accent Mauve
    'FrameMocha': dict(
        WIN='#181825',        # Mantle
        FILL='#313244',       # Surface0
        HOVER='#45475a',      # Surface1
        PRESS='#585b70',      # Surface2
        TOGGLE='#585b70',     # Surface2
        SEL='#45475a',        # Surface1
        SEL_INACTIVE='#313244',
        ROW_HOVER='#1e1e2e',  # Base
        OUTLINE='#313244',    # Surface0
        ACCENT='#cba6f7',     # Mauve
        ACCENT_HOVER='#b998e2',
        ON_ACCENT='#11111b',  # Crust
        DIM='#9399b2',        # Overlay2
        TEXT='#cdd6f4',       # Text
        DISABLED='#6c7086',   # Overlay0
        RED='#f38ba8',        # Red
        CHECK='#45475a', CHECK_FOCUS='#585b70',
        SCROLL='#585b70', SCROLL_HOVER='#6c7086', SCROLL_PRESS='#7f849c',
        ALT_BASE='#1e1e2e', MID_LIGHT='#313244', DARK='#11111b', MID='#1e1e2e',
        HIGHLIGHT='#474859', HIGHLIGHT_INACTIVE='#474859',
        LINK='#89b4fa', VISITED='#b4befe',   # Blue, Lavender
    ),
}
NAME = os.path.basename(os.path.normpath(out))
if NAME not in PALETTES:
    sys.exit('the output folder must be named one of: ' + ', '.join(PALETTES))
P = PALETTES[NAME]
WIN, FILL, HOVER, PRESS, TOGGLE = P['WIN'], P['FILL'], P['HOVER'], P['PRESS'], P['TOGGLE']
SEL, SEL_INACTIVE, ROW_HOVER, OUTLINE = P['SEL'], P['SEL_INACTIVE'], P['ROW_HOVER'], P['OUTLINE']
ACCENT, ACCENT_HOVER, ON_ACCENT, DIM = P['ACCENT'], P['ACCENT_HOVER'], P['ON_ACCENT'], P['DIM']
TEXT, DISABLED, RED = P['TEXT'], P['DISABLED'], P['RED']

# colours used everywhere (unless an element below says otherwise)
GLOBAL = {
    '#3584e4': ACCENT, '#4990e7': ACCENT_HOVER, '#f2ffff': ON_ACCENT,
    '#1d1d20': WIN, '#2c2c2c': WIN, '#2e2e32': WIN, '#222226': WIN, '#212121': OUTLINE,
    '#acb1bc': HOVER, '#5a616e': DIM, '#f04a50': RED, '#4285f4': DIM,
    '#5a5a5a': DISABLED, '#646464': DIM, '#dfdfdf': TEXT,
    '#6e6e6e': PRESS, '#797979': PRESS, '#93cee9': HOVER, '#3daee9': ACCENT,
    '#31363b': WIN, '#eff0f1': WIN, '#fcfcfc': WIN, '#587392': DIM,
}
# white (arrows, faint hover overlays) is the text colour (Mocha's is not white)
if TEXT.lower() != '#ffffff':
    GLOBAL['#ffffff'] = TEXT
# per element (the start of its id): colour -> colour, 'currentColor' included
ELEMENTS = [
    (r'^button-normal', {'#444444': FILL, '#414141': FILL}),
    (r'^button-focused', {'#4f4f4f': HOVER, '#444444': HOVER}),
    (r'^button-pressed', {'#797979': PRESS, '#616161': PRESS}),
    (r'^button-toggled', {'#6e6e6e': TOGGLE, 'currentColor': TOGGLE}),
    (r'^tbutton-toggled', {'#4b4b4b': HOVER}),
    (r'^tbutton-pressed', {'#444444': FILL}),
    (r'^itemview-pressed', {'#616161': SEL}),
    (r'^itemview-toggled', {'#4b4b4b': SEL_INACTIVE}),
    (r'^itemview-focused', {'#3d3d3d': ROW_HOVER}),
    (r'^menubaritem-focused', {'#414141': FILL}),
    (r'^menubaritem-(pressed|toggled)', {'#444444': SEL, '#4b4b4b': SEL}),
    (r'^tab-toggled', {'#444444': HOVER}),
    (r'^tab-focused', {'#414141': SEL_INACTIVE}),
    (r'^(lineedit|combo)-normal', {'#2e2e32': FILL}),
    (r'^lineedit-focused', {'#2e2e32': FILL, 'currentColor': DIM}),
    (r'^combo-focused', {'#2e2e32': FILL}),
    (r'^progress-normal', {'#616161': HOVER}),
    (r'^progress-pattern-disabled', {'#2e2e32': HOVER}),
    (r'^progress-pattern', {'currentColor': ACCENT}),
    (r'^slider-toggled', {'currentColor': ACCENT}),
    (r'^slidercursor', {'#2c2c2c': ACCENT_HOVER, '#3584e4': ACCENT_HOVER, 'currentColor': ACCENT_HOVER}),
    (r'^(tab-tear|menuitem-tearoff-focused)', {'currentColor': ACCENT}),
    (r'^dial-handle', {'currentColor': ACCENT_HOVER}),
    (r'^scrollbarslider-normal', {'#4b4b4b': P['SCROLL']}),
    (r'^scrollbarslider-focused', {'#4b4b4b': P['SCROLL_HOVER']}),
    (r'^scrollbarslider-pressed', {'#707070': P['SCROLL_PRESS']}),
    (r'^(checkbox|radio|menu-checkbox|menu-radio)-normal', {'#404040': P['CHECK']}),
    (r'^(checkbox|radio|menu-checkbox|menu-radio)-focused', {'#4b4b4b': P['CHECK_FOCUS']}),
]

def recolor(value, group):
    def one(m):
        c = m.group(0)
        key = c.lower() if c.startswith('#') else c
        if len(key) == 4 and key.startswith('#'):
            key = '#' + ''.join(ch * 2 for ch in key[1:])
        if group:
            for pat, table in ELEMENTS:
                if re.match(pat, group) and key in table:
                    return table[key]
        return GLOBAL.get(key, c)
    return re.sub(r'#[0-9a-fA-F]{6}\b|#[0-9a-fA-F]{3}\b|currentColor', one, value)

tree = ET.parse(os.path.join(src, 'KvLibadwaitaDark.svg'))
root = tree.getroot()
parent = {c: p for p in root.iter() for c in p}
part = re.compile(r'-(top|bottom|left|right|topleft|topright|bottomleft|bottomright)$')
def group_of(e):
    while e is not None:
        i = e.get('id')
        if i and re.match(r'^[a-z]+(-[a-z0-9]+)+$', i) and not re.match(r'^(path|rect|stop|linear|radial|layer|g|use|circle)', i):
            return part.sub('', i)
        e = parent.get(e)
    return None
for e in root.iter():
    g = group_of(e)
    # the slider's groove has no colour of its own (black at 25 %, hardly visible on
    # #1a1a1a): the text colour at 15 %, as GTK's
    if g == 'slider-normal' and e.tag.split('}')[1] in ('rect', 'path') and not e.get('fill') \
            and 'fill:' not in (e.get('style') or ''):
        e.set('style', 'fill:' + TEXT)
        e.set('opacity', '.15')
    for a in ('style', 'fill', 'stroke', 'stop-color', 'color'):
        v = e.get(a)
        if v:
            e.set(a, recolor(v, g))
    if e.tag == '{%s}style' % SVG and e.text:
        e.text = recolor(e.text, None)
tree.getroot().set('{http://sodipodi.sourceforge.net/DTD/sodipodi-0.dtd}docname', NAME + '.svg')
os.makedirs(out, exist_ok=True)
tree.write(os.path.join(out, NAME + '.svg'), encoding='utf-8', xml_declaration=True)

# ── the config: KvLibadwaitaDark's, with the palette ──
k = open(os.path.join(src, 'KvLibadwaitaDark.kvconfig')).read()
colors = {
    'window.color': WIN, 'base.color': WIN, 'alt.base.color': P['ALT_BASE'], 'button.color': FILL,
    'light.color': SEL, 'mid.light.color': P['MID_LIGHT'], 'dark.color': P['DARK'], 'mid.color': P['MID'],
    'highlight.color': P['HIGHLIGHT'], 'inactive.highlight.color': P['HIGHLIGHT_INACTIVE'],
    'text.color': TEXT, 'window.text.color': TEXT, 'button.text.color': TEXT,
    'disabled.text.color': DISABLED, 'tooltip.text.color': TEXT, 'highlight.text.color': TEXT,
    'link.color': P['LINK'], 'link.visited.color': P['VISITED'], 'progress.indicator.text.color': TEXT,
}
def setcolor(m):
    key = m.group(1)
    return '%s=%s' % (key, colors[key]) if key in colors else m.group(0)
k = re.sub(r'^([a-z.]+\.color)=.*$', setcolor, k, flags=re.M)
k = re.sub(r'(text\.[a-z]+\.color)=(#dfdfdf|#dedede)', r'\1=' + TEXT, k)
k = re.sub(r'(text\.[a-z]+\.color)=#787878', r'\1=' + DIM, k)
k = k.replace('author=Vince Liuice, based on KvAdapta by Tsu Jan',
              'author=frameshell, from KvLibadwaitaDark by GabePoel (based on Colloid-kde by Vince Liuice, KvAdapta by Tsu Jan)')
COMMENTS = {
    'Frame': 'The Frame colours (the shell and its GTK theme)',
    'FrameNoir': 'The Noir colours (the shell and its GTK theme): black and #060606',
    'FrameMocha': 'Catppuccin Mocha (the shell\'s Mocha theme and its GTK theme)',
}
k = k.replace('comment=An uncomplicated theme inspired by the Materia GTK theme',
              'comment=' + COMMENTS[NAME] + ' on KvLibadwaita\'s shapes')
open(os.path.join(out, NAME + '.kvconfig'), 'w').write(k)
print('written', out)
