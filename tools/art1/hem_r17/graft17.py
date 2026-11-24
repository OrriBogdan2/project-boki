"""graft17.py BASE HAND_D8K OUT [--sign 1|-1] [--wrap 1|0] [--scale S] [--mirror 0|1] [--wfrac F] [--tex 1024]
Lace r17: replace the live left mitten with a Meshy porcelain fist that grips the bow.
- body prim (mesh 1 prim 2): faces touching left-hand verts past the r15 wrist plane (2.5 cm above LeftHand) dropped.
- new prim in mesh 1, material 'body-hand17' (slot prefix 'body' = same toon slot as body-retex), own texture,
  every vert weight 1.0 on LeftHand. Forearm stub above the wrist ball removed; red cord wrap kept (--wrap 1, trimmed) or removed.
- placement: Meshy handle axis on the bow grip axis; roll so the hand's handle->wrist-ball direction follows the forearm;
  wrist ball centre at the LeftHand joint; the bow subtree (Bow, StringMid) is shifted so its grip centre = the handle centre.
- bow tracks: channels that target the 'Bow' mesh node (76, a clip-transplant slip) are moved to the Bow bone.
- Attack: the Bow bone's own rotation (bow tilts ~45 deg inside the hand) is moved onto LeftHand (WFRAC of it), so the bow stays in the fist.
"""
import sys, io, argparse
sys.path.insert(0, __file__.rsplit('/', 1)[0])
from glbio import *
from seg import loadhand, vcol
from PIL import Image
from scipy.spatial.transform import Rotation as Rot

ap = argparse.ArgumentParser()
ap.add_argument('base'); ap.add_argument('hand'); ap.add_argument('out')
ap.add_argument('--sign', type=float, default=1); ap.add_argument('--wrap', type=int, default=1)
ap.add_argument('--width', type=float, default=0.095, help='hand width along the grip, m')
ap.add_argument('--mirror', type=int, default=0); ap.add_argument('--wfrac', type=float, default=1.0)
ap.add_argument('--tex', type=int, default=1024); ap.add_argument('--wrapr', type=float, default=0.0, help='shrink wrap radius to this (m), 0 = keep')
ap.add_argument('--gy', type=float, default=0.93, help='grip centre height (straight section mid)')
ap.add_argument('--ball', type=float, default=0.0, help='wrist ball offset along the forearm (m, + = toward the elbow)')
a = ap.parse_args()

j, b = load(a.base); N = j['nodes']; sk = j['skins'][0]; names = [N[n]['name'] for n in sk['joints']]
IBacc = sk['inverseBindMatrices']; IB = acc(j, b, IBacc).reshape(-1, 4, 4).transpose(0, 2, 1); G = np.linalg.inv(IB)
iLH = names.index('LeftHand'); iLF = names.index('LeftForeArm'); iBow = names.index('Bow'); iSM = names.index('StringMid')
nLH = sk['joints'][iLH]; nBow = sk['joints'][iBow]; nSM = sk['joints'][iSM]
wrist = G[iLH][:3, 3]; fdir = wrist - G[iLF][:3, 3]; fdir /= np.linalg.norm(fdir)  # forearm, elbow -> wrist

# ---------- 1. drop the live left hand (r15 wrist plane)
p = j['meshes'][1]['primitives'][2]; A = p['attributes']
P = acc(j, b, A['POSITION']).astype(float); J = acc(j, b, A['JOINTS_0']); W = acc(j, b, A['WEIGHTS_0']).astype(float)
F = acc(j, b, p['indices']).reshape(-1, 3).astype(np.int64)
dom = J[np.arange(len(J)), W.argmax(1)]
L = [i for i, n in enumerate(names) if 'LeftHand' in n]
al = (P - wrist) @ fdir
cut = (np.isin(dom, L) | (dom == iLF)) & (al > -0.025)
keepF = F[~cut[F].any(1)]
print('body: dropped faces', len(F) - len(keepF))
a_idx = j['accessors'][p['indices']]
b = replace_view(j, b, a_idx['bufferView'], keepF.astype(np.uint16 if a_idx['componentType'] == 5123 else np.uint32).ravel().tobytes())
a_idx['count'] = keepF.size; a_idx.pop('min', None); a_idx.pop('max', None)
# forearm end ring (for the report)
ring = np.unique(keepF); ring = ring[(np.isin(dom[ring], L) | (dom[ring] == iLF)) & (al[ring] > -0.035)]
fend = P[ring].mean(0) if len(ring) else wrist
print('forearm end centre', fend.round(3), 'ring r %.2f cm' % (np.linalg.norm(P[ring] - fend, axis=1).mean() * 100 if len(ring) else 0))

