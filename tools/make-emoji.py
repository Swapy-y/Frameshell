#!/usr/bin/env python3
# make-emoji.py - makes config/quickshell/frame/components/emoji.js, the emoji
# list of the shell's emoji picker (SUPER + .), from emojibase-data
# (https://emojibase.dev, MIT licence):
#
#   npm pack emojibase-data && mkdir x && tar -xzf emojibase-data-*.tgz -C x
#   python3 tools/make-emoji.py x/package [15.1]
#
# Every emoji up to the given Emoji version (default 15.1: newer ones may not be
# in the emoji font yet), in Unicode's order, without skin tones and the
# "component" group (skin tones, hair styles on their own). Per emoji: the emoji,
# its name, its group and the words it is found by (its tags and GitHub's
# shortcodes, e.g. "thumbsup").
import json
import os
import sys

GROUPS = ["Smileys & Emotion", "People & Body", None, "Animals & Nature", "Food & Drink",
          "Travel & Places", "Activities", "Objects", "Symbols", "Flags"]   # 2 = component: left out


def main():
    pkg = sys.argv[1]
    max_version = float(sys.argv[2]) if len(sys.argv) > 2 else 15.1
    data = json.load(open(os.path.join(pkg, "en", "data.json"), encoding="utf-8"))
    codes = {}
    gh = os.path.join(pkg, "en", "shortcodes", "github.json")
    if os.path.exists(gh):
        codes = json.load(open(gh, encoding="utf-8"))
    shown = [g for g in GROUPS if g is not None]
    rows = []
    for e in sorted(data, key=lambda e: e.get("order", 1 << 30)):
        g = e.get("group")
        if g is None or GROUPS[g] is None or e.get("version", 0) > max_version:
            continue
        words = [t.lower() for t in e.get("tags", [])]
        sc = codes.get(e["hexcode"], [])
        words += [s.replace("_", " ") for s in ([sc] if isinstance(sc, str) else sc)]
        seen, kw = set(), []
        for w in words:
            if w not in seen:
                seen.add(w)
                kw.append(w)
        rows.append([e["emoji"], e["label"], shown.index(GROUPS[g]), " ".join(kw)])
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "config", "quickshell", "frame",
                       "components", "emoji.js")
    with open(out, "w", encoding="utf-8") as f:
        f.write(".pragma library\n")
        f.write("// The emoji of the emoji picker (modules/EmojiPicker.qml): [emoji, name, group, words].\n")
        f.write("// Made by tools/make-emoji.py from emojibase-data (https://emojibase.dev, MIT licence),\n")
        f.write("// Emoji %s and older, %d emoji. Don't edit by hand: run the script.\n" % (max_version, len(rows)))
        f.write("var groups = %s;\n" % json.dumps(shown, ensure_ascii=False))
        f.write("var list = [\n")
        for r in rows:
            f.write(json.dumps(r, ensure_ascii=False) + ",\n")
        f.write("];\n")
    print("%d emoji -> %s" % (len(rows), os.path.normpath(out)))


main()
