"""Assemble the Warden concept sheets from the hand-drawn layers in src/<id>.svg.in.

Each .svg.in starts with <!--META {json}--> (names, palette, materials, notes)
and holds four hand-drawn groups: front, tq (3/4 view), bust, relic.
Shorthand attributes, expanded here so every sheet shares one line weight and
one lighting model (key light upper left, rim light right):
  m="mat"      material gradient fill + ink outline (lw="n" sets the width)
  f="mat"      material gradient fill, no outline (f="mat:r" = radial)
  sh="30"      form shadow, 30% shade        hl="30"   highlight, 30% white
  rim="3"      rim-light stroke (the META rim colour), width 3
  ln="2"       interior ink line, width 2
  sg="40"      soft form shadow: a gradient fading in toward the right (sgl: left,
               sgv: bottom, sgu: top, sgr: radial, darkest at the edge), 40% at its darkest
  hg="40"      soft highlight, white fading out from the upper left
  rg="60"      soft rim light: the META rim colour fading in toward the right edge
class="fx" marks glows and particles (left out of the black silhouette row).
Shape helpers (expanded first, into plain paths):
  <limb pts="x y r; x y r; ..." m="mat"/>  a smooth tapered capsule along a spline
               through the points, r the half-width at each (muscles, fingers, tails);
               fluff="0.2" scallops the edge into tufts (per="n" sets tufts per segment)
  <brush pts="x y w; ..." c="#hex|rim"/>  a tapered ink stroke (w the half-width;
               give the ends 0 for a brush point), ink by default

python3 build.py [ids...]  ->  ../<id>.svg, and src/out/lineup.svg
"""
import json
import math
import os
import re
import sys

from ttf import Font

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.dirname(HERE)
ORDER = ["bulwark", "archer", "juggernaut", "ashwick", "ostra", "dolm",
         "thief", "mage", "gunslinger", "dredge", "tender", "rimewright"]
INK = "#1d1724"
SHADE = "#241631"
FIG = 0.76  # default sheet scale of the full-body views (META "sheet_scale" overrides it)
UNIT = 4.0  # drawing units per cm: every figure stands on y=0 at true height (META "height_cm")
FONTS = {"L": Font(os.path.join(HERE, "../../../../fonts/LilitaOne-Regular.ttf")),
         "R": Font(os.path.join(HERE, "../../../../fonts/Rubik.ttf"))}


class Text:
    """Glyph-outline text; collects the glyph defs it uses."""

    def __init__(self):
        self.used = {}

    def run(self, s, x, y, size, font="R", fill=INK, anchor="start", spacing=0.0):
        f = FONTS[font]
        w = f.width(s, size) + spacing * size * (len(s) - 1)
        if anchor == "middle":
            x -= w / 2
        elif anchor == "end":
            x -= w
        k = size / f.upm
        out = ['<g fill="%s">' % fill]
        for c in s:
            g = f.glyph(c)
            if c != " ":
                gid = "gl%s%d" % (font, g)
                self.used[gid] = (font, g)
                out.append('<use href="#%s" transform="translate(%.1f %.1f) scale(%.4f)"/>' % (gid, x, y, k))
            x += f.adv[g] * k + spacing * size
        out.append("</g>")
        return "".join(out)

    def wrap(self, s, width, size, font="R", first_indent=0.0):
        f, lines, cur = FONTS[font], [], ""
        for word in s.split():
            trial = (cur + " " + word).strip()
            limit = width - (first_indent if not lines else 0)
            if cur and f.width(trial, size) > limit:
                lines.append(cur)
                cur = word
            else:
                cur = trial
        return lines + [cur]

    def defs(self):
        return "".join('<path id="%s" d="%s"/>' % (gid, FONTS[fo].path(g))
                       for gid, (fo, g) in sorted(self.used.items()))


def _mix(a, b, k):
    a, b = [int(a[i:i + 2], 16) for i in (1, 3, 5)], [int(b[i:i + 2], 16) for i in (1, 3, 5)]
    return "#%02x%02x%02x" % tuple(round(x + (y - x) * k) for x, y in zip(a, b))


