#!/usr/bin/env python3
"""Measure the match HUD against scripts/ui/HUD_SPEC.md: tools/hud_measure.py <shots-dir>.

Reads hud_<W>x<H>.png + hud_<W>x<H>_bare.png (from `--hud-verify-shots`), diffs each pair to get the HUD's own
pixels, and measures every element in 1080p-equivalent px (layout px x 1.5; the HUD is laid out for 1280x720 and
scaled by Settings._apply_ui_scale) against the reference number in the spec. Prints a table; exit 1 when an
element at 1920x1080 drifts more than TOL px, an element differs between sizes by more than TOL px, a HUD pixel
touches the window edge, or two HUD groups overlap."""
import glob, os, sys
import numpy as np
from PIL import Image
from scipy import ndimage

TOL = 2.0          # px at 1080p
MARGIN = 4         # px at 1080p: the least gap from a HUD part to the window edge (the ref's minimap sits 9 px in)
HP, HP_HI, SIL = (168, 242, 110), (194, 246, 154), (238, 246, 251)


def runs(v):
    out, s = [], None
    for i, x in enumerate(v):
        if x and s is None:
            s = i
        if not x and s is not None:
            out.append((s, i)); s = None
    return out + ([(s, len(v))] if s is not None else [])


class Shot:
    def __init__(s, path):
        s.img = np.asarray(Image.open(path).convert("RGB")).astype(int)
        bare = np.asarray(Image.open(path.replace(".png", "_bare.png")).convert("RGB")).astype(int)
        diff = np.abs(s.img - bare).max(axis=2)
        s.mask = diff > 10
        s.faint = diff > 3                           # also the dark HUD parts over a dark world
        s.H, s.W = s.mask.shape
        s.f = min(s.H / 720.0, s.W / 1240.0) / 1.5   # px per 1080p px (Settings._apply_ui_scale at ui_scale 1)
        s.dy = s.H - 1080 * s.f                      # bottom-anchored items sit at y = H - (1080 - y) * f
        s.dx = s.W - 1920 * s.f                      # right-anchored items likewise

    def bl(s, x0, y0, x1, y1):
        """A window in 1080p px, bottom-left anchored (x from the left, y as at 1080p), as pixel slices."""
        f = s.f
        return slice(int(s.dy + y0 * f), int(s.dy + y1 * f)), slice(int(x0 * f), int(x1 * f))

    def br(s, x0, y0, x1, y1):
        f = s.f
        return slice(int(s.dy + y0 * f), int(s.dy + y1 * f)), slice(int(s.dx + x0 * f), int(s.dx + x1 * f))

    def tl(s, x0, y0, x1, y1):
        f = s.f
        return slice(int(y0 * f), int(y1 * f)), slice(int(x0 * f), int(x1 * f))

    def tr(s, x0, y0, x1, y1):
        f = s.f
        return slice(int(y0 * f), int(y1 * f)), slice(int(s.dx + x0 * f), int(s.dx + x1 * f))

    def rowpx(s, y):
        return int(round(s.dy + y * s.f))

    def colpx(s, x, right=False):
        return int(round((s.dx if right else 0) + x * s.f))

    def near_row(s, y, x0, x1):
        r, c = s.rowpx(y), slice(int(x0 * s.f), int(x1 * s.f))
        return s.faint[r, c] & (s.img[r, c].max(axis=1) < 70)

    def dark(s, w):
        """The plate / frame pixels: HUD pixels that are dark (the frame is see-through, so its colour follows the world)."""
        return s.faint[w] & (s.img[w].max(axis=2) < 70)

    def near(s, w, col, tol):
        """Pixels of the HUD (not the world behind it) within tol of a colour."""
        return (np.abs(s.img[w] - np.array(col)).max(axis=2) <= tol) & s.faint[w]

    def ext(s, w, m, axis):
        """Extent (start, size) in 1080p px along axis 'x' or 'y' of the True pixels of m inside window w."""
        ys, xs = np.nonzero(m)
        if len(xs) == 0:
            return None
        v, o = (xs, w[1].start) if axis == "x" else (ys, w[0].start)
        return (o + v.min()) / s.f, (v.max() + 1 - v.min()) / s.f

    def line(s, w, m, axis):
        """The widest run along one row/column of the window (the longest `axis` run in m)."""
        best = None
        for i in range(m.shape[0] if axis == "x" else m.shape[1]):
            r = runs(m[i] if axis == "x" else m[:, i])
            for a, b in r:
                if best is None or b - a > best[1]:
                    best = (a, b - a, i)
        return best


# measured and left as it is, with the reason (a drift line that is a choice, not a bug)
KEPT = {"weapon silhouette height": "our rifle drawing is taller in the grip; width matches"}


