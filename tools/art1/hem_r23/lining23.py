# lining23.py IN.glb LINING_TEX.jpg OUT.glb [ink_y_top ink_y_bot lining_y_min] : Lace r23 skirt ink + lining.
# The r21 Meshy skirt is ONE closed thin shell (outer + inner layer, ~4 mm apart, 0 boundary edges). It had no COLOR_0, so the
# game's ink shell (outline.gdshader, cull_front) grew on every vertex: on the inner layer it shows black wherever the layers
# touch or cross (the held-Idle "black diamonds") and on the thin fray tips (the "black shredded hem").
# 1. skirt-meshy gets COLOR_0 (rgb 1 = unused by hero_toon, alpha = ink room): inner-layer verts 0, outer verts 1 above
#    ink_y_top fading to 0 at ink_y_bot (the fray band).
# 2. the inner-layer faces move to their own primitive (same vertex accessors) with material "skirt-lining23" whose base
#    colour is LINING_TEX (a deep wine copy of the skirt texture, as the turnaround's lining): the inside no longer reads hot pink.
#    Inner faces below lining_y_min (the thin fray strands) stay on the skirt texture, so the hem tips match both sides.
# Every other prim, clip, skin and texture stays byte-identical. Run hem_r21/repack.py after.
import sys, copy, numpy as np
sys.path.insert(0, 'tools/art1/hem_r17'); import glbio
src, ltex, out = sys.argv[1:4]
yt, yb = (float(sys.argv[4]), float(sys.argv[5])) if len(sys.argv) > 5 else (0.52, 0.44)
yl = float(sys.argv[6]) if len(sys.argv) > 6 else 0.0  # inner faces below this (the fray strands) keep the skirt texture
j, b = glbio.load(src)
mesh = next(me for me in j['meshes'] for p in me['primitives'] if j['materials'][p['material']]['name'] == 'skirt-meshy')
p = next(p for p in mesh['primitives'] if j['materials'][p['material']]['name'] == 'skirt-meshy')
P = glbio.acc(j, b, p['attributes']['POSITION']).astype(float); N = glbio.acc(j, b, p['attributes']['NORMAL']).astype(float)
F = glbio.acc(j, b, p['indices']).reshape(-1, 3).astype(np.int64)
c = P[P[:, 1] > 0.9][:, [0, 2]].mean(0)  # hip axis (x, z) from the waist ring
rad = np.c_[P[:, 0] - c[0], np.zeros(len(P)), P[:, 2] - c[1]]; rad /= np.linalg.norm(rad, axis=1, keepdims=True) + 1e-9
vin = (N * rad).sum(1) < 0  # vertex normal points at the axis: inner layer
fn = np.cross(P[F[:, 1]] - P[F[:, 0]], P[F[:, 2]] - P[F[:, 0]]); fc = P[F].mean(1)
fr = np.c_[fc[:, 0] - c[0], np.zeros(len(F)), fc[:, 2] - c[1]]
fin = ((fn * fr).sum(1) < 0) & (fc[:, 1] >= yl)
a = np.clip((P[:, 1] - yb) / max(yt - yb, 1e-6), 0, 1); a[vin] = 0.0
col = np.c_[np.ones((len(P), 3)), a].astype(np.float32)
def add_view(data, target=None):
    global b
    b += b'\0' * ((-len(b)) % 4); v = {'buffer': 0, 'byteOffset': len(b), 'byteLength': len(data)}
    if target: v['target'] = target
    b += data; j['bufferViews'].append(v); return len(j['bufferViews']) - 1
def add_acc(arr, ct, typ, target):
    v = add_view(np.ascontiguousarray(arr).tobytes(), target)
    j['accessors'].append({'bufferView': v, 'componentType': ct, 'count': int(len(arr) if arr.ndim == 1 else arr.shape[0]), 'type': typ})
    return len(j['accessors']) - 1
b = bytearray(b)
p['attributes']['COLOR_0'] = add_acc(col, 5126, 'VEC4', 34962)
io = F[~fin].astype(np.uint32).ravel(); ii = F[fin].astype(np.uint32).ravel()
p['indices'] = add_acc(io, 5125, 'SCALAR', 34963)
m2 = copy.deepcopy(j['materials'][p['material']]); m2['name'] = 'skirt-lining23'
t2 = dict(j['textures'][m2['pbrMetallicRoughness']['baseColorTexture']['index']])
img = add_view(open(ltex, 'rb').read()); j['images'].append({'bufferView': img, 'mimeType': 'image/jpeg', 'name': 'skirt_lining23'})
t2['source'] = len(j['images']) - 1; j['textures'].append(t2)
m2['pbrMetallicRoughness']['baseColorTexture']['index'] = len(j['textures']) - 1
j['materials'].append(m2)
p2 = {'attributes': dict(p['attributes']), 'indices': add_acc(ii, 5125, 'SCALAR', 34963), 'material': len(j['materials']) - 1}
mesh['primitives'].insert(mesh['primitives'].index(p) + 1, p2)
glbio.save(out, j, b)
print('skirt verts', len(P), 'inner verts %.1f%%' % (vin.mean() * 100), 'faces outer', (~fin).sum(), 'inner', fin.sum(),
      'ink room: 0 on %.1f%% of verts' % ((a < 0.004).mean() * 100), '->', out)