def _spline(pts, per=10):
    """Catmull-Rom through (x, y, r) points; returns dense (x, y, r) samples."""
    if len(pts) == 1:
        return pts
    ext = [pts[0]] + pts + [pts[-1]]
    out = []
    for i in range(1, len(ext) - 2):
        p0, p1, p2, p3 = ext[i - 1], ext[i], ext[i + 1], ext[i + 2]
        for k in range(per):
            t = k / per
            t2, t3 = t * t, t * t * t
            x, y = (0.5 * (2 * p1[j] + (-p0[j] + p2[j]) * t + (2 * p0[j] - 5 * p1[j] + 4 * p2[j] - p3[j]) * t2
                           + (-p0[j] + 3 * p1[j] - 3 * p2[j] + p3[j]) * t3) for j in (0, 1))
            s_ = t * t * (3 - 2 * t)
            out.append((x, y, p1[2] + (p2[2] - p1[2]) * s_))
    out.append(pts[-1])
    return out


def _outline(pts, fluff=0.0, per=10):
    smp = _spline(pts, per)
    n = len(smp)
    left, right = [], []
    for i, (x, y, r) in enumerate(smp):
        a, b = smp[max(i - 1, 0)], smp[min(i + 1, n - 1)]
        dx, dy = b[0] - a[0], b[1] - a[1]
        d = math.hypot(dx, dy) or 1.0
        nx, ny = -dy / d, dx / d
        k = (1 + fluff if i % 2 else 1 - fluff * 0.4) if fluff and 0 < i < n - 1 else 1.0
        left.append((x + nx * r * k, y + ny * r * k))
        right.append((x - nx * r * k, y - ny * r * k))
    loop = list(left)

    def cap(c, r, ang0):
        return [(c[0] + r * math.cos(ang0 + math.pi * k / 6), c[1] + r * math.sin(ang0 + math.pi * k / 6))
                for k in range(1, 6)] if r > 0.4 else []
    (x1, y1, r1), (x0, y0, _) = smp[-1], smp[-2]
    loop += cap((x1, y1), r1, math.atan2(y1 - y0, x1 - x0) - math.pi / 2)
    loop += right[::-1]
    (x1, y1, r1), (x0, y0, _) = smp[0], smp[1]
    loop += cap((x1, y1), r1, math.atan2(y1 - y0, x1 - x0) - math.pi / 2)
    m = len(loop)
    mid = lambda a, b: ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
    st = mid(loop[-1], loop[0])
    d = ["M%.1f %.1f" % st]
    for i in range(m):
        q, e = loop[i], mid(loop[i], loop[(i + 1) % m])
        d.append("Q%.1f %.1f %.1f %.1f" % (q[0], q[1], e[0], e[1]))
    return "".join(d) + "Z"


def _pts(s):
    return [tuple(float(v) for v in chunk.split()) for chunk in s.split(";") if chunk.strip()]


def _element(src, eid):
    """The full <g id="eid">...</g> element from src (balanced), or ''."""
    i = src.find('<g id="%s"' % eid)
    if i < 0:
        return ""
    depth, j = 0, i
    for mo in re.finditer(r"<g\b[^>]*?(/?)>|</g>", src[i:]):
        if mo.group(0) == "</g>":
            depth -= 1
        elif not mo.group(1):
            depth += 1
        if depth == 0:
            j = i + mo.end()
            break
    return src[i:j]


def _drop_fx_groups(svg):
    """Remove every <g ... class="fx" ...> group, nested groups and all (balanced)."""
    while True:
        mo = re.search(r'<g\b[^>]*\bclass="fx"[^>]*>', svg)
        if not mo:
            return svg
        depth, end = 0, len(svg)
        for t in re.finditer(r"<g\b[^>]*?(/?)>|</g>", svg[mo.start():]):
            if t.group(0) == "</g>":
                depth -= 1
            elif not t.group(1):
                depth += 1
            if depth == 0:
                end = mo.start() + t.end()
                break
        svg = svg[:mo.start()] + svg[end:]


def inline_uses(svg, lib):
    """Replace <use href="#L-x"> with a copy of L-x from lib (for the silhouette pass)."""
    def sub(mo):
        el = _element(lib, mo.group(1))
        el = re.sub(r'^<g id="[^"]*"', "<g", el)
        return '<g %s>%s</g>' % (mo.group(2), el) if el else mo.group(0)
    for _ in range(3):
        svg = re.sub(r'<use href="#(L-[\w-]+)"\s*([^<>]*?)/>', sub, svg)
    return svg