# ---------- 2. the Meshy hand
H, HN, UV, HF, I = loadhand(a.hand); c = vcol(I, UV)
if a.mirror:
    H[:, 0] *= -1; HN[:, 0] *= -1; HF = HF[:, ::-1]
red = (c[:, 0] - c[:, 1] > 50) & (c[:, 0] - c[:, 2] > 30)
cream = (~red) & (c[:, 0] - c[:, 2] > 18) & (c.mean(1) > 140)
cq = H[red].mean(0); ax = np.linalg.svd(H[red] - cq, full_matrices=False)[2][0]
# ball: largest cream cluster near the hand (the one closest to the handle)
bc = H[cream].mean(0)
fh = bc - cq; fh -= (fh @ ax) * ax; dball = np.linalg.norm(fh); fh /= dball
aw = (H[~red] - cq) @ ax; w98 = np.ptp(np.percentile(aw[((H[~red] - cq) @ fh) < dball], [2, 98]))
s = a.width / w98
print('meshy: handle r %.3f  ball dist %.3f  hand width %.3f  -> scale %.4f (ball %.1f cm, wrap r %.1f cm)' % (
    np.median(np.linalg.norm((H[red] - cq) - np.outer((H[red] - cq) @ ax, ax), axis=1)), dball, w98, s, dball * s * 100,
    np.median(np.linalg.norm((H[red] - cq) - np.outer((H[red] - cq) @ ax, ax), axis=1)) * s * 100))
# keep: everything below the ball top (ball radius from the cream spread), red only within the trimmed length
rb = np.percentile(np.linalg.norm(H[cream] - bc, axis=1), 70)
hf = (H - cq) @ fh; ha = (H - cq) @ ax
keepv = (hf < dball + 0.55 * rb)
if a.wrap:
    half = 0.5 * w98 + 0.012 / s
    keepv &= ~red | (np.abs(ha) < half)
else:
    keepv &= ~red
kf = HF[keepv[HF].all(1)]
used = np.unique(kf); rm = -np.ones(len(H), np.int64); rm[used] = np.arange(len(used)); kf = rm[kf]
Hk = H[used]; HNk = HN[used]; UVk = UV[used]; redk = red[used]
if a.wrap and a.wrapr > 0:  # pull the wrap verts radially toward the axis
    d = Hk[redk] - cq; al_ = d @ ax; rad = d - np.outer(al_, ax); rr = np.linalg.norm(rad, axis=1, keepdims=True)
    tgt = a.wrapr / s; Hk[redk] = cq + np.outer(al_, ax) + rad / np.maximum(rr, 1e-9) * np.minimum(rr, tgt + (rr - np.median(rr)) * 0.5)
print('hand kept verts', len(Hk), 'tris', len(kf), 'wrap verts', int(redk.sum()))

