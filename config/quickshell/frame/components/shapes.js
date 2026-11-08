.pragma library

// Geometry helpers for the "frame" look.
//
// Everything is expressed as SVG path strings (consumed by QtQuick.Shapes
// PathSvg) in *overlay pixel coordinates*:
//   W,H  screen size           F  frame thickness (top / left / right)
//   B    bottom bar height     R  radius of the wallpaper window corners
//
// The wallpaper "window" is the rectangle (F, F) - (W-F, H-B) with rounded
// corners. The dark frame is everything outside it. Panels ("flaps") are
// extra dark shapes that grow out of the frame and are merged into it with
// concave "ears" so the whole thing reads as one continuous piece.

var OFF = 2;   // how far outside the screen the hidden parts of paths go

function n(v) {
    return Math.round(v * 100) / 100;
}

function pt(x, y) {
    return n(x) + "," + n(y);
}

// Inner (wallpaper) rounded rectangle, drawn counter-clockwise so that it
// punches a hole through the outer rectangle with the non-zero fill rule too.
function innerPath(W, H, F, B, R) {
    var IL = F, IT = F, IR = W - F, IB = H - B;
    var r = Math.max(0, Math.min(R, (IR - IL) / 2, (IB - IT) / 2));
    var s = "M" + pt(IL + r, IT);
    s += " A" + n(r) + "," + n(r) + " 0 0 0 " + pt(IL, IT + r);
    s += " L" + pt(IL, IB - r);
    s += " A" + n(r) + "," + n(r) + " 0 0 0 " + pt(IL + r, IB);
    s += " L" + pt(IR - r, IB);
    s += " A" + n(r) + "," + n(r) + " 0 0 0 " + pt(IR, IB - r);
    s += " L" + pt(IR, IT + r);
    s += " A" + n(r) + "," + n(r) + " 0 0 0 " + pt(IR - r, IT);
    s += " Z";
    return s;
}

// Full frame: outer rectangle (clockwise) + inner hole (counter-clockwise).
function ringPath(W, H, F, B, R) {
    return "M0,0 L" + pt(W, 0) + " L" + pt(W, H) + " L" + pt(0, H) + " Z " + innerPath(W, H, F, B, R);
}

// A panel that grows out of the frame.
//
//  o.x, o.y, o.w, o.h        bounding rectangle (overlay coordinates, may be
//                            fractional - that is what makes animations smooth)
//  o.top/bottom/left/right   which sides of that rectangle sit on the
//                            corresponding screen edge (touch the frame)
//  o.rb                      radius of the free (convex) corners
//  o.re                      radius of the concave "ears" where the panel
//                            meets the frame
//
// Corners are walked clockwise starting at the top-left. At every corner:
//   both neighbouring sides attached -> square (hidden in the screen corner)
//   one neighbouring side attached   -> concave ear blending into the frame
//   none attached                    -> ordinary rounded convex corner
//
// Radii are shrunk (all by the same factor) when the panel is too small for
// them, so a panel that is only a few pixels big is a small, soft bump that
// grows out of the frame instead of a clipped or overlapping shape.
//
// Returns "" while nothing of the panel sticks out of the frame yet.
function flapPath(o) {
    var W = o.W, H = o.H, F = o.F, B = o.B;
    var x0 = o.x, y0 = o.y, x1 = o.x + o.w, y1 = o.y + o.h;
    var IL = F, IT = F, IR = W - F, IB = H - B;
    var top = !!o.top, bottom = !!o.bottom, left = !!o.left, right = !!o.right;

    // the part of the panel that is inside the window area (what you can see)
    var dw = (right ? IR : x1) - (left ? IL : x0);
    var dh = (bottom ? IB : y1) - (top ? IT : y0);
    if (dw < 0.5 || dh < 0.5)
        return "";

    // radius every corner would like to have
    var rb0 = Math.max(0, o.rb), re0 = Math.max(0, o.re);
    function want(a, b) {
        return (a && b) ? 0 : ((a || b) ? re0 : rb0);
    }
    var rtl = want(top, left), rtr = want(top, right);
    var rbr = want(bottom, right), rbl = want(bottom, left);

    // every free edge has to be long enough for the two corner radii at its ends
    var k = 1;
    function fit(len, sum) {
        if (sum > 0 && len < sum)
            k = Math.min(k, len / sum);
    }
    if (!top)
        fit(dw, rtl + rtr);
    if (!bottom)
        fit(dw, rbl + rbr);
    if (!left)
        fit(dh, rtl + rbl);
    if (!right)
        fit(dh, rtr + rbr);
    rtl *= k; rtr *= k; rbr *= k; rbl *= k;

    var segs = [];
    function P(x, y) {                       // line-to (or move-to for the first point)
        segs.push((segs.length === 0 ? "M" : "L") + pt(x, y));
    }
    function A(r, x, y, sweep) {             // 90 degree arc
        segs.push("A" + n(r) + "," + n(r) + " 0 0 " + sweep + " " + pt(x, y));
    }

    // ---- top-left (arrive going up the left side, leave going right) ----
    if (top && left) {
        P(-OFF, -OFF);
    } else if (top) {
        P(x0, IT + rtl); A(rtl, x0 - rtl, IT, 0); P(x0 - rtl, -OFF);
    } else if (left) {
        P(-OFF, y0 - rtl); P(IL, y0 - rtl); A(rtl, IL + rtl, y0, 0);
    } else {
        P(x0, y0 + rtl); A(rtl, x0 + rtl, y0, 1);
    }

    // ---- top-right (arrive going right along the top, leave going down) ----
    if (top && right) {
        P(W + OFF, -OFF);
    } else if (top) {
        P(x1 + rtr, -OFF); P(x1 + rtr, IT); A(rtr, x1, IT + rtr, 0);
    } else if (right) {
        P(IR - rtr, y0); A(rtr, IR, y0 - rtr, 0); P(W + OFF, y0 - rtr);
    } else {
        P(x1 - rtr, y0); A(rtr, x1, y0 + rtr, 1);
    }

    // ---- bottom-right (arrive going down the right side, leave going left) ----
    if (bottom && right) {
        P(W + OFF, H + OFF);
    } else if (bottom) {
        P(x1, IB - rbr); A(rbr, x1 + rbr, IB, 0); P(x1 + rbr, H + OFF);
    } else if (right) {
        P(W + OFF, y1 + rbr); P(IR, y1 + rbr); A(rbr, IR - rbr, y1, 0);
    } else {
        P(x1, y1 - rbr); A(rbr, x1 - rbr, y1, 1);
    }

    // ---- bottom-left (arrive going left along the bottom, leave going up) ----
    if (bottom && left) {
        P(-OFF, H + OFF);
    } else if (bottom) {
        P(x0 - rbl, H + OFF); P(x0 - rbl, IB); A(rbl, x0, IB - rbl, 0);
    } else if (left) {
        P(IL + rbl, y1); A(rbl, IL, y1 + rbl, 0); P(-OFF, y1 + rbl);
    } else {
        P(x0 + rbl, y1); A(rbl, x0, y1 - rbl, 1);
    }

    segs.push("Z");
    return segs.join(" ");
}

function clamp(v, lo, hi) {
    return Math.max(lo, Math.min(hi, v));
}

function lerp(a, b, t) {
    return a + (b - a) * t;
}

// The whole number closest to `v` that has the same odd/even-ness as `total`.
// A shape that is centred inside `total` pixels then lands exactly on whole
// pixels, so its edges stay perfectly sharp.
function sameParity(v, total) {
    return 2 * Math.round((v - total) / 2) + total;
}
