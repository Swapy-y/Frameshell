.pragma library

// Which workspace pills the island shows.
//
//   occupied   ids of the workspaces that have at least one window
//   focused    id of the workspace you are on
//   base       how many pills are always there (1 … base)
//   cap        the "next" pill is only created up to this id
//
// Rules:
//   * 1 … base are always shown.
//   * A workspace above `base` is shown while it has windows or while you are on it.
//   * When the highest workspace that has windows is `base` or more, the next
//     one is shown too, so there is always an empty one to open an app in.
//   * Anything else above `base` disappears (close the last window in it and its
//     pill goes away).
function pillIds(occupied, focused, base, cap) {
    var show = {};
    var i;
    for (i = 1; i <= base; i++)
        show[i] = true;

    var top = 0;
    for (i = 0; i < occupied.length; i++) {
        var id = occupied[i];
        if (id > 0) {
            show[id] = true;
            if (id > top)
                top = id;
        }
    }

    if (focused > 0)
        show[focused] = true;
    if (top >= base && top < cap)
        show[top + 1] = true;

    return Object.keys(show).map(Number).sort(function (a, b) {
        return a - b;
    });
}