def shapes(svg, meta):
    """Expand <limb> and <brush> into paths (see the module doc)."""
    def limb(mo):
        attrs = mo.group(2)
        fl = re.search(r'\bfluff="([^"]*)"', attrs)
        per = re.search(r'\bper="([^"]*)"', attrs)
        d = _outline(_pts(re.search(r'\bpts="([^"]*)"', attrs).group(1)),
                     float(fl.group(1)) if fl else 0.0, int(per.group(1)) if per else 10)
        attrs = re.sub(r'\s*\b(pts|fluff|per)="[^"]*"', "", attrs)
        if mo.group(1) == "brush":
            c = re.search(r'\bc="([^"]*)"', attrs)
            col = c.group(1) if c else INK
            col = meta.get("rim", "#bfe9ff") if col == "rim" else col
            attrs = 'ink="1" fill="%s"' % col + re.sub(r'\s*\bc="[^"]*"', "", attrs)
        return '<path d="%s" %s/>' % (d, attrs.strip())
    return re.sub(r'<(limb|brush)\b([^<>]*?)/>', limb, svg)


def load(cid):
    src = open(os.path.join(HERE, cid + ".svg.in")).read()
    meta = json.loads(re.search(r"<!--META(.*?)-->", src, re.S).group(1))
    body = re.sub(r"<!--META.*?-->", "", src, flags=re.S)
    groups = {}
    for name in ("defs", "front", "tq", "bust", "relic"):
        m = re.search(r'<g id="%s">(.*?)</g><!--/%s-->' % (name, name), body, re.S)
        groups[name] = m.group(1) if m else ""
    meta["id"] = cid
    return meta, groups


def materials(meta):
    cid, out = meta["id"], []
    rim = meta.get("rim", "#bfe9ff")
    for name, (lt, base, dk) in meta["mat"].items():
        stops = ('<stop offset="0" stop-color="%s"/><stop offset="0.45" stop-color="%s"/>'
                 '<stop offset="0.86" stop-color="%s"/><stop offset="1" stop-color="%s"/>'
                 % (lt, base, dk, _mix(dk, rim, 0.22)))
        out.append('<linearGradient id="%s-%s" x1="0.15" y1="0" x2="0.85" y2="1">%s</linearGradient>'
                   % (cid, name, stops))
        out.append('<radialGradient id="%s-%s-r" cx="0.38" cy="0.32" r="0.75">%s</radialGradient>'
                   % (cid, name, stops))
    for name, col in meta.get("glow", {}).items():
        out.append('<radialGradient id="%s-%s-g"><stop offset="0" stop-color="%s" stop-opacity="0.9"/>'
                   '<stop offset="0.35" stop-color="%s" stop-opacity="0.45"/>'
                   '<stop offset="1" stop-color="%s" stop-opacity="0"/></radialGradient>' % (cid, name, col, col, col))
    out.append('<linearGradient id="%s-rimg" x1="0" y1="0" x2="1" y2="0"><stop offset="0.55" stop-color="%s" '
               'stop-opacity="0"/><stop offset="1" stop-color="%s"/></linearGradient>' % (cid, rim, rim))
    return "".join(out)


def _mat_ref(cid, v):
    if v.endswith(":g"):
        return "url(#%s-%s-g)" % (cid, v[:-2])
    if v.endswith(":r"):
        return "url(#%s-%s-r)" % (cid, v[:-2])
    return "url(#%s-%s)" % (cid, v)


