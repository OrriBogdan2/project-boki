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
class="fx" marks glows and particles (left out of the black silhouette row).

python3 build.py [ids...]  ->  ../<id>.svg, and src/out/lineup.svg
"""
import json
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
FIG = 0.76  # sheet scale of the full-body views (lineup uses LINEUP_SCALE)
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
    for name, (lt, base, dk) in meta["mat"].items():
        stops = ('<stop offset="0" stop-color="%s"/><stop offset="0.48" stop-color="%s"/>'
                 '<stop offset="1" stop-color="%s"/>' % (lt, base, dk))
        out.append('<linearGradient id="%s-%s" x1="0.15" y1="0" x2="0.85" y2="1">%s</linearGradient>'
                   % (cid, name, stops))
        out.append('<radialGradient id="%s-%s-r" cx="0.38" cy="0.32" r="0.75">%s</radialGradient>'
                   % (cid, name, stops))
    for name, col in meta.get("glow", {}).items():
        out.append('<radialGradient id="%s-%s-g"><stop offset="0" stop-color="%s" stop-opacity="0.9"/>'
                   '<stop offset="0.35" stop-color="%s" stop-opacity="0.45"/>'
                   '<stop offset="1" stop-color="%s" stop-opacity="0"/></radialGradient>' % (cid, name, col, col, col))
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
    if silhouette:
        svg = re.sub(r'<g class="fx"[^>]*>.*?</g>', "", svg, flags=re.S)
        svg = re.sub(r'<[a-z]+[^<>]*?(class="fx"|\b(sh|hl|rim|ln)="[^"]*")[^<>]*/>', "", svg)
        svg = re.sub(r'\b(fill|stroke|stop-color)="(?!none)[^"]*"', r'\1="#111"', svg)
        svg = re.sub(r'\b(opacity|fill-opacity|stroke-opacity)="[^"]*"', "", svg)
        svg = re.sub(r'\bm="[^"]*"', 'fill="#111" stroke="#111" stroke-width="3"', svg)
        svg = re.sub(r'\bf="[^"]*"', 'fill="#111"', svg)
        return re.sub(r'\blw="[^"]*"', "", svg)

    def m_sub(mo):
        tag = mo.group(0)
        lw = re.search(r'\blw="([^"]*)"', tag)
        w = lw.group(1) if lw else "3"
        tag = re.sub(r'\s*\blw="[^"]*"', "", tag)
        return re.sub(r'\bm="([^"]*)"', lambda k: 'fill="%s" stroke="%s" stroke-width="%s" '
                      'stroke-linejoin="round" stroke-linecap="round"' % (_mat_ref(cid, k.group(1)), INK, w), tag)
    svg = re.sub(r'<[a-z]+[^<>]*\bm="[^"]*"[^<>]*>', m_sub, svg)
    svg = re.sub(r'\bf="([^"]*)"', lambda k: 'fill="%s"' % _mat_ref(cid, k.group(1)), svg)
    svg = re.sub(r'\bsh="(\d+)"', lambda k: 'fill="%s" opacity="%.2f"' % (SHADE, int(k.group(1)) / 100), svg)
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
             '<ellipse cx="215" cy="905" rx="230" ry="48" fill="url(#%s-pool)"/>'
             '<ellipse cx="690" cy="905" rx="230" ry="48" fill="url(#%s-pool)"/></g>' % (cid, cid, cid))
    for name, x in (("front", 215), ("threequarter", 690)):
        art = g["front" if name == "front" else "tq"]
        p.append('<g id="layer-%s">%s<g transform="translate(%d 905) scale(%g)">%s</g></g>'
                 % (name, ground(x, 905, meta.get("shadow", 120) * FIG, fl), x, FIG, expand(art, meta)))
    p.append('<g id="layer-labels">')
    p.append(T.run("FRONT", 215, 962, 15, "L", "#9a93a6", "middle", 0.2))
    p.append(T.run("3/4", 690, 962, 15, "L", "#9a93a6", "middle", 0.2))
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
    T = Text()
    n, w, sc = len(items), 1600, 0.40
    step = (w - 80) / n
    p, defs = ['<rect width="1600" height="900" fill="url(#paper)"/>',
               '<rect width="1600" height="56" fill="%s"/>' % INK], [COMMON_DEFS]
    p.append(T.run("THE TWELVE WARDENS", 30, 40, 30, "L", "#f4efe6", spacing=0.04))
    p.append(T.run("same scale; bottom row: black silhouettes at gameplay read", 1570, 38, 15, "R", "#b9b0c2", "end"))
    for i, (meta, g) in enumerate(items):
        x = 40 + step * (i + 0.5)
        defs.append(materials(meta) + expand(g["defs"], meta))
        p.append(ground(x, 440, meta.get("shadow", 120) * sc, meta.get("float", 0)))
        p.append('<g transform="translate(%.1f 440) scale(%g)">%s</g>' % (x, sc, expand(g["front"], meta)))
        p.append(T.run(meta["name"], x, 476, 17, "L", INK, "middle"))
        p.append(T.run(meta["title"], x, 495, 11.5, "R", "#6d6377", "middle"))
        p.append('<g transform="translate(%.1f 830) scale(%g)">%s</g>'
                 % (x, sc, expand(g["front"], meta, silhouette=True)))
        p.append(T.run(meta["name"], x, 864, 14, "L", "#6d6377", "middle"))
    p.append('<rect x="0" y="512" width="1600" height="2" fill="#bdb3a6"/>')
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="1600" height="900" viewBox="0 0 1600 900">'
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
