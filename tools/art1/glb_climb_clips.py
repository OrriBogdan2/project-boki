"""Keys the climb clips ('mantle', 'ledge') into a Hunter's .glb with no Blender (posekit.py needs bpy, which only some boxes have).
Poses are written as targets like posekit's: the hips lean and move, each limb segment aims along a direction given as
(pitch, out) in degrees (pitch 0 hangs down, 90 forward, 180 straight up; out spreads it sideways), the head tilts. Every key is
solved to the rig's local rotations from its rest pose; bones not driven here (hands, feet, pauldrons, skirt, face) hold the
idle clip's first pose, so a weapon or hook riding a hand stays in it. Hero tweaks are small edits on the shared keys.
Run: python3 tools/art1/glb_climb_clips.py <hero art id> [out.glb]   (hem, tarek, dredge, claire; art/wardens/<id>/<id>.glb)
Timing (content/rules/warden_anim/<id>.json "climb"): the mantle clip plays with the ledge rise up to MANTLE_RISE s (the hands
meet the lip when the body does), then runs on in time; the ledge clip hangs to LEDGE_HOLD s, then pulls up."""
import copy
import math
import struct
import sys

sys.path.insert(0, __file__.rsplit("/", 1)[0])
from glb_add_clips import read, write

FPS = 30
MANTLE_RISE = 0.28
LEDGE_HOLD = 0.30
LIMBS = {"upper_arm.L": ("forearm.L", -1), "forearm.L": ("hand.L", -1), "upper_arm.R": ("forearm.R", 1), "forearm.R": ("hand.R", 1),
         "thigh.L": ("shin.L", -1), "shin.L": ("foot.L", -1), "thigh.R": ("shin.R", 1), "shin.R": ("foot.R", 1)}
KEY_LIMB = {"uL": "upper_arm.L", "fL": "forearm.L", "uR": "upper_arm.R", "fR": "forearm.R",
            "tL": "thigh.L", "sL": "shin.L", "tR": "thigh.R", "sR": "shin.R"}
ARM_OUT = 14.0     # degrees an arm stands out of the body's line when the pose gives none


def pose(**kw):
    return kw


def keys_mantle():
    return [
        (0.00, pose(lean=8, head=18, hip=(0, 0, 0), uL=(150, 14), fL=(165, 10), uR=(150, 14), fR=(165, 10),
                    tL=(45, 3), sL=(-20, 3), tR=(-5, 3), sR=(-30, 3))),
        (0.12, pose(lean=22, head=22, hip=(0, -0.05, -0.08), uL=(70, 20), fL=(165, 12), uR=(70, 20), fR=(165, 12),
                    tL=(85, 3), sL=(-10, 3), tR=(20, 3), sR=(-40, 3))),
        (MANTLE_RISE, pose(lean=30, head=25, hip=(0, -0.02, -0.12), uL=(30, 22), fL=(5, 18), uR=(30, 22), fR=(5, 18),
                           tL=(100, 4), sL=(0, 4), tR=(30, 3), sR=(-50, 3))),
        (0.42, pose(lean=22, head=12, hip=(0, 0.05, -0.08), uL=(-5, 25), fL=(-15, 20), uR=(-5, 25), fR=(-15, 20),
                    tL=(-10, 3), sL=(-45, 3), tR=(75, 3), sR=(-15, 3))),
        (0.56, pose(lean=14, head=5, hip=(0, -0.07, -0.04), uL=(25, 40), fL=(50, 35), uR=(25, 40), fR=(50, 35),
                    tL=(-15, 3), sL=(-40, 3), tR=(35, 3), sR=(-30, 3))),
        (0.72, pose(lean=8, head=0, hip=(0, 0, 0), uL=(-25, 8), fL=(70, 5), uR=(35, 8), fR=(80, 5),
                    tL=(-30, 3), sL=(-45, 3), tR=(35, 3), sR=(-35, 3))),
    ]


