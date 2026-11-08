#!/usr/bin/env python3
# ═══════════════════════════════════════════════════════════════════════════
#  make-themes.py - makes the GTK themes and the Qt colour schemes of the
#  shell's colour themes (Config.qml: Default, Noir, Mocha) from the Frame ones.
#
#    python3 make-themes.py            (run it in this folder's parent, or anywhere)
#
#  Frame (the Default theme) is the hand-made original:
#      themes/Frame/                       GTK 3 / GTK 4 theme
#      config/qt5ct|qt6ct/colors/frame.conf    Qt palettes
#  Every other theme is the same files with each colour swapped for the one that
#  has the same job in its palette (below):
#      themes/Frame-Noir/, themes/Frame-Mocha/
#      config/qt5ct|qt6ct/colors/frame-noir.conf, frame-mocha.conf
#  So: change how a theme looks -> edit its palette here and run this again;
#  change the GTK theme itself -> edit themes/Frame and run this again.
#  (The Kvantum themes - the shapes of Qt apps - come from Kvantum/make-frame.py,
#  with the same colours.)
# ═══════════════════════════════════════════════════════════════════════════
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)

# ── the palettes ────────────────────────────────────────────────────────────
# GTK: the colour of each job. Frame's are the colours in themes/Frame (checked).
GTK = {
    'Frame': dict(
        BG='#1a1a1a',          # windows, views, header bars, dialogs
        FG='#ffffff',          # text
        ON='#1a1a1a',          # text on the accent / red / green / yellow
        ACCENT='#ffffff',      # main buttons, switches, checkboxes
        RED='#ff6b6b', GREEN='#8fd694', YELLOW='#ffb454',
        OUTLINE='#313131',     # header bar and sidebar edges
        SIDEBAR='#1f1f1f', SIDEBAR2='#1c1c1c',
        CARD='#222222',        # cards, thumbnails
        POPOVER='#1a1a1a',     # menus and popovers
        SELECTED='#3a3a3a',    # selected rows and files
        TEXT_SELECTION='#3e3e3e',  # selected text (textSelection in Config.qml)
        LINK='#6aa3d9', VISITED='#b48ead',
        INFOBAR='#2a2a2a', INFOBAR_HOVER='#313131',
        MENU_BORDER='#313131', TOOLTIP='#1a1a1a',
        OVERVIEW='#1f1f1f', TOGGLE='rgba(255, 255, 255, 0.2)',
    ),
    # black #000000, cards / fields / buttons / selections #060606; a little lighter
    # only where it has to show (hover, press)
    'Noir': dict(
        BG='#000000', FG='#ffffff', ON='#000000', ACCENT='#ffffff',
        RED='#ff6b6b', GREEN='#8fd694', YELLOW='#ffb454',
        OUTLINE='#060606', SIDEBAR='#000000', SIDEBAR2='#000000',
        CARD='#060606', POPOVER='#060606', SELECTED='#060606', TEXT_SELECTION='#222222',
        LINK='#6aa3d9', VISITED='#b48ead',
        INFOBAR='#060606', INFOBAR_HOVER='#0d0d0d',
        MENU_BORDER='#161616', TOOLTIP='#060606',
        OVERVIEW='#000000', TOGGLE='rgba(255, 255, 255, 0.2)',
        # buttons, entries: #060606 instead of white 10 % (which would be #1a1a1a)
        FILL='#060606', FILL_HOVER='#0d0d0d', FILL_ACTIVE='#161616',
    ),
    # Catppuccin Mocha (catppuccin.com/palette), the accent Mauve
    'Mocha': dict(
        BG='#181825',          # Mantle
        FG='#cdd6f4',          # Text
        ON='#11111b',          # Crust
        ACCENT='#cba6f7',      # Mauve
        RED='#f38ba8', GREEN='#a6e3a1', YELLOW='#f9e2af',
        OUTLINE='#313244',     # Surface0
        SIDEBAR='#1e1e2e', SIDEBAR2='#1e1e2e',   # Base
        CARD='#1e1e2e',        # Base
        POPOVER='#181825',     # Mantle
        SELECTED='#45475a',    # Surface1
        TEXT_SELECTION='#474859',
        LINK='#89b4fa', VISITED='#b4befe',       # Blue, Lavender
        INFOBAR='#313244', INFOBAR_HOVER='#45475a',
        MENU_BORDER='#45475a', TOOLTIP='#181825',
        OVERVIEW='#1e1e2e', TOGGLE='rgba(205, 214, 244, 0.2)',
    ),
}

