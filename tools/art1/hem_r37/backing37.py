"""backing37.py UNCUT.glb IN.glb OUT.glb [--cx --top --hw0 --hw1 (as slit37)] [--margin M] [--ylo Y] [--inset D]: porcelain
backing behind the upper r37 front slit.
Why: from the game camera (high, ~66 deg down) the top of the slit looks down the inside of the skirt bell and out of the open
hem between her legs: Godot r37 idle/run/attack showed a ground-green hole under the belt (r37 NEW_s3 + th1 match renders).
Her leg shell (leg-meshy) is open above the knee on the inner side, and the live thigh graft (thigh37.py) sits too far
back to block that line of sight. Blender rest-pose views never showed it.
How: the UNCUT skirtlining faces inside the slit wedge (+ margin, centroid y > ylo, front half) are copied as a new prim in
the skirt mesh, moved D m inward toward the skirt axis, with the lining's own skin weights (8 influences; so the backing stays
D behind the cloth in every pose and can never poke out) and the leg-meshy material, UVs taken from the nearest leg-meshy
vertex, so through the slit the camera sees porcelain thigh, not ground. All other prims are unchanged."""
import sys, argparse
sys.path.insert(0, __file__.rsplit('/', 2)[0] + '/hem_r17')
import numpy as np
from scipy.spatial import cKDTree
from glbio import load, acc, save, CT

ap = argparse.ArgumentParser(); ap.add_argument('uncut'); ap.add_argument('inp'); ap.add_argument('out')
ap.add_argument('--cx', type=float, default=-0.12); ap.add_argument('--top', type=float, default=0.96)
ap.add_argument('--hw0', type=float, default=0.03); ap.add_argument('--hw1', type=float, default=0.06)
ap.add_argument('--margin', type=float, default=0.02); ap.add_argument('--ylo', type=float, default=0.70)
ap.add_argument('--inset', type=float, default=0.015)
a = ap.parse_args()
ju, bu = load(a.uncut); j, b = load(a.inp); b = bytearray(b)
mat = lambda jj, p: jj['materials'][p['material']]['name']
LPu = [p for m in ju['meshes'] for p in m['primitives'] if mat(ju, p) == 'cloth-skirtlining'][0]
mi = [i for i, m in enumerate(j['meshes']) if any(mat(j, p) == 'leg-meshy' for p in m['primitives'])][0]
LEG = [p for p in j['meshes'][mi]['primitives'] if mat(j, p) == 'leg-meshy'][0]
A = {k: acc(ju, bu, v) for k, v in LPu['attributes'].items()}
P = A['POSITION'].astype(float); N = A['NORMAL'].astype(float); F = acc(ju, bu, LPu['indices']).astype(np.int64).reshape(-1, 3)
C = P[F].mean(1); y = C[:, 1]
t = np.clip((a.top - y) / (a.top - 0.30), 0, 1); hw = a.hw0 + (a.hw1 - a.hw0) * t ** 0.8
hw = np.where(y > a.top, a.hw0 * np.clip(1 - (y - a.top) / 0.03, 0, 1), hw)
sel = (C[:, 2] > 0) & (np.abs(C[:, 0] - a.cx) < hw + a.margin) & (y < a.top + 0.03 + a.margin) & (y > a.ylo)
Fs = F[sel]; used = np.unique(Fs); remap = -np.ones(len(P), np.int64); remap[used] = np.arange(len(used))
# outward = horizontal radial direction from the skirt's vertical axis (x=z=0); the lining normals are mixed in/out
rad = P[used] * np.array([1.0, 0.0, 1.0]); nrm = rad / np.linalg.norm(rad, axis=1, keepdims=True)
Q = (P[used] - a.inset * nrm).astype(np.float32)
LPOS = acc(j, b, LEG['attributes']['POSITION']).astype(float); LUV = acc(j, b, LEG['attributes']['TEXCOORD_0'])
uv = LUV[cKDTree(LPOS).query(Q)[1]]
# wind every face so its front side faces outward (radial): the lining winding is mostly inward, and Godot shades a
# back face with the flipped normal, which made the r37 bk2 backing render black in-game
Fs = remap[Fs]; fn = np.cross(Q[Fs[:, 1]] - Q[Fs[:, 0]], Q[Fs[:, 2]] - Q[Fs[:, 0]])
flip = (fn * nrm[Fs].mean(1)).sum(1) < 0; Fs[flip] = Fs[flip][:, ::-1]
print('backing: %d faces, %d verts, y %.3f..%.3f, x %.3f..%.3f, %d faces rewound' % (
    len(Fs), len(used), Q[:, 1].min(), Q[:, 1].max(), Q[:, 0].min(), Q[:, 0].max(), flip.sum()))


def addacc(arr, like):
    global b
    arr = np.ascontiguousarray(arr.astype(CT[like['componentType']])); raw = arr.tobytes()
    b += b'\0' * ((-len(b)) % 4); off = len(b); b += raw
    j['bufferViews'].append({'buffer': 0, 'byteOffset': off, 'byteLength': len(raw)})
    d = {'bufferView': len(j['bufferViews']) - 1, 'componentType': like['componentType'], 'count': len(arr), 'type': like['type']}
    if like.get('normalized'): d['normalized'] = True
    if like['type'] == 'VEC3' and arr.ndim == 2 and like is ju['accessors'][LPu['attributes']['POSITION']]:
        d['min'] = [float(v) for v in arr.min(0)]; d['max'] = [float(v) for v in arr.max(0)]
    j['accessors'].append(d); return len(j['accessors']) - 1


attrs = {}
for k, v in LPu['attributes'].items():
    if k.startswith('COLOR'): continue
    like = ju['accessors'][v]
    if k == 'POSITION': arr = Q
    elif k == 'NORMAL': arr = nrm.astype(np.float32)
    elif k == 'TEXCOORD_0': like = j['accessors'][LEG['attributes']['TEXCOORD_0']]; arr = uv
    else: arr = A[k][used]
    attrs[k] = addacc(arr, like)
ind = addacc(Fs.reshape(-1), {'componentType': 5125, 'type': 'SCALAR'})
j['meshes'][mi]['primitives'].append({'attributes': attrs, 'indices': ind, 'material': LEG['material'], 'mode': 4})
j['buffers'][0]['byteLength'] = len(b)
save(a.out, j, bytes(b)); print('backing37 ->', a.out)