def expand(svg, meta, silhouette=False):
    """Expand the shorthand attributes (see the module doc)."""
    cid, rim = meta["id"], meta.get("rim", "#bfe9ff")
    svg = re.sub(r'url\(#L-', "url(#%s-" % cid, svg)
    svg = re.sub(r'href="#L-', 'href="#%s-' % cid, svg)
    svg = re.sub(r'id="L-', 'id="%s-' % cid, svg)
    svg = shapes(svg, meta)
    if silhouette:
        svg = _drop_fx_groups(svg)
        svg = re.sub(r'<[a-z]+[^<>]*?(class="fx"|\b(sh|hl|rim|ln|ink|sg|sgl|sgv|sgu|sgr|hg|rg)="[^"]*")[^<>]*/>', "", svg)
        svg = re.sub(r'\b(fill|stroke|stop-color)="(?!none)[^"]*"', r'\1="#111"', svg)
        svg = re.sub(r'\b(opacity|fill-opacity|stroke-opacity)="[^"]*"', "", svg)
        svg = re.sub(r'\bm="[^"]*"', 'fill="#111" stroke="#111" stroke-width="3"', svg)
        svg = re.sub(r'\bf="[^"]*"', 'fill="#111"', svg)
        return re.sub(r'\blw="[^"]*"', "", svg)

    def m_sub(mo):
        tag = mo.group(0)
        lw = re.search(r'\blw="([^"]*)"', tag)
        w = lw.group(1) if lw else str(meta.get("lw", 3))
        tag = re.sub(r'\s*\blw="[^"]*"', "", tag)
        return re.sub(r'\bm="([^"]*)"', lambda k: 'fill="%s" stroke="%s" stroke-width="%s" '
                      'stroke-linejoin="round" stroke-linecap="round"' % (_mat_ref(cid, k.group(1)), INK, w), tag)
    svg = re.sub(r'<[a-z]+[^<>]*\bm="[^"]*"[^<>]*>', m_sub, svg)
    svg = re.sub(r'\bf="([^"]*)"', lambda k: 'fill="%s"' % _mat_ref(cid, k.group(1)), svg)
    svg = re.sub(r'\bsh="(\d+)"', lambda k: 'fill="%s" opacity="%.2f"' % (SHADE, int(k.group(1)) / 100), svg)
    svg = re.sub(r'\bink="1"\s*', "", svg)
    for k, gid in (("sg", "sR"), ("sgl", "sL"), ("sgv", "sD"), ("sgu", "sU"), ("sgr", "sO"), ("hg", "hG")):
        svg = re.sub(r'\b%s="(\d+)"' % k, lambda mo, g=gid: 'fill="url(#%s)" opacity="%.2f"' % (g, int(mo.group(1)) / 100), svg)
    svg = re.sub(r'\brg="(\d+)"', lambda k: 'fill="url(#%s-rimg)" opacity="%.2f"' % (cid, int(k.group(1)) / 100), svg)
    svg = re.sub(r'\bhl="(\d+)"', lambda k: 'fill="#fff" opacity="%.2f"' % (int(k.group(1)) / 100), svg)
    svg = re.sub(r'\brim="([\d.]+)"', lambda k: 'fill="none" stroke="%s" stroke-width="%s" '
                 'stroke-linecap="round" stroke-linejoin="round" opacity="0.9"' % (rim, k.group(1)), svg)
    svg = re.sub(r'\bln="([\d.]+)"', lambda k: 'fill="none" stroke="%s" stroke-width="%s" '
                 'stroke-linecap="round" stroke-linejoin="round"' % (INK, k.group(1)), svg)
    return svg


def ground(x, y, rx, float_gap=0):
    k = 0.75 if float_gap else 1.0
    return ('<ellipse cx="%g" cy="%g" rx="%g" ry="%g" fill="url(#gshadow)" opacity="%.2f"/>'
            % (x, y, rx * k, rx * 0.16 * k, 0.85 * k))


COMMON_DEFS = ('<radialGradient id="gshadow"><stop offset="0" stop-color="#1a1222" stop-opacity="0.7"/>'
               '<stop offset="0.55" stop-color="#1a1222" stop-opacity="0.32"/>'
               '<stop offset="1" stop-color="#1a1222" stop-opacity="0"/></radialGradient>'
               '<linearGradient id="paper" x1="0" y1="0" x2="0.3" y2="1"><stop offset="0" stop-color="#f1ece4"/>'
               '<stop offset="1" stop-color="#d9d0c4"/></linearGradient>'
               + "".join('<linearGradient id="%s" x1="%g" y1="%g" x2="%g" y2="%g"><stop offset="0.3" stop-color="%s" '
                         'stop-opacity="0"/><stop offset="1" stop-color="%s"/></linearGradient>' % (g, *v, SHADE, SHADE)
                         for g, v in (("sR", (0, 0, 1, 0)), ("sL", (1, 0, 0, 0)), ("sD", (0, 0, 0, 1)), ("sU", (0, 1, 0, 0)))) +
               '<radialGradient id="sO" cx="0.42" cy="0.4" r="0.62"><stop offset="0.55" stop-color="%s" stop-opacity="0"/>'
               '<stop offset="1" stop-color="%s"/></radialGradient>' % (SHADE, SHADE) +
               '<radialGradient id="hG" cx="0.3" cy="0.25" r="0.6"><stop offset="0" stop-color="#fff"/>'
               '<stop offset="1" stop-color="#fff" stop-opacity="0"/></radialGradient>'
               '<clipPath id="bustclip"><rect x="0" y="0" width="320" height="320" rx="22"/></clipPath>')


