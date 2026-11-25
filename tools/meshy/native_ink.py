"""Ink room and slot name for a Meshy-native body (docs/art/wardens/MESHY_NATIVE.md): the game's ink shell
(shaders/outline.gdshader, ink_mask) grows each vertex by at most its vertex colour's alpha x INK_ROOM (0.02 m).
A Meshy file has no vertex colour, so every vertex got the full line and thin parts (Grimble's goo ribbons) drew
black slabs where the shell poked through. This writes COLOR_0 = (1, 1, 1, room): half the free distance along
the vertex normal, inward or outward, as a share of FULL m (fit_warden.ink_room's rule, for a file that never
goes through Blender's export), and none where the inward ray meets nothing within SHUT m (an open, one-layer
sheet: its shell is seen from behind as a solid black slab). Blender is only used for its BVH ray casts.
--slot=NAME renames the single material to the game's painted slot (warden_glb SLOTS, warden_look "slots"),
so the Hunter's tuned per-slot look applies to the native body too ("skin-native": the skin slot's look plus
warden_look's "skin-native" overrides, which the contract model's own "skin" never sees).

  python3 tools/meshy/native_ink.py OUT.glb IN.glb [--full=0.02] [--shut=0.5] [--slot=skin-native] [--blender=PATH]
"""

import os
import subprocess
import sys
import tempfile

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import native_pack as npk

BLENDER = os.path.expanduser("~/tools/blender-4.5.15-linux-x64/blender")

RAYS = """
import sys, numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree
d = np.load(sys.argv[-2])
P, N, F, full, shut = d["P"], d["N"], d["F"], float(d["full"]), float(d["shut"])
tree = BVHTree.FromPolygons([Vector(p) for p in P], [tuple(int(i) for i in f) for f in F])
room = np.empty(len(P), np.float32)
for i in range(len(P)):
    p, n = Vector(P[i]), Vector(N[i])
    if tree.ray_cast(p - n * 1e-4, -n, shut)[0] is None:
        room[i] = 0.0  # an open sheet (a goo ribbon, a flap): no inside, the shell would show as its black back
        continue
    best = full * 2.0
    for dd in (n, -n):
        hit = tree.ray_cast(p + dd * 1e-4, dd, best)
        if hit[0] is not None:
            best = min(best, hit[3])
    room[i] = min(1.0, best * 0.5 / full)
np.save(sys.argv[-1], room)
"""


def main(args):
    opts = dict(a[2:].split("=", 1) for a in args if a.startswith("--"))
    out_path, in_path = [a for a in args if not a.startswith("--")]
    full = float(opts.get("full", "0.02"))
    js, bin_ = npk.load(in_path)
    out = npk.Out(js, bin_)
    with tempfile.TemporaryDirectory() as tmp:
        for mesh in js["meshes"]:
            for prim in mesh["primitives"]:
                pos = npk.floats(js, bin_, prim["attributes"]["POSITION"])
                nrm = npk.floats(js, bin_, prim["attributes"]["NORMAL"])
                ia = js["accessors"][prim["indices"]]
                dt = {5121: np.uint8, 5123: np.uint16, 5125: np.uint32}[ia["componentType"]]
                raw = npk.view_bytes(js, bin_, ia["bufferView"])
                idx = np.frombuffer(raw, dt, ia["count"], ia.get("byteOffset", 0)).reshape(-1, 3)
                # welded positions: a UV seam splits a vertex, and the shell must not see the seam as a gap
                key, inv = np.unique(np.round(pos, 6), axis=0, return_inverse=True)
                inv = inv.ravel()
                wn = np.zeros_like(key)
                np.add.at(wn, inv, nrm)
                wn /= np.maximum(np.linalg.norm(wn, axis=1, keepdims=True), 1e-9)
                np.savez(
                    os.path.join(tmp, "in.npz"), P=key, N=wn, F=inv[idx], full=full, shut=float(opts.get("shut", "0.5"))
                )
                script = os.path.join(tmp, "rays.py")
                open(script, "w").write(RAYS)
                subprocess.run(
                    [
                        opts.get("blender", BLENDER),
                        "-b",
                        "--factory-startup",
                        "--python",
                        script,
                        "--",
                        os.path.join(tmp, "in.npz"),
                        os.path.join(tmp, "room.npy"),
                    ],
                    check=True,
                    stdout=subprocess.DEVNULL,
                )
                room = np.load(os.path.join(tmp, "room.npy"))[inv]
                col = np.ones((len(pos), 4), np.float32)
                col[:, 3] = room
                prim["attributes"]["COLOR_0"] = out.add_floats(col, "VEC4")
                print(
                    "%s: ink room, %d%% of vertices under a full line, %d%% under half"
                    % (mesh.get("name", "mesh"), int(100 * (room < 0.999).mean()), int(100 * (room < 0.5).mean()))
                )
    if "slot" in opts:
        for m in js["materials"]:
            m["name"] = opts["slot"]
    out.write(out_path)


if __name__ == "__main__":
    main(sys.argv[1:])