def measure(s):
    """{element: (spec at 1080p px, measured)}; positions are x from the left (left items) or from the right edge."""
    R, f = {}, s.f
    # ---- self frame (bottom-left) ----
    w = s.bl(40, 950, 260, 1000)
    hp = s.near(w, HP, 14) | s.near(w, HP_HI, 10)
    R["health bar height"] = (23, s.ext(w, hp, "y")[1])
    body = s.near(w, HP, 14)       # the fill's own green, under the lighter top strip
    row = body[np.nonzero(body.sum(axis=1) > 0.5 * body.sum(axis=1).max())[0][0]]
    R["health bar width (top edge)"] = (162, (np.nonzero(row)[0].max() + 1 - np.nonzero(row)[0].min()) / f)
    seams = [a for a, _ in runs(~row[np.nonzero(row)[0].min():np.nonzero(row)[0].max()])]
    R["health segment pitch"] = (26, (seams[-1] - seams[0]) / (len(seams) - 1) / f)
    w = s.bl(190, 950, 215, 1020)
    R["plate height"] = (52, s.ext(w, s.dark(w), "y")[1])
    r1 = runs(s.near_row(1008, 20, 280)); r2 = runs(s.dark(s.bl(20, 958, 280, 961)).any(axis=0))
    R["plate left x (bottom edge)"] = (50, 20 + r1[0][0] / f)
    R["plate right x (top edge)"] = (246, 20 + r2[-1][1] / f)
    w = s.bl(40, 1030, 260, 1048)
    xp = s.dark(w) | s.near(w, (211, 62, 253), 50)
    R["xp bar height"] = (13, s.ext(w, xp, "y")[1])
    R["xp bar width"] = (177, s.ext(w, xp, "x")[1])
    w = s.bl(212, 880, 290, 954)
    ex, ey = s.ext(w, s.faint[w], "x"), s.ext(w, s.faint[w], "y")
    R["armour badge dia"] = (52, min(ex[1], ey[1]))
    R["armour badge centre x"] = (248, ex[0] + ex[1] / 2)
    # abilities: five slots, rank tabs sit above them so read the top edge at the slot's left side
    w = s.bl(380, 985, 720, 1030)
    cols = runs(s.mask[w].any(axis=0))
    cols = [(a / f + 380, b / f + 380) for a, b in cols if b - a > 20 * f]
    R["ability slots shown"] = (5, len(cols))
    if len(cols) >= 5:
        R["slot size"] = (55, float(np.mean([b - a for a, b in cols[:5]])))
        R["slot pitch"] = (66, (cols[4][0] - cols[0][0]) / 4)
        R["first slot left x"] = (391, cols[0][0])
        col = s.mask[s.bl(0, 940, 1, 1080)[0], s.colpx(cols[0][0]) + 6]
        tops = runs(col)
        R["slot top y"] = (978, 940 + tops[0][0] / f if tops else -1)
        keys = runs(s.mask[s.bl(0, 1036, 1, 1075)[0], s.colpx(cols[1][0]) + 10])
        R["key pill height"] = (19, (keys[0][1] - keys[0][0]) / f if keys else -1)
    w = s.bl(240, 960, 400, 1040)
    sil = s.near(w, SIL, 10)
    R["weapon silhouette x"] = (256, s.ext(w, sil, "x")[0]); R["weapon silhouette width"] = (118, s.ext(w, sil, "x")[1])
    R["weapon silhouette height"] = (48, s.ext(w, sil, "y")[1])
    # ---- minimap and phase line (top-left) ----
    row = runs(s.faint[int(159 * f), :int(300 * f)])
    R["minimap width"] = (252, (row[-1][1] - row[0][0]) / f if row else -1)
    R["minimap centre x"] = (138, (row[0][0] + row[-1][1]) / 2 / f if row else -1)
    w = s.tl(60, 4, 220, 31)
    ct = runs(s.mask[w].any(axis=0))
    R["clock tab width"] = (59, max(b - a for a, b in ct) / f)
    col = runs(s.faint[0:int(46 * f), int(120 * f)])
    R["clock tab height"] = (15, max(b - a for a, b in col) / f if col else -1)
    bar = runs(s.mask[int(313 * f), :int(300 * f)])
    R["phase bar left x"] = (19, bar[0][0] / f if bar else -1)
    R["phase bar right x"] = (257, bar[-1][1] / f if bar else -1)
    h = runs(s.mask[int(300 * f):int(330 * f), int(150 * f)])
    R["phase bar height"] = (6, (h[-1][1] - h[-1][0]) / f if h else -1)
    # ---- bottom-right: belt, cards, gear column (x from the right edge) ----
    w = s.br(1400, 1020, 1920, 1040)
    belt = [(a / f + 1400 - 1920, b / f + 1400 - 1920) for a, b in runs(s.mask[w].any(axis=0)) if b - a > 6 * f]
    slots = [r for r in belt if 36 < r[1] - r[0] < 44]
    R["belt slot size"] = (39, float(np.mean([b - a for a, b in slots[:4]])))
    R["belt slot pitch"] = (43, (slots[3][0] - slots[0][0]) / 3)
    cards = [r for r in belt if 50 < r[1] - r[0] < 60]
    R["item card width"] = (53, float(np.mean([b - a for a, b in cards[:3]])))
    R["item card pitch"] = (60, (cards[2][0] - cards[0][0]) / 2)
    R["gap belt to cards"] = (48, cards[0][0] - slots[3][1])
    w = s.br(1676, 940, 1724, 1060)
    cc = [r for r in runs(s.mask[w].any(axis=1)) if r[1] - r[0] > 20 * f]
    R["item card top y"] = (982, 940 + cc[0][0] / f)
    g = runs(s.mask[s.br(1872, 860, 1888, 1060)].any(axis=1))       # the strip over the icons' middles
    g = [(a / f + 860, b / f + 860) for a, b in g]
    R["gear icon dia"] = (34, float(np.mean([b - a for a, b in g[-3:]])))
    R["gear icon pitch"] = (38, (g[-1][0] - g[-3][0]) / 2)
    # ---- top-right: counters, rule, currency ----
    ws = [s.tr(c - 14, 12, c + 14, 36) for c in (1674, 1716, 1758)]
    R["counter icon width (mean of 3)"] = (15, float(np.mean([s.ext(w, s.mask[w], "x")[1] for w in ws])))
    R["counter icon centre y"] = (26, float(np.mean([sum(s.ext(w, s.mask[w], "y")[::1][:1]) + s.ext(w, s.mask[w], "y")[1] / 2 for w in ws])))
    ys = runs(s.mask[s.tr(1700, 36, 1701, 52)[0], s.colpx(1700, True)])
    R["rule y"] = (44, 36 + (ys[0][0] + ys[0][1]) / 2 / f if ys else -1)
    w = s.tr(1870, 4, 1920, 44)
    gem = runs(ndimage.binary_opening(s.mask[w], iterations=2).any(axis=0))
    mid = s.colpx(1887, True) - w[1].start            # the coin's centre (22 layout px from the right edge)
    coin = [r for r in gem if r[0] <= mid < r[1]]
    R["currency coin width"] = (26, (coin[0][1] - coin[0][0]) / f if coin else -1)
    return R