def sheet(meta, g):
    T = Text()
    cid, acc = meta["id"], meta["accent"]
    p = ['<g id="layer-paper"><rect width="1600" height="1000" fill="url(#paper)"/>',
         '<rect x="0" y="0" width="1600" height="96" fill="%s"/>' % INK,
         '<rect x="0" y="96" width="1600" height="5" fill="%s"/></g>' % acc]
    p.append('<g id="layer-header">')
    p.append(T.run(meta["name"].upper(), 36, 68, 52, "L", "#f4efe6", spacing=0.03))
    nx = 36 + FONTS["L"].width(meta["name"].upper(), 52) + 0.03 * 52 * len(meta["name"]) + 22
    p.append(T.run("the original %s" % meta["title"], nx, 66, 26, "L", acc))
    p.append(T.run(meta["tag"], 1564, 64, 17, "R", "#b9b0c2", "end"))
    p.append("</g>")
    fl = meta.get("float", 0)
    st = meta.get("stage", ["#3a4656", "#141820"])
    wash = ('<radialGradient id="%s-stage" cx="0.5" cy="0.42" r="0.62"><stop offset="0" stop-color="%s"/>'
            '<stop offset="1" stop-color="%s"/></radialGradient>'
            '<radialGradient id="%s-pool"><stop offset="0" stop-color="%s" stop-opacity="0.35"/>'
            '<stop offset="1" stop-color="%s" stop-opacity="0"/></radialGradient>' % (cid, st[0], st[1], cid, acc, acc))
    p.append('<g id="layer-stage"><rect x="16" y="114" width="890" height="870" rx="20" fill="url(#%s-stage)"/>'
             '<ellipse cx="%d" cy="905" rx="230" ry="48" fill="url(#%s-pool)"/>'
             '<ellipse cx="%d" cy="905" rx="230" ry="48" fill="url(#%s-pool)"/></g>'
             % ((cid,) + (meta.get("pos", (215, 690))[0], cid, meta.get("pos", (215, 690))[1], cid)))
    fig = meta.get("sheet_scale", FIG)
    fx, tx = meta.get("pos", (215, 690))
    for name, x in (("front", fx), ("threequarter", tx)):
        art = g["front" if name == "front" else "tq"]
        p.append('<g id="layer-%s">%s<g transform="translate(%d 905) scale(%g)">%s</g></g>'
                 % (name, ground(x, 905, meta.get("shadow", 120) * fig, fl), x, fig, expand(art, meta)))
    p.append('<g id="layer-labels">')
    p.append(T.run("FRONT  ·  %.2f m" % (meta.get("height_cm", 180) / 100), fx, 962, 15, "L", "#9a93a6", "middle", 0.2))
    p.append(T.run("3/4", tx, 962, 15, "L", "#9a93a6", "middle", 0.2))
    p.append("</g>")
    # bust
    p.append('<g id="layer-bust" transform="translate(930 122)"><g clip-path="url(#bustclip)">'
             '<rect width="320" height="320" fill="%s"/>%s</g>'
             '<rect width="320" height="320" rx="22" fill="none" stroke="%s" stroke-width="4"/></g>'
             % (meta.get("bust_bg", "#2a2433"), expand(g["bust"], meta), INK))
    p.append(T.run("PORTRAIT", 1090, 470, 15, "L", "#6d6377", "middle", 0.2))
    # relic
    p.append('<g id="layer-relic" transform="translate(1270 122)">'
             '<rect width="300" height="320" rx="22" fill="#e9e2d7" stroke="#c9bfb2" stroke-width="2"/>%s</g>'
             % expand(g["relic"], meta))
    p.append(T.run("RELIC: %s" % meta["relic"].upper(), 1420, 470, 15, "L", "#6d6377", "middle", 0.12))
    # palette
    p.append('<g id="layer-palette">')
    sw = 640 / len(meta["palette"])
    for i, (hexc, label) in enumerate(meta["palette"]):
        x = 930 + i * sw
        p.append('<rect x="%.1f" y="496" width="%.1f" height="62" rx="6" fill="%s" stroke="%s" stroke-width="2"/>'
                 % (x + 2, sw - 6, hexc, INK))
        p.append(T.run(label, x + sw / 2 - 1, 578, 13, "R", "#4a4253", "middle"))
        p.append(T.run(hexc.upper(), x + sw / 2 - 1, 595, 11, "R", "#8a8193", "middle"))
    p.append("</g>")
    # notes
    p.append('<g id="layer-notes">')
    y = 640
    for head, body in meta["notes"]:
        p.append('<circle cx="938" cy="%d" r="5" fill="%s"/>' % (y - 6, acc))
        p.append(T.run(head, 952, y, 19, "L", INK))
        y += 25
        for line in T.wrap(body, 618, 15.5):
            p.append(T.run(line, 952, y, 15.5, "R", "#3a3342"))
            y += 21
        y += 14
    p.append("</g>")
    defs = ('<defs id="layer-defs">%s%s%s%s%s</defs>'
            % (COMMON_DEFS, wash, materials(meta), expand(g["defs"], meta), T.defs()))
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="1600" height="1000" viewBox="0 0 1600 1000">\n'
            '<title>%s, the original %s: concept sheet</title>\n%s\n%s\n</svg>\n'
            % (meta["name"], meta["title"], defs, "\n".join(p)))


