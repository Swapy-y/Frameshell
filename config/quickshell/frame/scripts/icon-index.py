#!/usr/bin/env python3
# icon-index.py [--check THEME]... THEME... - the icons of icon themes, for the shell's
# "App icons" (the Settings app's Appearance page, services/IconPacks.qml).
#
# Qt can only use the icon theme the shell started with (shell.qml's IconTheme pragma), so for
# another one the shell needs the files themselves. For every THEME this prints which file each
# icon name is in - looked up the way the freedesktop icon theme spec says: the theme, then the
# themes it inherits (index.theme, "Inherits"), hicolor (where apps put their own icons) and
# /usr/share/pixmaps. Of the sizes of an icon it takes an SVG (the biggest drawing of it: Papirus
# draws its 16 px icons simpler than its 64 px ones), else the biggest picture.
# A theme after --check is only looked for (the shell's own theme: Qt finds its icons).
#
# Prints one JSON object, short (Papirus has some 15 000 icons):
#   { "THEME": { "found": true / false, "dirs": [ "/folder", ... ], "icons": { "name": n } } }
# where icon "name" is the file  dirs[n // 3] + "/" + name + [".svg", ".png", ".xpm"][n % 3]
# ("dirs" and "icons" only for the themes that are not just checked).
import configparser
import json
import os
import sys

EXTENSIONS = (".svg", ".png", ".xpm")


def base_dirs():
    """where icon themes are, the first one first (the spec's order)"""
    home = os.path.expanduser("~")
    data_home = os.environ.get("XDG_DATA_HOME") or os.path.join(home, ".local", "share")
    data_dirs = os.environ.get("XDG_DATA_DIRS") or "/usr/local/share:/usr/share"
    out = [os.path.join(home, ".icons"), os.path.join(data_home, "icons")]
    out += [os.path.join(d, "icons") for d in data_dirs.split(":") if d]
    seen = []
    for d in out:
        if d not in seen and os.path.isdir(d):
            seen.append(d)
    return seen


def theme_dirs(name):
    """the folders of a theme (it may be split over several base folders)"""
    return [os.path.join(b, name) for b in base_dirs() if os.path.isdir(os.path.join(b, name))]


def read_index(dirs):
    """its index.theme: (the themes it inherits, { subfolder: (size, scale) }) - the size of a
    scalable folder is the biggest it is made for (MaxSize)"""
    for d in dirs:
        path = os.path.join(d, "index.theme")
        if not os.path.isfile(path):
            continue
        parser = configparser.ConfigParser(interpolation=None, strict=False)
        parser.optionxform = str
        try:
            parser.read(path, encoding="utf-8")
        except (configparser.Error, UnicodeDecodeError, OSError):
            return [], {}
        if not parser.has_section("Icon Theme"):
            return [], {}
        head = parser["Icon Theme"]
        inherits = [t.strip() for t in head.get("Inherits", "").split(",") if t.strip()]
        subdirs = {}
        names = head.get("Directories", "") + "," + head.get("ScaledDirectories", "")
        for sub in (s.strip() for s in names.split(",")):
            if not sub or not parser.has_section(sub):
                continue
            sec = parser[sub]
            try:
                size = int(sec.get("Size", "0"))
                if sec.get("Type", "Threshold") == "Scalable":
                    size = max(size, int(sec.get("MaxSize", str(size))))
                scale = int(sec.get("Scale", "1"))
            except ValueError:
                continue
            subdirs[sub] = (size, scale)
        return inherits, subdirs
    return [], {}


def icons_of(dirs, subdirs):
    """{ name: path } of one theme, the best file of each name"""
    best = {}
    seen = set()                        # a folder linked under two names (Papirus' @2x) once
    for d in dirs:
        for sub, (size, scale) in subdirs.items():
            folder = os.path.join(d, sub)
            real = os.path.realpath(folder)
            if real in seen:
                continue
            seen.add(real)
            try:
                entries = os.scandir(folder)
            except OSError:
                continue
            with entries:
                for e in entries:
                    stem, ext = os.path.splitext(e.name)
                    if ext not in EXTENSIONS:
                        continue
                    # an SVG draws sharp at any size (the biggest drawing first); else the
                    # biggest picture (xpm last)
                    score = (1 << 20 if ext == ".svg" else 0) + size * scale * (0.5 if ext == ".xpm" else 1)
                    if stem not in best or score > best[stem][0]:
                        best[stem] = (score, os.path.join(folder, e.name))
    return {k: v[1] for k, v in best.items()}


def index(name):
    """(found, { name: path }) of a theme with the themes it builds on"""
    found = bool(theme_dirs(name))
    icons = {}
    chain, todo = [], [name]
    while todo:                         # the theme, then what it inherits, in order
        t = todo.pop(0)
        if t in chain or len(chain) > 20:
            continue
        chain.append(t)
        inherits, _ = read_index(theme_dirs(t))
        todo += [i for i in inherits if i not in chain]
    if "hicolor" in chain:
        chain.remove("hicolor")
    chain.append("hicolor")
    for t in chain:
        dirs = theme_dirs(t)
        _, subdirs = read_index(dirs)
        for k, v in icons_of(dirs, subdirs).items():
            icons.setdefault(k, v)      # a theme before it has it already
    try:                                # last: /usr/share/pixmaps
        with os.scandir("/usr/share/pixmaps") as entries:
            for e in entries:
                stem, ext = os.path.splitext(e.name)
                if ext in EXTENSIONS and e.is_file():
                    icons.setdefault(stem, e.path)
    except OSError:
        pass
    return found, icons


def main(args):
    out = {}
    i = 0
    while i < len(args):
        if args[i] == "--check" and i + 1 < len(args):
            out[args[i + 1]] = {"found": bool(theme_dirs(args[i + 1]))}
            i += 2
            continue
        found, icons = index(args[i])
        dirs, where, short = [], {}, {}
        for name, path in icons.items():
            folder, file = os.path.split(path)
            if folder not in where:
                where[folder] = len(dirs)
                dirs.append(folder)
            short[name] = where[folder] * 3 + EXTENSIONS.index(os.path.splitext(file)[1])
        out[args[i]] = {"found": found, "dirs": dirs, "icons": short}
        i += 1
    json.dump(out, sys.stdout, separators=(",", ":"))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
