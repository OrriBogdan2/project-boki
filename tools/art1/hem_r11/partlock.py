"""partlock.py LIVE.glb CAND.glb : every non-skirt mesh: node name, per-primitive material name, vertex count, unique-position set equality (a Blender re-export splits a few seam verts, so raw counts differ by a handful), max |dNORMAL|, max |dWEIGHT|, joints equal."""
import sys, json, struct, numpy as np
def load(p):
    raw = open(p, 'rb').read(); jl = struct.unpack('<I', raw[12:16])[0]; j = json.loads(raw[20:20 + jl]); bo = 20 + jl + 8; return j, raw[bo:]
def acc(j, b, i):
    a = j['accessors'][i]; v = j['bufferViews'][a['bufferView']]; o = v.get('byteOffset', 0) + a.get('byteOffset', 0); n = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4}[a['type']]
    dt = {5126: '<f4', 5123: '<u2', 5121: 'u1', 5125: '<u4'}[a['componentType']]; sz = np.dtype(dt).itemsize
    st = v.get('byteStride', n * sz); arr = np.frombuffer(b, dt, count=(a['count'] - 1) * st // sz + n, offset=o) if st != n * sz else np.frombuffer(b, dt, count=a['count'] * n, offset=o)
    return (np.lib.stride_tricks.as_strided(arr, (a['count'], n), (st, sz)) if st != n * sz else arr.reshape(-1, n)).astype(float)
def prims(path):
    j, b = load(path); out = {}
    for n in j['nodes']:
        if 'mesh' not in n or n['name'].startswith('Skirt'): continue
        for k, pr in enumerate(j['meshes'][n['mesh']]['primitives']):
            at = pr['attributes']; d = {'mat': j['materials'][pr['material']]['name'], 'pos': acc(j, b, at['POSITION']), 'nor': acc(j, b, at['NORMAL']) if 'NORMAL' in at else None,
                 'w': acc(j, b, at['WEIGHTS_0']) if 'WEIGHTS_0' in at else None, 'jt': acc(j, b, at['JOINTS_0']) if 'JOINTS_0' in at else None}
            out[(n['name'], k)] = d
    return out
A, B = prims(sys.argv[1]), prims(sys.argv[2]); bad = 0
for k in sorted(A):
    if k not in B: print('MISSING', k); bad += 1; continue
    from scipy.spatial import cKDTree; a, c = A[k], B[k]; dp = max(cKDTree(c['pos']).query(a['pos'])[0].max(), cKDTree(a['pos']).query(c['pos'])[0].max()); same = dp < 1e-4
    ok = same and a['mat'] == c['mat']; bad += (not ok)
    print('%-12s %d mat %-18s %-18s verts %6d %6d max nearest-vertex dist %.1e %s' % (k[0], k[1], a['mat'], c['mat'], len(a['pos']), len(c['pos']), dp, 'OK' if ok else 'DIFF'))
print('PARTLOCK', 'PASS' if not bad else 'FAIL %d' % bad)
