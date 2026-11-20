"""blender -b --python-exit-code 1 -P tools/art1/glb_ink_room.py -- IN.glb OUT.glb [FULL=0.02]: fit_warden.ink_room on an
existing glb, in place: per mesh, each vertex's room along its normal (in or out, half the gap to the same mesh,
as a fraction of FULL m) into COLOR_0's alpha (rgb kept); every other byte of the glb unchanged."""
import sys, json, struct
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree
a = sys.argv[sys.argv.index('--') + 1:]; src, out = a[0], a[1]; full = float(a[2]) if len(a) > 2 else 0.02
d = bytearray(open(src, 'rb').read()); jl = struct.unpack('<I', d[12:16])[0]; j = json.loads(d[20:20 + jl]); B0 = 20 + jl + 8
CT = {5126: np.float32, 5123: np.uint16, 5121: np.uint8, 5125: np.uint32}; NC = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4}
def acc(i):
    ac = j['accessors'][i]; bv = j['bufferViews'][ac['bufferView']]; dt = np.dtype(CT[ac['componentType']]); n = NC[ac['type']]
    off = B0 + bv.get('byteOffset', 0) + ac.get('byteOffset', 0); st = bv.get('byteStride', dt.itemsize * n)
    return ac, dt, n, off, st
def read(i):
    ac, dt, n, off, st = acc(i)
    return np.array([np.frombuffer(bytes(d[off + k * st: off + k * st + dt.itemsize * n]), dt) for k in range(ac['count'])])
for m in j['meshes']:
    prims = []
    for pr in m['primitives']:
        at = pr['attributes']; prims.append((at, read(at['POSITION']).astype(float), read(at['NORMAL']).astype(float), read(pr['indices']).reshape(-1, 3)))
    allP, allI, base = [], [], 0
    for at, P, N, I in prims:
        allP.append(P); allI.append(I + base); base += len(P)
    allP = np.concatenate(allP); allI = np.concatenate(allI)
    tree = BVHTree.FromPolygons([Vector(p) for p in allP], [tuple(int(x) for x in t) for t in allI])
    rooms = []
    for at, P, N, I in prims:
        N = N / np.maximum(np.linalg.norm(N, axis=1, keepdims=True), 1e-9)
        room = np.empty(len(P))
        for k in range(len(P)):
            v = Vector(P[k]); n = Vector(N[k]); best = full * 2.0
            for dd in (n, -n):
                hit = tree.ray_cast(v + dd * 1e-4, dd, best)
                if hit[0] is not None: best = min(best, hit[3])
            room[k] = min(1.0, best * 0.5 / full)
        ac, dt, n, off, st = acc(at['COLOR_0'])
        for k in range(len(P)):
            o = off + k * st + 3 * dt.itemsize
            val = room[k] if dt == np.float32 else round(room[k] * float(np.iinfo(dt).max))
            d[o:o + dt.itemsize] = np.array([val], dt).tobytes()
        rooms.append(room)
    room = np.concatenate(rooms)
    print('INK %s: %d verts, %d%% under a full line, median %.2f' % (m['name'], len(room), int(100 * (room < 0.999).mean()), np.median(room)))
open(out, 'wb').write(bytes(d)); print('INK wrote', out)