def keys_ledge():
    return [
        (0.00, pose(lean=3, head=20, hip=(0, 0, 0), uL=(170, 12), fL=(175, 8), uR=(170, 12), fR=(175, 8),
                    tL=(10, 3), sL=(-20, 3), tR=(-5, 3), sR=(-15, 3))),
        (LEDGE_HOLD, pose(lean=3, head=20, hip=(0, 0.01, 0), uL=(170, 12), fL=(175, 8), uR=(170, 12), fR=(175, 8),
                          tL=(-5, 3), sL=(-25, 3), tR=(8, 3), sR=(-18, 3))),
        (0.55, pose(lean=20, head=22, hip=(0, -0.06, -0.10), uL=(110, 16), fL=(165, 12), uR=(110, 16), fR=(165, 12),
                    tL=(60, 3), sL=(-15, 3), tR=(0, 3), sR=(-30, 3))),
        (0.75, pose(lean=28, head=18, hip=(0, -0.03, -0.12), uL=(35, 20), fL=(5, 16), uR=(35, 20), fR=(5, 16),
                    tL=(95, 3), sL=(0, 3), tR=(25, 3), sR=(-45, 3))),
        (0.90, pose(lean=12, head=6, hip=(0, 0, -0.03), uL=(10, 12), fL=(45, 10), uR=(10, 12), fR=(45, 10),
                    tL=(10, 3), sL=(-20, 3), tR=(-5, 3), sR=(-15, 3))),
    ]


# per Hunter: [clip, key time, pose entries] replaced on the shared keys (lean_mul scales every lean)
TWEAKS = {
    "tarek": {"lean_mul": 0.8, "arm_out": 10},                      # Tenzo: heavy rock arms, upright, wide
    "hem": {"lean_mul": 1.15, "tuck": 8},                           # Lace: light, knees tucked higher; the bow rides her left hand
    "dredge": {"lean_mul": 0.9, "hook_arm": True},                  # Grimble: the right arm is the hook, straight, the lip takes it
    "claire": {"lean_mul": 1.0, "skate_trail": True},               # Neve: the skates trail straight behind, no heel scuffs
}


def tweak(clip, art):
    t = TWEAKS[art]
    out = copy.deepcopy(clip)
    for _, p in out:
        p["lean"] *= t["lean_mul"]
        for k in ("uL", "fL", "uR", "fR"):
            p[k] = (p[k][0], p[k][1] + t.get("arm_out", 0))
        if t.get("tuck"):
            p["tL"] = (p["tL"][0] + t["tuck"] * (p["tL"][0] > 30), p["tL"][1])
            p["tR"] = (p["tR"][0] + t["tuck"] * (p["tR"][0] > 30), p["tR"][1])
        if t.get("hook_arm"):
            p["fR"] = (p["uR"][0] + (p["fR"][0] - p["uR"][0]) * 0.35, p["fR"][1])      # (the hook arm hardly bends)
        if t.get("skate_trail"):
            p["sL"] = (p["sL"][0] * 0.5 if p["sL"][0] < 0 else p["sL"][0], p["sL"][1])
            p["sR"] = (p["sR"][0] * 0.5 if p["sR"][0] < 0 else p["sR"][0], p["sR"][1])
    return out


# ---- quaternion maths: tuples (x, y, z, w), the glTF order
def qmul(a, b):
    ax, ay, az, aw = a
    bx, by, bz, bw = b
    return (aw * bx + ax * bw + ay * bz - az * by, aw * by - ax * bz + ay * bw + az * bx,
            aw * bz + ax * by - ay * bx + az * bw, aw * bw - ax * bx - ay * by - az * bz)


def qinv(a):
    return (-a[0], -a[1], -a[2], a[3])


def qrot(q, v):
    p = qmul(qmul(q, (v[0], v[1], v[2], 0.0)), qinv(q))
    return (p[0], p[1], p[2])


def qx(deg):
    h = math.radians(deg) / 2
    return (math.sin(h), 0.0, 0.0, math.cos(h))


def qarc(a, b):
    """The shortest turn taking direction a onto direction b."""
    d = a[0] * b[0] + a[1] * b[1] + a[2] * b[2]
    c = (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])
    if d < -0.999999:
        return (1.0, 0.0, 0.0, 0.0)
    q = (c[0], c[1], c[2], 1.0 + d)
    n = math.sqrt(sum(x * x for x in q))
    return tuple(x / n for x in q)