# ---------- 3. placement
gP = None
pb = j['meshes'][0]['primitives'][1]; BP = acc(j, b, pb['attributes']['POSITION']).astype(float)
sel = (BP[:, 1] > 0.86) & (BP[:, 1] < 1.0); gc = BP[sel].mean(0); g = np.linalg.svd(BP[sel] - gc, full_matrices=False)[2][0]
g = g * a.sign
gc = gc + g * ((a.gy - gc[1]) / g[1])  # slide along the grip axis to the straight-section middle
ft = -fdir - (-fdir @ g) * g; ft /= np.linalg.norm(ft)  # wrist side, perpendicular to the grip
src = np.c_[ax, fh, np.cross(ax, fh)]; dst = np.c_[g, ft, np.cross(g, ft)]
Rm = dst @ src.T
print("knuckle side (meshy +z) ->", (Rm @ np.array([0, 0, 1.0])).round(2))
bend = np.degrees(np.arccos(np.clip(ft @ -fdir, -1, 1)))
target_ball = wrist - fdir * a.ball
Q = (Rm @ ((Hk - bc) * s).T).T + target_ball
QN = (Rm @ HNk.T).T; QN /= np.linalg.norm(QN, axis=1, keepdims=True)
hc = (Rm @ ((cq - bc) * s)) + target_ball  # handle centre, global
delta = hc - gc
print('grip centre', gc.round(3), 'axis', g.round(3), 'wrist bend %.0f deg' % bend, 'bow shift %.2f cm' % (np.linalg.norm(delta) * 100), delta.round(3))

# ---------- 4. new primitive
tex = I.resize((a.tex, a.tex), Image.LANCZOS); bio = io.BytesIO(); tex.save(bio, 'JPEG', quality=90)
def addview(raw):
    global b
    off = len(b); b = b + bytearray(raw) + bytearray((-len(raw)) % 4)
    j['bufferViews'].append({'buffer': 0, 'byteOffset': off, 'byteLength': len(raw)}); return len(j['bufferViews']) - 1
def addacc(arr, ct, typ, mm=False):
    raw = np.ascontiguousarray(arr.astype(CT[ct])).tobytes(); v = addview(raw)
    d = {'bufferView': v, 'componentType': ct, 'count': len(arr), 'type': typ}
    if mm: d['min'] = [float(x) for x in arr.min(0)]; d['max'] = [float(x) for x in arr.max(0)]
    j['accessors'].append(d); return len(j['accessors']) - 1
iv = addview(bio.getvalue()); j['images'].append({'bufferView': iv, 'mimeType': 'image/jpeg', 'name': 'hand17'})
j['textures'].append({'source': len(j['images']) - 1, **({'sampler': j['textures'][0]['sampler']} if 'sampler' in j['textures'][0] else {})})
body_mat = j['materials'][p['material']]
mat = {k: v for k, v in body_mat.items()}; mat['name'] = 'body-hand17'
mat['pbrMetallicRoughness'] = dict(body_mat['pbrMetallicRoughness']); mat['pbrMetallicRoughness']['baseColorTexture'] = {'index': len(j['textures']) - 1}
j['materials'].append(mat)
jt = j['accessors'][A['JOINTS_0']]['componentType']
JJ = np.zeros((len(Q), 4)); JJ[:, 0] = iLH; WW = np.zeros((len(Q), 4)); WW[:, 0] = 1
prim = {'attributes': {'POSITION': addacc(Q, 5126, 'VEC3', True), 'NORMAL': addacc(QN, 5126, 'VEC3'),
                       'TEXCOORD_0': addacc(UVk, 5126, 'VEC2'), 'JOINTS_0': addacc(JJ, jt, 'VEC4'), 'WEIGHTS_0': addacc(WW, 5126, 'VEC4')},
        'indices': addacc(kf.ravel(), 5125 if len(Q) > 65535 else 5123, 'SCALAR'), 'material': len(j['materials']) - 1}
j['meshes'][1]['primitives'].append(prim)

# ---------- 5. bow subtree shift (rest, IBMs, mesh, translation tracks)
par = {c: i for i, n in enumerate(N) for c in n.get('children', [])}
dl = np.linalg.inv(G[iLH][:3, :3]) @ delta  # in LeftHand-local
t0 = np.array(N[nBow]['translation']); N[nBow]['translation'] = [float(x) for x in t0 + dl]
T = np.eye(4); T[:3, 3] = delta
IB2 = IB.copy()
for i in (iBow, iSM): IB2[i] = np.linalg.inv(T @ G[i])
put(j, b, IBacc, IB2.transpose(0, 2, 1).reshape(-1, 16).astype(np.float32))
for pr in j['meshes'][0]['primitives']:
    X = acc(j, b, pr['attributes']['POSITION']).astype(float); put(j, b, pr['attributes']['POSITION'], (X + delta).astype(np.float32))