# Qt (qt5ct / qt6ct colour schemes). Frame's are the colours in colors/frame.conf.
QT = {
    'Frame': dict(FG='#ffffff', FILL='#313131', LIGHT='#3a3a3a', MIDLIGHT='#333333', DARK='#0f0f0f',
                  MID='#1f1f1f', BG='#1a1a1a', SHADOW='#000000', HIGHLIGHT='#3e3e3e',
                  HIGHLIGHT_INACTIVE='#3e3e3e', HIGHLIGHT_DISABLED='#3a3a3a', LINK='#6aa3d9',
                  VISITED='#b48ead', ALT_BASE='#1f1f1f', TOOLTIP='#2a2a2a', DIM='#8c8c8c',
                  DISABLED='#6a6a6a', FAINT='#575757', ACCENT='#ffffff'),
    'Noir': dict(FG='#ffffff', FILL='#060606', LIGHT='#161616', MIDLIGHT='#0d0d0d', DARK='#000000',
                 MID='#060606', BG='#000000', SHADOW='#000000', HIGHLIGHT='#222222',
                 HIGHLIGHT_INACTIVE='#222222', HIGHLIGHT_DISABLED='#060606', LINK='#6aa3d9',
                 VISITED='#b48ead', ALT_BASE='#060606', TOOLTIP='#060606', DIM='#8c8c8c',
                 DISABLED='#575757', FAINT='#3a3a3a', ACCENT='#ffffff'),
    'Mocha': dict(FG='#cdd6f4', FILL='#313244', LIGHT='#45475a', MIDLIGHT='#313244', DARK='#11111b',
                  MID='#1e1e2e', BG='#181825', SHADOW='#000000', HIGHLIGHT='#474859',
                  HIGHLIGHT_INACTIVE='#474859', HIGHLIGHT_DISABLED='#313244', LINK='#89b4fa',
                  VISITED='#b4befe', ALT_BASE='#1e1e2e', TOOLTIP='#313244', DIM='#9399b2',
                  DISABLED='#6c7086', FAINT='#585b70', ACCENT='#cba6f7'),
}

DESCRIBE = {
    'Noir': 'black #000000 windows, #060606 cards, fields, buttons and menus, white text,\n'
            '   #8c8c8c dim text, white main buttons with black text, #ff6b6b for errors, #ffb454\n'
            '   for warnings',
    'Mocha': 'Catppuccin Mocha (catppuccin.com/palette): Mantle #181825 windows, Base\n'
             '   #1e1e2e cards, Surface0 #313244 buttons, Surface1 #45475a selections, Text #cdd6f4,\n'
             '   Mauve #cba6f7 main buttons with Crust text, Red #f38ba8 errors, Yellow #f9e2af warnings',
}