def edges_and_overlaps(s):
    """Problems: a group closer than MARGIN px (1080p) to the window edge, or two named groups whose boxes overlap."""
    bad = []
    f = s.f
    # groups: windows in 1080p px that hold one part each; the box is tight to the HUD's pixels
    groups = {"vitals": s.bl(0, 810, 215, 1080), "badge": s.bl(216, 888, 280, 952), "weapon": s.bl(250, 970, 380, 1060),
              "abilities": s.bl(384, 965, 712, 1070), "belt": s.br(1450, 980, 1630, 1080),
              "cards": s.br(1668, 975, 1850, 1080), "gear": s.br(1856, 860, 1904, 1048),
              "minimap": s.tl(0, 0, 300, 330), "squad": s.tl(0, 322, 345, 530), "score": s.tr(1640, 0, 1920, 110)}
    boxes = {}
    solid = ndimage.binary_opening(s.mask, iterations=2)     # not the world's own movement (grass) between the frames
    for nm, w in groups.items():
        ys, xs = np.nonzero(solid[w])
        if len(xs):
            boxes[nm] = (w[1].start + xs.min(), w[0].start + ys.min(), w[1].start + xs.max(), w[0].start + ys.max())
            gap = min(boxes[nm][0], boxes[nm][1], s.W - 1 - boxes[nm][2], s.H - 1 - boxes[nm][3]) / f
            if gap < MARGIN:
                bad.append("%s is %.0f px from the window edge (margin %d)" % (nm, gap, MARGIN))
    names = list(boxes)
    for i in range(len(names)):
        for j in range(i + 1, len(names)):
            a, b = boxes[names[i]], boxes[names[j]]
            if a[0] <= b[2] and b[0] <= a[2] and a[1] <= b[3] and b[1] <= a[3]:
                bad.append("%s overlaps %s" % (names[i], names[j]))
    return bad


def main():
    d = sys.argv[1] if len(sys.argv) > 1 else "shots"
    shots = {}
    for p in sorted(glob.glob(os.path.join(d, "hud_*x*.png"))):
        if not p.endswith("_bare.png"):
            shots[os.path.basename(p)[4:-4]] = Shot(p)
    if "1920x1080" not in shots:
        sys.exit("need hud_1920x1080.png")
    res = {k: measure(s) for k, s in shots.items()}
    names = list(shots)
    print("%-32s %7s" % ("element (1080p px)", "spec") + "".join("%12s" % n for n in names) + "  drift")
    fail = []
    for el, (spec, got) in res["1920x1080"].items():
        others = [res[n][el][1] for n in names]
        drift = got - spec
        spread = max(others) - min(others)
        flag = "" if abs(drift) <= TOL and spread <= TOL else "  <-- DRIFT"
        if flag and el in KEPT:
            flag = "  kept: " + KEPT[el]
        elif flag:
            fail.append(el)
        print("%-32s %7.1f" % (el, spec) + "".join("%12.1f" % v for v in others) + "  %+5.1f%s" % (drift, flag))
    for n, s in shots.items():
        for b in edges_and_overlaps(s):
            print("%s: %s" % (n, b)); fail.append(b)
    print("FAIL: %d" % len(fail) if fail else "OK: every element within %.0f px" % TOL)
    sys.exit(1 if fail else 0)


main()