def slerp(a, b, t):
    d = sum(x * y for x, y in zip(a, b))
    if d < 0:
        b, d = tuple(-x for x in b), -d
    if d > 0.9995:
        q = tuple(x + (y - x) * t for x, y in zip(a, b))
    else:
        th = math.acos(d)
        wa, wb = math.sin((1 - t) * th) / math.sin(th), math.sin(t * th) / math.sin(th)
        q = tuple(x * wa + y * wb for x, y in zip(a, b))
    n = math.sqrt(sum(x * x for x in q))
    return tuple(x / n for x in q)


def aim_dir(pitch, out, side):
    p, o = math.radians(pitch), math.radians(out)
    return (side * math.sin(o), -math.cos(o) * math.cos(p), -math.cos(o) * math.sin(p))


# ---- the rig
class Rig:
    def __init__(self, j, b):
        self.j, self.b = j, b
        self.nodes = j["nodes"]
        self.id = {n.get("name"): i for i, n in enumerate(self.nodes)}
        self.parent = {}
        for i, n in enumerate(self.nodes):
            for c in n.get("children", []):
                self.parent[c] = i
        self.rest_g = {}
        self.rest_p = {}
        for i in range(len(self.nodes)):
            self._rest(i)
        self.idle = self._sample_idle()

    def _rest(self, i):
        if i in self.rest_g:
            return
        n = self.nodes[i]
        q = tuple(n.get("rotation", (0, 0, 0, 1)))
        t = n.get("translation", (0, 0, 0))
        if i in self.parent:
            self._rest(self.parent[i])
            pq, pp = self.rest_g[self.parent[i]], self.rest_p[self.parent[i]]
            off = qrot(pq, t)
            self.rest_g[i], self.rest_p[i] = qmul(pq, q), (pp[0] + off[0], pp[1] + off[1], pp[2] + off[2])
        else:
            self.rest_g[i], self.rest_p[i] = q, tuple(t)

    def _read(self, ai, n):
        a = self.j["accessors"][ai]
        bv = self.j["bufferViews"][a["bufferView"]]
        off = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
        w = {"SCALAR": 1, "VEC3": 3, "VEC4": 4}[a["type"]]
        return struct.unpack("<%df" % (a["count"] * w), bytes(self.b[off:off + a["count"] * w * 4])), w

    def _sample_idle(self):
        """Every track of the idle clip at its first key: {(node, path): value}."""
        idle = next(a for a in self.j["animations"] if a["name"] == "idle")
        out = {}
        for ch in idle["channels"]:
            sm = idle["samplers"][ch["sampler"]]
            vals, w = self._read(sm["output"], 0)
            out[(ch["target"]["node"], ch["target"]["path"])] = tuple(vals[:w])
        return out

    def local(self, name, path, default):
        return self.idle.get((self.id[name], path), default)

    def solve(self, p):
        """One pose -> {(node, path): value} for the driven bones."""
        out = {}
        new_g = {}
        hips = self.id["hips"]
        hq = self.local("hips", "rotation", self.nodes[hips].get("rotation", (0, 0, 0, 1)))
        ht = self.local("hips", "translation", self.nodes[hips].get("translation", (0, 0, 0)))
        out[(hips, "translation")] = (ht[0] + p["hip"][0], ht[1] + p["hip"][1], ht[2] + p["hip"][2])
        pg = self.rest_g[self.parent[hips]] if hips in self.parent else (0, 0, 0, 1)
        lean = qx(-p["lean"])
        out[(hips, "rotation")] = qmul(qinv(pg), qmul(lean, qmul(pg, hq)))
        new_g[hips] = qmul(pg, out[(hips, "rotation")])
        i = self.id["head"]
        out[(i, "rotation")] = qmul(qinv(new_g.get(self.parent[i], self.rest_g[self.parent[i]])), qmul(qx(p["head"]), self.rest_g[i]))
        order = ["upper_arm.L", "forearm.L", "upper_arm.R", "forearm.R", "thigh.L", "shin.L", "thigh.R", "shin.R"]
        for name in order:
            i = self.id[name]
            child, side = LIMBS[name]
            key = [k for k, v in KEY_LIMB.items() if v == name][0]
            rest_dir = self._dir(i, self.id[child])
            d = aim_dir(p[key][0], p[key][1], side)
            g = qmul(qarc(rest_dir, d), self.rest_g[i])
            par_i = self.parent[i]
            par = new_g.get(par_i, self.rest_g[par_i])
            out[(i, "rotation")] = qmul(qinv(par), g)
            new_g[i] = g
        return out

    def _dir(self, a, b):
        v = tuple(self.rest_p[b][k] - self.rest_p[a][k] for k in range(3))
        n = math.sqrt(sum(x * x for x in v))
        return tuple(x / n for x in v)