# ── GTK: which job each named colour has ────────────────────────────────────
NAMED = {
    'accent_bg_color': 'ACCENT', 'accent_fg_color': 'ON', 'accent_color': 'ACCENT',
    'destructive_bg_color': 'RED', 'destructive_fg_color': 'ON', 'destructive_color': 'RED',
    'success_bg_color': 'GREEN', 'success_fg_color': 'ON', 'success_color': 'GREEN',
    'warning_bg_color': 'YELLOW', 'warning_fg_color': 'ON', 'warning_color': 'YELLOW',
    'error_bg_color': 'RED', 'error_fg_color': 'ON', 'error_color': 'RED',
    'window_bg_color': 'BG', 'window_fg_color': 'FG', 'view_bg_color': 'BG', 'view_fg_color': 'FG',
    'headerbar_bg_color': 'BG', 'headerbar_fg_color': 'FG', 'headerbar_border_color': 'FG',
    'headerbar_backdrop_color': 'BG', 'headerbar_shade_color': 'OUTLINE',
    'headerbar_darker_shade_color': 'OUTLINE',
    'sidebar_bg_color': 'SIDEBAR', 'sidebar_fg_color': 'FG', 'sidebar_backdrop_color': 'SIDEBAR',
    'sidebar_border_color': 'OUTLINE',
    'secondary_sidebar_bg_color': 'SIDEBAR2', 'secondary_sidebar_fg_color': 'FG',
    'secondary_sidebar_backdrop_color': 'SIDEBAR2', 'secondary_sidebar_border_color': 'OUTLINE',
    'card_bg_color': 'CARD', 'card_fg_color': 'FG', 'dialog_bg_color': 'BG', 'dialog_fg_color': 'FG',
    'popover_bg_color': 'POPOVER', 'popover_fg_color': 'FG',
    'thumbnail_bg_color': 'CARD', 'thumbnail_fg_color': 'FG',
    'theme_selected_bg_color': 'SELECTED', 'theme_selected_fg_color': 'FG',
    'theme_unfocused_selected_bg_color': 'SELECTED', 'theme_unfocused_selected_fg_color': 'FG',
    'frame_link_color': 'LINK', 'frame_visited_color': 'VISITED',
    'overview_bg_color': 'OVERVIEW', 'overview_fg_color': 'FG',
    'active_toggle_bg_color': 'TOGGLE', 'active_toggle_fg_color': 'FG',
}
# shadows stay as they are (black at some %)
KEEP = {'sidebar_shade_color', 'secondary_sidebar_shade_color', 'card_shade_color',
        'popover_shade_color', 'shade_color', 'scrollbar_outline_color'}

# colours written straight into a rule: their job by the rule's selector
def literal_role(selector, value):
    sel = selector.lower()
    if 'selection' in sel:
        return {'#3e3e3e': 'TEXT_SELECTION'}.get(value)
    if 'infobar' in sel:
        return {'#2a2a2a': 'INFOBAR', '#313131': 'INFOBAR_HOVER'}.get(value)
    if 'tooltip' in sel:
        return {'#1a1a1a': 'TOOLTIP', '#313131': 'MENU_BORDER'}.get(value)
    if 'banner' in sel:
        return {'#1a1a1a': 'BG'}.get(value)
    if 'toast' in sel:
        return {'#1a1a1a': 'BG'}.get(value)
    if 'popover' in sel or 'menu' in sel:
        return {'#313131': 'MENU_BORDER'}.get(value)
    return None


def recolor_css(text, name, header):
    pal, frame = GTK[name], GTK['Frame']

    def check(role, old):
        if frame[role].lower() != old.lower():
            sys.exit('themes/Frame: %r is not the Frame palette\'s %s (%s)' % (old, role, frame[role]))
        return pal[role]

    # the first comment: the header
    out = re.sub(r'\A/\*.*?\*/', lambda m: header, text, count=1, flags=re.S) if header else text

    # @define-color name value;
    def named(m):
        key, value = m.group(1), m.group(2)
        if key in KEEP:
            return m.group(0)
        if key not in NAMED:
            sys.exit('themes/Frame: no job for @define-color ' + key)
        return '@define-color %s %s;' % (key, check(NAMED[key], value))
    out = re.sub(r'@define-color ([a-z_]+) ([^;]+);', named, out)

    # --name: value;  (GTK 4)
    def variable(m):
        key, value = m.group(1).replace('-', '_'), m.group(2)
        if key in KEEP:
            return m.group(0)
        if key not in NAMED:
            sys.exit('themes/Frame: no job for --' + m.group(1))
        return '--%s: %s;' % (m.group(1), check(NAMED[key], value))
    out = re.sub(r'--([a-z-]+): ([^;]+);', variable, out)

    # colours written in rules (outside comments)
    def block(m):
        selector, body = m.group(1), m.group(2)
        if '@define-color' in selector or ':root' in selector:     # (named colours: done above)
            return m.group(0)
        def lit(mm):
            role = literal_role(selector, mm.group(0).lower())
            if role is None:
                sys.exit('themes/Frame: no job for %s in "%s"' % (mm.group(0), selector.strip()))
            return check(role, mm.group(0))
        return selector + '{' + re.sub(r'#[0-9a-fA-F]{6}\b', lit, body) + '}'
    parts = re.split(r'(/\*.*?\*/)', out, flags=re.S)
    for i in range(0, len(parts), 2):
        parts[i] = re.sub(r'([^{}]*)\{([^{}]*)\}', block, parts[i])
    return ''.join(parts)