def lineup(items):
    """All Wardens at one true scale over a metre scale, then the same row as black
    silhouettes (the gameplay-read test). Visual heights only: hitboxes are unchanged."""
    T = Text()
    n, sc, g1, g2 = len(items), 0.27, 352, 712
    x0 = 64
    step = (1600 - x0 - 14) / n
    p, defs = ['<rect width="1600" height="780" fill="url(#paper)"/>',
               '<rect width="1600" height="56" fill="%s"/>' % INK], [COMMON_DEFS]
    p.append(T.run("THE TWELVE WARDENS", 30, 40, 30, "L", "#f4efe6", spacing=0.04))
    p.append(T.run("true heights on one scale (art only: gameplay hitboxes are unchanged)  ·  bottom row: filled black, "
                   "the gameplay-zoom read", 1570, 38, 14, "R", "#b9b0c2", "end"))
    for ground_y in (g1, g2):
        for cm in range(0, 251, 50):
            y = ground_y - cm * UNIT * sc
            p.append('<rect x="%d" y="%.1f" width="%d" height="%g" fill="#a89d90" opacity="%s"/>'
                     % (x0 - 6, y - 0.5, 1600 - x0 - 8, 1 if cm else 2, "0.55" if cm % 100 == 0 else "0.3"))
            if ground_y == g1 or cm % 100 == 0:
                p.append(T.run("%g m" % (cm / 100), x0 - 12, y + 4, 11, "R", "#8a8193", "end"))
    for i, (meta, g) in enumerate(items):
        x = x0 + step * (i + 0.5)
        defs.append(materials(meta) + expand(g["defs"], meta))
        p.append(ground(x, g1, meta.get("shadow", 120) * sc, meta.get("float", 0)))
        p.append('<g transform="translate(%.1f %d) scale(%g)">%s</g>' % (x, g1, sc, expand(g["front"], meta)))
        p.append(T.run(meta["name"], x, g1 + 28, 15, "L", INK, "middle"))
        p.append(T.run("%s  ·  %.2f m" % (meta["title"], meta.get("height_cm", 180) / 100), x, g1 + 44, 10, "R", "#6d6377", "middle"))
        p.append('<g transform="translate(%.1f %d) scale(%g)">%s</g>'
                 % (x, g2, sc, expand(inline_uses(g["front"], g["defs"] + g["front"]), meta, silhouette=True)))
        p.append(T.run(meta["name"], x, g2 + 26, 13, "L", "#6d6377", "middle"))
    p.append('<rect x="0" y="412" width="1600" height="2" fill="#bdb3a6"/>')
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="1600" height="780" viewBox="0 0 1600 780">'
            '<defs>%s%s</defs>%s</svg>\n' % ("".join(defs), T.defs(), "\n".join(p)))


def main():
    ids = sys.argv[1:] or [c for c in ORDER if os.path.exists(os.path.join(HERE, c + ".svg.in"))]
    for cid in ids:
        meta, g = load(cid)
        open(os.path.join(OUT, cid + ".svg"), "w").write(sheet(meta, g))
    done = [c for c in ORDER if os.path.exists(os.path.join(HERE, c + ".svg.in"))]
    os.makedirs(os.path.join(HERE, "out"), exist_ok=True)
    open(os.path.join(HERE, "out", "lineup.svg"), "w").write(lineup([load(c) for c in done]))


if __name__ == "__main__":
    main()
