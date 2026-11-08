.pragma library

// ---------------------------------------------------------------------------
// search.js - ranking for the app launcher (plain JavaScript, no QML).
//
//   rank(apps, query, counts) -> apps sorted best match first
//
//   apps    list of { id, name, generic, keywords, comment, exec }
//   query   what the user typed; several words must ALL match
//   counts  { appId: timesLaunched } - often used apps float up
//
// Score per word (best one wins):
//   name equals word 1000 | name starts with it 800 | a word of the name starts
//   with it 600 | name contains it 400 | letters appear in order (c-h-r-m ->
//   chromium) 100..300 | generic name / keywords / comment / command contain it 50..150
// ---------------------------------------------------------------------------

function fuzzy(text, word) {
    // letters of `word` must appear in `text` in order; tighter matches score more
    var pos = -1, gaps = 0;
    for (var i = 0; i < word.length; i++) {
        var next = text.indexOf(word.charAt(i), pos + 1);
        if (next < 0)
            return 0;
        if (pos >= 0)
            gaps += next - pos - 1;
        pos = next;
    }
    return Math.max(100, 300 - gaps * 10);
}

function wordScore(app, word) {
    var name = (app.name || "").toLowerCase();
    if (name === word)
        return 1000;
    if (name.indexOf(word) === 0)
        return 800;
    var parts = name.split(/[\s\-_.]+/);
    for (var i = 0; i < parts.length; i++) {
        if (parts[i].indexOf(word) === 0)
            return 600;
    }
    if (name.indexOf(word) >= 0)
        return 400;
    var f = word.length >= 2 ? fuzzy(name, word) : 0;
    if (f > 0)
        return f;
    if ((app.generic || "").toLowerCase().indexOf(word) >= 0)
        return 150;
    if ((app.keywords || "").toLowerCase().indexOf(word) >= 0)
        return 120;
    if ((app.exec || "").toLowerCase().indexOf(word) >= 0)
        return 80;
    if ((app.comment || "").toLowerCase().indexOf(word) >= 0)
        return 50;
    return 0;
}

function score(app, words, counts) {
    var total = 0;
    for (var i = 0; i < words.length; i++) {
        var s = wordScore(app, words[i]);
        if (s === 0)
            return 0;               // every word has to match something
        total += s;
    }
    var used = counts && counts[app.id] ? counts[app.id] : 0;
    return total / words.length + Math.min(used, 30) * 3;
}

function rank(apps, query, counts) {
    var words = (query || "").toLowerCase().split(/\s+/).filter(function (w) {
        return w.length > 0;
    });
    var scored = [];
    for (var i = 0; i < apps.length; i++) {
        var s = words.length === 0 ? 1 + Math.min(counts && counts[apps[i].id] ? counts[apps[i].id] : 0, 1000) : score(apps[i], words, counts);
        if (s > 0)
            scored.push({ app: apps[i], s: s });
    }
    scored.sort(function (a, b) {
        if (b.s !== a.s)
            return b.s - a.s;
        return (a.app.name || "").localeCompare(b.app.name || "");
    });
    return scored.map(function (e) {
        return e.app;
    });
}