# ── Noir: buttons and fields in #060606 (adw-gtk3 / libadwaita make them white
#    at 10 %, which on black is #1a1a1a) ──
NOIR_GTK3 = '''
/* ── Noir: buttons and fields #060606 (adw-gtk3 makes them white at 10 %%) ── */
button:not(.flat):not(.suggested-action):not(.destructive-action):not(.osd):not(.titlebutton),
spinbutton:not(.vertical),
entry,
combobox button.combo {
  background-color: %(FILL)s;
}
button:not(.flat):not(.suggested-action):not(.destructive-action):not(.osd):not(.titlebutton):hover {
  background-color: %(FILL_HOVER)s;
}
button:not(.flat):not(.suggested-action):not(.destructive-action):not(.osd):not(.titlebutton):active,
button:not(.flat):not(.suggested-action):not(.destructive-action):not(.osd):not(.titlebutton):checked {
  background-color: %(FILL_ACTIVE)s;
}
spinbutton:not(.vertical) entry,
spinbutton:not(.vertical) button {
  background-color: transparent;
}
spinbutton:disabled:not(.vertical),
entry:disabled {
  background-color: %(FILL)s;
}
/* ── Noir: the row under the pointer #060606 (adw-gtk3: white at 7 %%, file lists 4 %%),
   a little lighter pressed ── */
row.activatable:hover,
row.activatable.has-open-popup,
treeview.view:not(:backdrop):not(:selected):hover {
  background-color: %(FILL)s;
}
row.activatable:active {
  background-color: %(FILL_HOVER)s;
}
/* ── Noir: selected list rows #060606 like selected files (adw-gtk3: white at 10 %%) ── */
row:selected,
row.activatable:selected,
row.activatable:selected:backdrop {
  background-color: %(SELECTED)s;
}
row.activatable:selected:hover,
row.activatable:selected.has-open-popup {
  background-color: %(FILL_HOVER)s;
}
row.activatable:selected:active {
  background-color: %(FILL_ACTIVE)s;
}
/* popovers and boxed lists are #060606 themselves, so a selected row or the row under
   the pointer would vanish there: as adw-gtk3 has it */
popover row:selected,
popover row.activatable:selected,
list.content > row:selected,
list.content > row.activatable:selected {
  background-color: alpha(currentColor, 0.1);
}
popover row.activatable:selected:active,
list.content > row.activatable:selected:active {
  background-color: alpha(currentColor, 0.19);
}
popover row.activatable:selected:hover,
popover row.activatable:selected.has-open-popup,
list.content > row.activatable:selected:hover,
list.content > row.activatable:selected.has-open-popup {
  background-color: alpha(currentColor, 0.12);
}
popover row.activatable:selected:backdrop,
list.content > row.activatable:selected:backdrop {
  background-color: alpha(currentColor, 0.07);
}
popover row.activatable:hover,
popover row.activatable.has-open-popup,
list.content > row.activatable.has-open-popup {
  background-color: alpha(currentColor, 0.07);
}
popover row.activatable:active,
list.content > row.activatable:active {
  background-color: alpha(currentColor, 0.16);
}
/* on a #060606 card or boxed list a #060606 button would vanish: one step lighter */
.card button:not(.flat):not(.suggested-action):not(.destructive-action):not(.osd):not(.titlebutton),
.boxed-list button:not(.flat):not(.suggested-action):not(.destructive-action):not(.osd):not(.titlebutton) {
  background-color: %(FILL_HOVER)s;
}
.card button:not(.flat):not(.suggested-action):not(.destructive-action):not(.osd):not(.titlebutton):hover,
.boxed-list button:not(.flat):not(.suggested-action):not(.destructive-action):not(.osd):not(.titlebutton):hover {
  background-color: %(FILL_ACTIVE)s;
}
'''
NOIR_GTK4 = '''
/* ── Noir: buttons and fields #060606 (libadwaita makes them white at 10 %%) ── */
button:not(.flat):not(.suggested-action):not(.destructive-action):not(.osd):not(.circular):not(.pill),
splitbutton:not(.flat) > button,
splitbutton:not(.flat) > menubutton > button,
spinbutton,
entry,
dropdown > button {
  background-color: %(FILL)s;
}
button:not(.flat):not(.suggested-action):not(.destructive-action):not(.osd):not(.circular):not(.pill):hover,
splitbutton:not(.flat) > button:hover,
splitbutton:not(.flat) > menubutton > button:hover {
  background-color: %(FILL_HOVER)s;
}
button:not(.flat):not(.suggested-action):not(.destructive-action):not(.osd):not(.circular):not(.pill):active,
button:not(.flat):not(.suggested-action):not(.destructive-action):not(.osd):not(.circular):not(.pill):checked {
  background-color: %(FILL_ACTIVE)s;
}
spinbutton > text,
spinbutton > button {
  background-color: transparent;
}
/* ── Noir: the row, file or sidebar entry under the pointer #060606 (libadwaita: white
   at 4 %%, sidebars 7 %%), a little lighter pressed ── */
row.activatable:hover,
row.activatable.has-open-popup,
.navigation-sidebar row.activatable:hover,
.navigation-sidebar row.activatable.has-open-popup,
.navigation-sidebar child.activatable:hover,
.navigation-sidebar child.activatable.has-open-popup,
.navigation-sidebar flowboxchild:hover,
.navigation-sidebar flowboxchild.has-open-popup,
gridview > child.activatable:hover,
flowbox > flowboxchild:hover {
  background-color: %(FILL)s;
}
row.activatable:active,
.navigation-sidebar row.activatable:active,
.navigation-sidebar child.activatable:active,
.navigation-sidebar flowboxchild:active,
gridview > child.activatable:active,
flowbox > flowboxchild:active {
  background-color: %(FILL_HOVER)s;
}
/* ── Noir: selected rows, files and sidebar entries #060606 (libadwaita tints them
   with the accent at 25 %%, sidebars with white at 10 %%), a little lighter under the
   pointer and pressed ── */
.view:selected,
.view:selected:focus,
row:selected,
listview > row:selected,
columnview > listview > row:selected,
.navigation-sidebar row:selected,
gridview > child:selected,
flowbox > flowboxchild:selected {
  background-color: %(SELECTED)s;
}
row.activatable:selected:hover,
row.activatable:selected.has-open-popup,
.navigation-sidebar row.activatable:selected:hover,
gridview > child.activatable:selected:hover,
flowbox > flowboxchild:selected:hover {
  background-color: %(FILL_HOVER)s;
}
row.activatable:selected:active,
.navigation-sidebar row.activatable:selected:active,
gridview > child.activatable:selected:active,
flowbox > flowboxchild:selected:active {
  background-color: %(FILL_ACTIVE)s;
}
/* popovers, cards and boxed lists are #060606 themselves, so a selected row would vanish
   there: white at 10 %%, 13 %% under the pointer, 19 %% pressed (libadwaita's sidebars) */
popover row:selected,
.card row:selected,
.boxed-list > row:selected,
.boxed-list-separate > row:selected,
list.content > row:selected {
  background-color: color-mix(in srgb, currentColor 10%%, transparent);
}
popover row.activatable:selected:hover,
popover row.activatable:selected.has-open-popup,
.card row.activatable:selected:hover,
.card row.activatable:selected.has-open-popup,
.boxed-list > row.activatable:selected:hover,
.boxed-list > row.activatable:selected.has-open-popup,
.boxed-list-separate > row.activatable:selected:hover,
.boxed-list-separate > row.activatable:selected.has-open-popup,
list.content > row.activatable:selected:hover,
list.content > row.activatable:selected.has-open-popup {
  background-color: color-mix(in srgb, currentColor 13%%, transparent);
}
popover row.activatable:selected:active,
.card row.activatable:selected:active,
.boxed-list > row.activatable:selected:active,
.boxed-list-separate > row.activatable:selected:active,
list.content > row.activatable:selected:active {
  background-color: color-mix(in srgb, currentColor 19%%, transparent);
}
/* there the row under the pointer as libadwaita has it too, so it stays visible (and on
   the see-through on-screen panels) */
popover row.activatable:hover,
popover row.activatable.has-open-popup,
.card row.activatable:hover,
.card row.activatable.has-open-popup {
  background-color: color-mix(in srgb, currentColor 4%%, transparent);
}
popover row.activatable:active,
.card row.activatable:active {
  background-color: color-mix(in srgb, currentColor 8%%, transparent);
}
.osd row.activatable:hover,
.osd row.activatable.has-open-popup {
  background-color: color-mix(in srgb, currentColor 7%%, transparent);
}
.osd row.activatable:active {
  background-color: color-mix(in srgb, currentColor 16%%, transparent);
}
.osd row.activatable:selected:hover,
.osd row.activatable:selected.has-open-popup {
  background-color: color-mix(in srgb, currentColor 13%%, transparent);
}
.osd row.activatable:selected:active {
  background-color: color-mix(in srgb, currentColor 19%%, transparent);
}
row.entry:not(:selected).activatable.focused:hover,
row.entry:not(:selected).activatable.focused:active,
row.spin:not(:selected).activatable.focused:hover,
row.spin:not(:selected).activatable.focused:active {
  background-color: transparent;
}
list.boxed-list-separate > row.expander row.header:not(:selected).activatable:hover,
list.boxed-list > row:not(:selected).activatable:hover,
list.content > row:not(:selected).activatable:hover,
list.boxed-list > row.expander row.header:not(:selected).activatable:hover,
list.content > row.expander row.header:not(:selected).activatable:hover,
row.expander list.nested > row:not(:selected).activatable:hover,
list.boxed-list-separate > row.expander row.header:not(:selected).activatable.has-open-popup,
list.boxed-list > row:not(:selected).activatable.has-open-popup,
list.content > row:not(:selected).activatable.has-open-popup,
list.boxed-list > row.expander row.header:not(:selected).activatable.has-open-popup,
list.content > row.expander row.header:not(:selected).activatable.has-open-popup,
row.expander list.nested > row:not(:selected).activatable.has-open-popup {
  background-color: color-mix(in srgb, currentColor 3%%, transparent);
}
list.boxed-list-separate > row.expander row.header:not(:selected).activatable:active,
list.boxed-list > row:not(:selected).activatable:active,
list.content > row:not(:selected).activatable:active,
list.boxed-list > row.expander row.header:not(:selected).activatable:active,
list.content > row.expander row.header:not(:selected).activatable:active,
row.expander list.nested > row:not(:selected).activatable:active {
  background-color: color-mix(in srgb, currentColor 8%%, transparent);
}
list.boxed-list-separate > row:not(.expander):not(:selected).activatable:hover,
list.boxed-list-separate > row:not(.expander):not(:selected).activatable.has-open-popup {
  background-color: var(--card-bg-color);
  background-image: image(color-mix(in srgb, currentColor 3%%, transparent));
}
list.boxed-list-separate > row:not(.expander):not(:selected).activatable:active {
  background-color: var(--card-bg-color);
  background-image: image(color-mix(in srgb, currentColor 8%%, transparent));
}
list.boxed-list-separate > row.entry:not(:selected).activatable.focused:hover,
list.boxed-list-separate > row.entry:not(:selected).activatable.focused:active,
list.boxed-list-separate > row.spin:not(:selected).activatable.focused:hover,
list.boxed-list-separate > row.spin:not(:selected).activatable.focused:active {
  background-color: var(--card-bg-color);
  background-image: none;
}
/* menus and drop-down lists exactly as libadwaita has them: no colour for the selected
   row (the check mark shows it), white at 10 %% under the pointer, 19 %% pressed */
popover.menu list > row:selected,
popover.menu listview > row:selected {
  background: none;
}
popover.menu list > row:hover,
popover.menu list > row:hover:selected.activatable,
popover.menu listview > row:hover,
popover.menu listview > row:hover:selected.activatable {
  background-color: color-mix(in srgb, currentColor 10%%, transparent);
}
popover.menu list > row:active,
popover.menu list > row:active:selected.activatable,
popover.menu listview > row:active,
popover.menu listview > row:active:selected.activatable {
  background-color: color-mix(in srgb, currentColor 19%%, transparent);
}
popover.menu list > row.has-open-popup,
popover.menu list > row.has-open-popup:selected.activatable,
popover.menu listview > row.has-open-popup,
popover.menu listview > row.has-open-popup:selected.activatable {
  background-color: color-mix(in srgb, currentColor 10%%, transparent);
}

/* on a #060606 card or boxed list a #060606 button would vanish: one step lighter */
.card button:not(.flat):not(.suggested-action):not(.destructive-action):not(.osd):not(.circular):not(.pill),
.boxed-list button:not(.flat):not(.suggested-action):not(.destructive-action):not(.osd):not(.circular):not(.pill) {
  background-color: %(FILL_HOVER)s;
}
.card button:not(.flat):not(.suggested-action):not(.destructive-action):not(.osd):not(.circular):not(.pill):hover,
.boxed-list button:not(.flat):not(.suggested-action):not(.destructive-action):not(.osd):not(.circular):not(.pill):hover {
  background-color: %(FILL_ACTIVE)s;
}
/* Nautilus's path bar (the folder buttons at the top) one colour: #060606 like the buttons
   in it (Nautilus makes the bar white at 10 %% and its buttons see-through) */
.nautilus-pathbar {
  background-color: %(FILL)s;
}
'''