def bake(rig, keys, art, name):
    """Samples the keys at FPS -> {(node, path): [values]}, with the idle's first pose on every other idle track."""
    end = keys[-1][0]
    frames = int(round(end * FPS)) + 1
    times = [f / FPS for f in range(frames)]
    tracks = {}
    for f, t in enumerate(times):
        for a in range(len(keys) - 1):
            if keys[a][0] <= t <= keys[a + 1][0] + 1e-9:
                u = (t - keys[a][0]) / (keys[a + 1][0] - keys[a][0])
                u = u * u * (3 - 2 * u)
                break
        pa, pb = keys[a][1], keys[a + 1][1]
        mix = {}
        for k in pa:
            va, vb = pa[k], pb[k]
            mix[k] = va + (vb - va) * u if isinstance(va, (int, float)) else tuple(x + (y - x) * u for x, y in zip(va, vb))
        for tgt, v in rig.solve(mix).items():
            tracks.setdefault(tgt, []).append(v)
    for tgt in tracks:
        if tgt[1] == "rotation":      # (keep the neighbours in the same hemisphere so they blend the short way)
            vs = tracks[tgt]
            for i in range(1, len(vs)):
                if sum(x * y for x, y in zip(vs[i - 1], vs[i])) < 0:
                    vs[i] = tuple(-x for x in vs[i])
    for tgt, v in rig.idle.items():
        if tgt not in tracks:
            tracks[tgt] = [v] * frames
    return times, tracks


def add_clip(j, b, name, times, tracks):
    def accessor(vals, typ, lo=None, hi=None):
        flat = [x for v in vals for x in (v if isinstance(v, tuple) else (v,))]
        b.extend(b"\0" * (-len(b) % 4))
        j["bufferViews"].append({"buffer": 0, "byteOffset": len(b), "byteLength": len(flat) * 4})
        b.extend(struct.pack("<%df" % len(flat), *flat))
        ac = {"bufferView": len(j["bufferViews"]) - 1, "componentType": 5126, "count": len(vals), "type": typ}
        if lo is not None:
            ac["min"], ac["max"] = [lo], [hi]
        j["accessors"].append(ac)
        return len(j["accessors"]) - 1

    j["animations"] = [a for a in j["animations"] if a["name"] != name]
    anim = {"name": name, "channels": [], "samplers": []}
    t_in = accessor(times, "SCALAR", times[0], times[-1])
    for (node, path), vals in sorted(tracks.items()):
        typ = {"rotation": "VEC4", "translation": "VEC3", "scale": "VEC3"}[path]
        anim["samplers"].append({"input": t_in, "output": accessor(vals, typ), "interpolation": "LINEAR"})
        anim["channels"].append({"sampler": len(anim["samplers"]) - 1, "target": {"node": node, "path": path}})
    j["animations"].append(anim)
    j["buffers"][0]["byteLength"] = len(b) + (-len(b) % 4)


def main(art, out):
    path = "art/wardens/%s/%s.glb" % (art, art)
    j, b = read(path)
    rig = Rig(j, b)
    for name, keys in (("mantle", keys_mantle()), ("ledge", keys_ledge())):
        times, tracks = bake(rig, tweak(keys, art), art, name)
        add_clip(j, b, name, times, tracks)
        print(art, name, len(times), "frames", times[-1], "s")
    write(out, j, b)


if __name__ == "__main__":
    art = sys.argv[1]
    main(art, sys.argv[2] if len(sys.argv) > 2 else "art/wardens/%s/%s.glb" % (art, art))
