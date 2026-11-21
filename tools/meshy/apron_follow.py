# tools/meshy/apron_follow.py (job 20261120-233237-a4): IN.glb OUT.glb [Y0 Y1 MAXD]: the sash apron (cloth-v95 verts below the waist, ridden by hips/thigh/shin, not
# the arm wraps) takes the weights of the nearest new trouser-band verts (cloth-v95p), so the thighs no longer push
# through it in crouch. Full transfer below Y0, none above Y1 (the waist knot keeps the hips). In-place float weights.
import sys, json, struct, numpy as np
from scipy.spatial import cKDTree
src, dst = sys.argv[1:3]; Y0, Y1, MAXD = (map(float, sys.argv[3:6]) if len(sys.argv) > 5 else (1.0, 1.12, 0.12))
raw = bytearray(open(src, 'rb').read())
jl = struct.unpack_from('<I', raw, 12)[0]; js = json.loads(raw[20:20 + jl]); b0 = 20 + jl + 8
def acc(i):
    a = js['accessors'][i]; v = js['bufferViews'][a['bufferView']]; o = b0 + v.get('byteOffset', 0) + a.get('byteOffset', 0)
    n = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4}[a['type']]; dt = {5126: np.float32, 5121: np.uint8, 5123: np.uint16}[a['componentType']]
    assert v.get('byteStride', 0) in (0, n * np.dtype(dt).itemsize)
    return np.frombuffer(bytes(raw[o:o + a['count'] * n * np.dtype(dt).itemsize]), dt).reshape(a['count'], n).copy(), o
jn = [js['nodes'][j]['name'] for j in js['skins'][0]['joints']]; NJ = len(jn)
pr = {js['materials'][p['material']]['name']: p for m in js['meshes'] for p in m['primitives']}
def dense(p):
    P, _ = acc(p['attributes']['POSITION']); W, wo = acc(p['attributes']['WEIGHTS_0']); J, jo = acc(p['attributes']['JOINTS_0'])
    D = np.zeros((len(P), NJ)); np.add.at(D, (np.repeat(np.arange(len(P)), 4), J.ravel()), W.ravel()); return P, D, wo, jo, W.dtype, J.dtype
Pb, Db, *_ = dense(pr['cloth-v95p'])
Pa, Da, wo, jo, wdt, jdt = dense(pr['cloth-v95'])
legish = [jn.index(n) for n in jn if n == 'hips' or n.split('.')[0] in ('thigh', 'shin')]
arm = [jn.index(n) for n in jn if n.split('.')[0] in ('forearm', 'hand', 'upper_arm', 'shoulder')]
d, idx = cKDTree(Pb).query(Pa, k=6)
sel = (Pa[:, 1] < Y1) & (Pa[:, 1] > 0.55) & (Da[:, legish].sum(1) > 0.5) & (Da[:, arm].sum(1) < 0.05) & (d[:, 0] < MAXD)
w = 1.0 / np.maximum(d, 1e-3) ** 2; w /= w.sum(1, keepdims=True)
T = np.einsum('vk,vkj->vj', w, Db[idx])
t = np.clip((Y1 - Pa[:, 1]) / (Y1 - Y0), 0, 1)[:, None] * sel[:, None]
N = (1 - t) * Da + t * T
J4 = np.argsort(-N, 1)[:, :4]; W4 = np.take_along_axis(N, J4, 1); W4 /= W4.sum(1, keepdims=True)
raw[wo:wo + W4.size * 4] = W4.astype(wdt).tobytes(); raw[jo:jo + J4.size * np.dtype(jdt).itemsize] = J4.astype(jdt).tobytes()
open(dst, 'wb').write(raw)
print('apron verts', int(sel.sum()), 'of', len(Pa), '| mean change', float((np.abs(N - Da).sum(1) / 2)[sel].mean().round(3)),
      '| y', Pa[sel][:, 1].min().round(2), Pa[sel][:, 1].max().round(2), '| x', Pa[sel][:, 0].min().round(2), Pa[sel][:, 0].max().round(2))