# the rules above, added to the end of each theme's colors.css
EXTRAS = {'Noir': {3: NOIR_GTK3, 4: NOIR_GTK4}}


def header(name, gtk_version):
    low = name.lower()
    if gtk_version == 3:
        return ('/* Frame-%s - colours for GTK 3 apps (Thunar, file pickers, Firefox\'s dialogs ...)\n'
                '   ->  ~/.local/share/themes/Frame-%s/gtk-3.0/colors.css\n\n'
                '   The shell\'s %s theme: %s.\n'
                '   gtk.css loads adw-gtk3-dark first; this file only replaces its colours.\n'
                '   Made by themes/make-themes.py from themes/Frame (what each rule is for: see the\n'
                '   comments there): change the palette in make-themes.py and run it again (an edit\n'
                '   here is lost then). Restart an app to see a change. */'
                % (name, name, name, DESCRIBE[name]))
    return ('/* Frame-%s - colours for GTK 4 and libadwaita apps (pavucontrol, GNOME apps, file pickers ...)\n'
            '   ->  ~/.local/share/themes/Frame-%s/gtk-4.0/colors.css\n\n'
            '   The shell\'s %s theme: %s.\n'
            '   Loaded by the Frame-%s theme (plain GTK 4 apps) and, while %s is the shell\'s theme,\n'
            '   by ~/.config/gtk-4.0/gtk.css (libadwaita apps, which ignore themes; scripts/theme.sh\n'
            '   points it here). Made by themes/make-themes.py from themes/Frame (what each rule is\n'
            '   for: see the comments there): change the palette in make-themes.py and run it again\n'
            '   (an edit here is lost then). Restart an app to see a change. */'
            % (name, name, name, DESCRIBE[name], name, name))


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    old = open(path).read() if os.path.exists(path) else None
    if old != text:
        open(path, 'w').write(text)
        print('written', os.path.relpath(path, ROOT))


