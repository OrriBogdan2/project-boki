"""Minimal TrueType outline reader: turns text into SVG glyph paths.

Godot's SVG rasterizer draws no <text>, so the sheets carry their labels as
glyph outlines (each glyph defined once in <defs>, placed with <use>).
"""
import struct


class Font:
    def __init__(self, path):
        self.b = open(path, "rb").read()
        n = struct.unpack(">H", self.b[4:6])[0]
        self.t = {}
        for i in range(n):
            tag, _, off, ln = struct.unpack(">4sIII", self.b[12 + 16 * i:28 + 16 * i])
            self.t[tag.decode()] = (off, ln)
        self.upm = self._u16("head", 18)
        long_loca = self._u16("head", 50) == 1
        nglyph = self._u16("maxp", 4)
        lo = self.t["loca"][0]
        if long_loca:
            self.loca = struct.unpack(">%dI" % (nglyph + 1), self.b[lo:lo + 4 * (nglyph + 1)])
        else:
            self.loca = [2 * v for v in struct.unpack(">%dH" % (nglyph + 1), self.b[lo:lo + 2 * (nglyph + 1)])]
        nh = self._u16("hhea", 34)
        ho = self.t["hmtx"][0]
        self.adv = [struct.unpack(">H", self.b[ho + 4 * min(g, nh - 1):ho + 4 * min(g, nh - 1) + 2])[0]
                    for g in range(nglyph)]
        self.cmap = self._cmap()

    def _u16(self, tag, off):
        o = self.t[tag][0] + off
        return struct.unpack(">H", self.b[o:o + 2])[0]

    def _cmap(self):
        base = self.t["cmap"][0]
        n = struct.unpack(">H", self.b[base + 2:base + 4])[0]
        for i in range(n):
            pid, eid, off = struct.unpack(">HHI", self.b[base + 4 + 8 * i:base + 12 + 8 * i])
            o = base + off
            if struct.unpack(">H", self.b[o:o + 2])[0] == 4 and pid in (0, 3):
                segx2 = struct.unpack(">H", self.b[o + 6:o + 8])[0]
                seg = segx2 // 2
                ends = struct.unpack(">%dH" % seg, self.b[o + 14:o + 14 + segx2])
                p = o + 16 + segx2
                starts = struct.unpack(">%dH" % seg, self.b[p:p + segx2])
                deltas = struct.unpack(">%dh" % seg, self.b[p + segx2:p + 2 * segx2])
                ro = p + 2 * segx2
                roffs = struct.unpack(">%dH" % seg, self.b[ro:ro + segx2])
                m = {}
                for s in range(seg):
                    for c in range(starts[s], min(ends[s], 0x2FFF) + 1):
                        if roffs[s] == 0:
                            g = (c + deltas[s]) & 0xFFFF
                        else:
                            a = ro + 2 * s + roffs[s] + 2 * (c - starts[s])
                            g = struct.unpack(">H", self.b[a:a + 2])[0]
                            g = (g + deltas[s]) & 0xFFFF if g else 0
                        m[c] = g
                return m
        raise ValueError("no format 4 cmap")

    def glyph(self, c):
        return self.cmap.get(ord(c), 0)

    def contours(self, g, dx=0.0, dy=0.0):
        """List of contours, each a list of (x, y, on_curve)."""
        go = self.t["glyf"][0] + self.loca[g]
        if self.loca[g] == self.loca[g + 1]:
            return []
        nc = struct.unpack(">h", self.b[go:go + 2])[0]
        p = go + 10
        if nc < 0:
            out = []
            while True:
                flags, gi = struct.unpack(">HH", self.b[p:p + 4])
                p += 4
                if flags & 1:
                    a1, a2 = struct.unpack(">hh", self.b[p:p + 4])
                    p += 4
                else:
                    a1, a2 = struct.unpack(">bb", self.b[p:p + 2])
                    p += 2
                p += 2 if flags & 8 else 4 if flags & 0x40 else 8 if flags & 0x80 else 0
                out += self.contours(gi, dx + a1, dy + a2)
                if not flags & 0x20:
                    return out
        ends = struct.unpack(">%dH" % nc, self.b[p:p + 2 * nc])
        p += 2 * nc
        il = struct.unpack(">H", self.b[p:p + 2])[0]
        p += 2 + il
        npts = ends[-1] + 1
        fl = []
        while len(fl) < npts:
            f = self.b[p]
            p += 1
            fl.append(f)
            if f & 8:
                fl += [f] * self.b[p]
                p += 1
        pts = []
        for axis, short, same in ((0, 2, 16), (1, 4, 32)):
            v, vals = 0, []
            for f in fl:
                if f & short:
                    d = self.b[p]
                    p += 1
                    v += d if f & same else -d
                elif not f & same:
                    v += struct.unpack(">h", self.b[p:p + 2])[0]
                    p += 2
                vals.append(v)
            pts.append(vals)
        out, s = [], 0
        for e in ends:
            out.append([(pts[0][i] + dx, pts[1][i] + dy, fl[i] & 1) for i in range(s, e + 1)])
            s = e + 1
        return out

    def path(self, g):
        """SVG path in font units, y flipped (baseline at 0, up is negative)."""
        d = []
        for c in self.contours(g):
            if not c:
                continue
            n = len(c)
            st = next((i for i in range(n) if c[i][2]), None)
            if st is None:
                a, b = c[0], c[1 % n]
                start = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
                st = 0
                seq = c
            else:
                start = c[st][:2]
                seq = c[st + 1:] + c[:st + 1]
            d.append("M%g %g" % (start[0], -start[1]))
            ctrl = None
            for x, y, on in seq:
                if on:
                    if ctrl:
                        d.append("Q%g %g %g %g" % (ctrl[0], -ctrl[1], x, -y))
                    else:
                        d.append("L%g %g" % (x, -y))
                    ctrl = None
                else:
                    if ctrl:
                        mx, my = (ctrl[0] + x) / 2, (ctrl[1] + y) / 2
                        d.append("Q%g %g %g %g" % (ctrl[0], -ctrl[1], mx, -my))
                    ctrl = (x, y)
            if ctrl:
                d.append("Q%g %g %g %g" % (ctrl[0], -ctrl[1], start[0], -start[1]))
            d.append("Z")
        return "".join(d)

    def width(self, s, size):
        return sum(self.adv[self.glyph(c)] for c in s) * size / self.upm
