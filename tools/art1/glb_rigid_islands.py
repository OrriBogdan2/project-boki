"""Weights whole mesh islands of a .glb rigidly onto one bone, in place, with no Blender. An island is the vertices joined
by a triangle or a shared point (WardenCarry._pieces counts them the same way); one whose every vertex rides <bones> by at
least MIN and whose middle lies in the box gets all its weight on <to>. Nothing else in the file changes. For a weapon
modelled into a hand that the Boki carry must drop (WardenCarry, data "carry_drop"): it drops only a rigid piece.
Run: python3 tools/art1/glb_rigid_islands.py <glb> <to> <bone>[,<bone>...] <x0,x1,y0,y1,z0,z1> [out.glb]
  e.g. sable.glb forearm.L forearm.L,hand.L -0.5,-0.2,0.45,0.95,-0.3,0.2  (her left flintlock; glTF space, -z her front)"""
import struct
import sys

sys.path.insert(0, __file__.rsplit("/", 1)[0])
from glb_add_clips import read, write

MIN = 0.95      # of a vertex's weight on the named bones, for its island to count as riding them
FMT = {5121: "B", 5123: "H", 5125: "I", 5126: "f"}


def view(j, i):
    """(byte offset, stride, struct format, normaliser) of accessor i's elements."""
    ac = j["accessors"][i]
    bv = j["bufferViews"][ac["bufferView"]]
    f = {"SCALAR": "", "VEC3": "3", "VEC4": "4"}[ac["type"]] + FMT[ac["componentType"]]
    norm = {"B": 255.0, "H": 65535.0}[f[-1]] if ac.get("normalized") else 1.0
    return bv.get("byteOffset", 0) + ac.get("byteOffset", 0), bv.get("byteStride", struct.calcsize("<" + f)), "<" + f, norm


def rows(j, b, i):
    at, stride, fmt, norm = view(j, i)
    return [[x / norm for x in struct.unpack_from(fmt, b, at + k * stride)] for k in range(j["accessors"][i]["count"])]


def put(j, b, i, verts, value):
    at, stride, fmt, norm = view(j, i)
    packed = struct.pack(fmt, *[x if fmt[-1] == "f" else int(round(x * norm)) for x in value])
    for v in verts:
        b[at + v * stride:at + v * stride + len(packed)] = packed


def islands(pos, tris):
    up = list(range(len(pos)))

    def top(v):
        while up[v] != v:
            up[v] = up[up[v]]
            v = up[v]
        return v
    seen = {}
    for v, p in enumerate(pos):
        if tuple(p) in seen:
            up[top(v)] = top(seen[tuple(p)])
        else:
            seen[tuple(p)] = v
    for t in range(0, len(tris), 3):
        up[top(tris[t])] = top(tris[t + 1])
        up[top(tris[t])] = top(tris[t + 2])
    out = {}
    for v in range(len(pos)):
        out.setdefault(top(v), []).append(v)
    return list(out.values())


def rigid(j, b, to, bones, box):
    """Puts the islands that ride `bones` inside `box` on `to`; returns [(primitive, vertices)] per island."""
    done = []
    for node in j["nodes"]:
        if "mesh" not in node or "skin" not in node:
            continue
        joints = [j["nodes"][n]["name"] for n in j["skins"][node["skin"]]["joints"]]
        on, ride = joints.index(to), {joints.index(n) for n in bones}
        for pi, prim in enumerate(j["meshes"][node["mesh"]]["primitives"]):
            a = prim["attributes"]
            pos, js, ws = rows(j, b, a["POSITION"]), rows(j, b, a["JOINTS_0"]), rows(j, b, a["WEIGHTS_0"])
            for isl in islands(pos, [int(r[0]) for r in rows(j, b, prim["indices"])]):
                mid = [sum(pos[v][k] for v in isl) / len(isl) for k in range(3)]
                inside = all(box[2 * k] <= mid[k] <= box[2 * k + 1] for k in range(3))
                if inside and all(sum(w for jt, w in zip(js[v], ws[v]) if int(jt) in ride) >= MIN for v in isl):
                    put(j, b, a["JOINTS_0"], isl, [on, 0, 0, 0])
                    put(j, b, a["WEIGHTS_0"], isl, [1.0, 0.0, 0.0, 0.0])
                    done.append((pi, len(isl)))
    return done


if __name__ == "__main__":
    path, to_bone, names, spec = sys.argv[1:5]
    glb, binary = read(path)
    picked = rigid(glb, binary, to_bone, names.split(","), [float(x) for x in spec.split(",")])
    write(sys.argv[5] if len(sys.argv) > 5 else path, glb, binary)
    print("rigid on", to_bone, ":", len(picked), "islands,", sum(n for _, n in picked), "vertices", picked)