def gtk_theme(name):
    src = os.path.join(HERE, 'Frame')
    dst = os.path.join(HERE, 'Frame-' + name)
    sub = lambda t: t.replace('themes/Frame/', 'themes/Frame-%s/' % name).replace('Frame - ', 'Frame-%s - ' % name, 1)
    write(os.path.join(dst, 'index.theme'),
          open(os.path.join(src, 'index.theme')).read()
          .replace('Name=Frame', 'Name=Frame-' + name)
          .replace('GtkTheme=Frame', 'GtkTheme=Frame-' + name)
          .replace('Comment=The frameshell colours', 'Comment=The frameshell %s colours' % name))
    for v in (3, 4):
        d = 'gtk-%d.0' % v
        for f in ('gtk.css', 'gtk-dark.css'):
            write(os.path.join(dst, d, f), sub(open(os.path.join(src, d, f)).read()))
        css = recolor_css(open(os.path.join(src, d, 'colors.css')).read(), name, header(name, v))
        # the comments inside describe Frame's colours: keep only the header (themes/Frame
        # has them all)
        head, body = css.split('*/', 1)
        body = re.sub(r'/\*.*?\*/\n?', '', body, flags=re.S)
        css = head + '*/' + re.sub(r'\n{3,}', '\n\n', body)
        extra = EXTRAS.get(name, {}).get(v, '')
        write(os.path.join(dst, d, 'colors.css'), css + (extra % GTK[name] if extra else ''))