# ---------- 6. tracks: retarget mesh-node 'Bow' channels to the bone; fix translation; Attack tilt -> LeftHand
nBowMesh = [i for i, n in enumerate(N) if n.get('name') == 'Bow' and 'mesh' in n]
def newacc(arr, typ): return addacc(np.asarray(arr, float), 5126, typ)
r0 = Rot.from_quat(N[nBow]['rotation'])
for an in j['animations']:
    for ch in an['channels']:
        if ch['target']['node'] in nBowMesh: ch['target']['node'] = nBow
    chs = {(c['target']['node'], c['target']['path']): c for c in an['channels']}
    ct = chs.get((nBow, 'translation'))
    if ct:
        s_ = an['samplers'][ct['sampler']]; o = acc(j, b, s_['output']).astype(float); o[:] = N[nBow]['translation']  # constant bone rest (transplanted mesh-node tracks held zeros)
        an['samplers'].append({'input': s_['input'], 'output': newacc(o, 'VEC3'), 'interpolation': s_.get('interpolation', 'LINEAR')}); ct['sampler'] = len(an['samplers']) - 1
    cr = chs.get((nBow, 'rotation')); clh = chs.get((nLH, 'rotation'))
    if cr is None: continue
    sr = an['samplers'][cr['sampler']]; tq = acc(j, b, sr['input'])[:, 0]; q = acc(j, b, sr['output']).astype(float)
    dev = max(np.degrees((r0.inv() * Rot.from_quat(x)).magnitude()) for x in q)
    if dev < 1 or a.wfrac <= 0: continue
    # bow local rotation -> rest; LeftHand local gets the delta about the hand (rotation only, wrist stays)
    D = [Rot.from_quat(x) * r0.inv() for x in q]  # in LeftHand-local frame: B(t) = D(t) * r0
    sl = an['samplers'][clh['sampler']]; tl = acc(j, b, sl['input'])[:, 0]; ql = acc(j, b, sl['output']).astype(float)
    Dl = Rot.from_quat(np.array([np.r_[x.as_quat()] for x in D]))
    # resample D onto LeftHand's key times (slerp)
    from scipy.spatial.transform import Slerp
    Dts = Slerp(tq, Dl)(np.clip(tl, tq[0], tq[-1]))
    Dts = Rot.from_rotvec(Dts.as_rotvec() * a.wfrac)
    qn = (Rot.from_quat(ql) * Dts).as_quat()
    # keep quaternion hemisphere continuity
    for k in range(1, len(qn)):
        if qn[k] @ qn[k - 1] < 0: qn[k] = -qn[k]
    an['samplers'].append({'input': sl['input'], 'output': newacc(qn, 'VEC4'), 'interpolation': sl.get('interpolation', 'LINEAR')}); clh['sampler'] = len(an['samplers']) - 1
    rest = Rot.from_rotvec((Rot.from_quat(q).__class__.from_quat(q) * r0.inv()).as_rotvec() * (1 - a.wfrac)) * r0
    qb = rest.as_quat()
    for k in range(1, len(qb)):
        if qb[k] @ qb[k - 1] < 0: qb[k] = -qb[k]
    an['samplers'].append({'input': sr['input'], 'output': newacc(qb, 'VEC4'), 'interpolation': sr.get('interpolation', 'LINEAR')}); cr['sampler'] = len(an['samplers']) - 1
    print(an['name'], 'bow tilt %.0f deg moved to the wrist (x%.2f)' % (dev, a.wfrac))
save(a.out, j, b); print('saved', a.out)