# ── Qt: the roles in qt5ct's order (qt6ct adds the accent) ──
QT_ACTIVE = ['FG', 'FILL', 'LIGHT', 'MIDLIGHT', 'DARK', 'MID', 'FG', 'FG', 'FG', 'BG', 'BG', 'SHADOW',
             'HIGHLIGHT', 'FG', 'LINK', 'VISITED', 'ALT_BASE', 'SHADOW', 'TOOLTIP', 'FG', 'DIM', 'ACCENT']
QT_DISABLED = ['DISABLED', 'FILL', 'LIGHT', 'MIDLIGHT', 'DARK', 'MID', 'DISABLED', 'FG', 'DISABLED', 'BG',
               'BG', 'SHADOW', 'HIGHLIGHT_DISABLED', 'DIM', 'DISABLED', 'DISABLED', 'ALT_BASE', 'SHADOW',
               'TOOLTIP', 'FG', 'FAINT', 'FAINT']
QT_INACTIVE = QT_ACTIVE[:12] + ['HIGHLIGHT_INACTIVE'] + QT_ACTIVE[13:]


def qt_line(pal, roles, count):
    return ', '.join('#ff' + pal[r].lower().lstrip('#') for r in roles[:count])


def qt_scheme(name, version):
    tool = 'qt%dct' % version
    count = 21 if version == 5 else 22
    src = os.path.join(ROOT, 'config', tool, 'colors', 'frame.conf')
    text = open(src).read()
    # Frame's file must be exactly what its palette gives
    lines = {k: qt_line(QT['Frame'], r, count) for k, r in
             (('active', QT_ACTIVE), ('disabled', QT_DISABLED), ('inactive', QT_INACTIVE))}
    for k, v in lines.items():
        if '%s_colors=%s\n' % (k, v) not in text:
            sys.exit('config/%s/colors/frame.conf: %s_colors is not the Frame palette' % (tool, k))
    pal = QT[name]
    out = ('; Frame %s - %s colour scheme (goes to ~/.config/%s/colors/frame-%s.conf)\n'
           '; The palette Qt apps use while %s is the shell\'s theme (scripts/theme.sh switches it),\n'
           '; the same as the Frame%s Kvantum theme\'s and the Frame-%s GTK theme\'s.\n'
           '; Made by themes/make-themes.py: change the palette there and run it again.\n'
           '; Each line lists the colours for one state (active / disabled / inactive) in %s\'s fixed order.\n\n'
           '[ColorScheme]\n'
           'active_colors=%s\ndisabled_colors=%s\ninactive_colors=%s\n'
           % (name, tool, tool, name.lower(), name, name, name, tool,
              qt_line(pal, QT_ACTIVE, count), qt_line(pal, QT_DISABLED, count), qt_line(pal, QT_INACTIVE, count)))
    write(os.path.join(ROOT, 'config', tool, 'colors', 'frame-%s.conf' % name.lower()), out)


if __name__ == '__main__':
    # Frame, recoloured with its own palette, must come out unchanged (else a colour has
    # no job here yet)
    for v in (3, 4):
        d = os.path.join(HERE, 'Frame', 'gtk-%d.0' % v, 'colors.css')
        t = open(d).read()
        if recolor_css(t, 'Frame', None) != t:
            sys.exit('themes/Frame/gtk-%d.0/colors.css does not come out unchanged' % v)
    for name in GTK:
        if name != 'Frame':
            gtk_theme(name)
            qt_scheme(name, 5)
            qt_scheme(name, 6)
    print('done')
