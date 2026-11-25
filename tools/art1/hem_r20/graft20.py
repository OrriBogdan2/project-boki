"""graft20.py HEM_IN LEGS_GLB OUT [sh=0.75 ytop=0.93 rcut=0.115 k=8]: Lace r20 leg swap.
Meshy part B (r13/m/B, task in r13/gen_log.tsv) legs, cut crotch->boot top by legcut.py + baked by bl_bake.py, are fitted onto the
body's leg bones (piecewise height map boot top/knee/crotch, horizontal scale sh), skinned by k-nearest transfer from the body's
own leg verts, and added as prim 'leg-meshy' in Mesh_0. Removed: the body-retex thigh/knee faces they replace (crude Meshy thighs
with holes + peach knee ovals) and the r16/r18 thigh-liner prims (the white shards / flat knee discs, hem.md D1-D3)."""
import sys, io; sys.path.insert(0, __file__.rsplit('/',1)[0])
from glbio import *
from PIL import Image
from scipy.spatial import cKDTree
IN, LG, OUT = sys.argv[1:4]; O = dict(a.split('=') for a in sys.argv[4:]); F = lambda k, d: float(O.get(k, d))
j, b = load(IN); N = j['nodes']; sk = j['skins'][0]; names = [N[k]['name'] for k in sk['joints']]
IB = acc(j, b, sk['inverseBindMatrices']).reshape(-1, 4, 4)
jp = lambda nm: np.linalg.inv(IB[names.index(nm)].T)[:3, 3]
mat = lambda nm: [i for i, m in enumerate(j['materials']) if m['name'] == nm][0]
# ---- body
bp = j['meshes'][1]['primitives'][2]; A = bp['attributes']
P = acc(j, b, A['POSITION']).astype(float); J = acc(j, b, A['JOINTS_0']).astype(int); W = acc(j, b, A['WEIGHTS_0']).astype(float)
UVb = acc(j, b, A['TEXCOORD_0']); Fb = acc(j, b, bp['indices']).reshape(-1, 3).astype(np.int64)
dom = np.array(names)[J[np.arange(len(J)), W.argmax(1)]]
img = j['images'][j['textures'][j['materials'][bp['material']]['pbrMetallicRoughness']['baseColorTexture']['index']]['source']]
bv = j['bufferViews'][img['bufferView']]; tex = np.asarray(Image.open(io.BytesIO(bytes(b[bv['byteOffset']:bv['byteOffset'] + bv['byteLength']]))).convert('RGB'))
th, tw, _ = tex.shape
col = tex[np.clip(((UVb[:, 1] % 1) * th).astype(int), 0, th - 1), np.clip(((UVb[:, 0] % 1) * tw).astype(int), 0, tw - 1)].astype(float)
light = col.mean(1) > 120
def bone_line(side):
    U, L, Ft = jp(side + 'UpLeg'), jp(side + 'Leg'), jp(side + 'Foot')
    def c(y):
        y = np.asarray(y, float); t1 = np.clip((y - L[1]) / (U[1] - L[1]), 0, 1); t2 = np.clip((y - Ft[1]) / (L[1] - Ft[1]), 0, 1)
        up = L[None] + t1[:, None] * (U - L)[None]; lo = Ft[None] + t2[:, None] * (L - Ft)[None]
        return np.where((y >= L[1])[:, None], up, lo)
    return c, L[1]
drop = np.zeros(len(P), bool); YT = F('ytop', 0.93)
for side in ('Left', 'Right'):
    c, ky = bone_line(side); cc = c(P[:, 1]); r = np.hypot(P[:, 0] - cc[:, 0], P[:, 2] - cc[:, 2])
    legv = np.isin(dom, [side + 'UpLeg', side + 'Leg']) & (r < F('rcut', 0.115))
    drop |= legv & (P[:, 1] > F('yb', 0.50)) & (P[:, 1] < YT)
    drop |= legv & (P[:, 1] > F('yl', 0.44)) & (P[:, 1] <= F('yb', 0.50)) & light
fd = drop[Fb].all(1) | (drop[Fb].sum(1) >= 2)
keepF = Fb[~fd]; print('body faces dropped', int(fd.sum()), 'of', len(Fb))
ai = j['accessors'][bp['indices']]
b = replace_view(j, b, ai['bufferView'], keepF.astype(CT[ai['componentType']]).ravel().tobytes()); ai['count'] = keepF.size; ai.pop('min', None); ai.pop('max', None)
# ---- remove r16/r18 thigh-liner prims
m0 = j['meshes'][4]; before = len(m0['primitives'])
m0['primitives'] = [p for p in m0['primitives'] if j['materials'][p['material']]['name'] != 'thigh-liner']
print('Mesh_0 prims', before, '->', len(m0['primitives']))
# ---- legs
lj, lb = load(LG); lp = lj['meshes'][0]['primitives'][0]
Q = acc(lj, lb, lp['attributes']['POSITION']).astype(float); QN = acc(lj, lb, lp['attributes']['NORMAL']).astype(float)
QU = acc(lj, lb, lp['attributes']['TEXCOORD_0']); QF = acc(lj, lb, lp['indices']).reshape(-1, 3)
li = lj['images'][0]; lbv = lj['bufferViews'][li['bufferView']]; limg = bytes(lb[lbv['byteOffset']:lbv['byteOffset'] + lbv['byteLength']])
# ---- close the outer thigh: B's skirt was fused to the outer thigh, so Meshy left it open above the knee.
# Mirror each thigh's inner surface (face angle > ma deg from the outward direction) about the leg's sagittal plane.
MY, MA = F('my', -0.07), F('ma', 95)
addQ, addN, addU, addF = [Q], [QN], [QU], [QF]; nv = len(Q)
for s in (1, -1):
    m = Q[:, 0] * s > 0
    ys_ = np.arange(-0.4, 0.45, 0.02); cx_ = []
    for y in ys_:
        S = Q[m & (np.abs(Q[:, 1] - y) < 0.015)]
        cx_.append((S[:, 0].max() + S[:, 0].min()) / 2 if len(S) > 5 else np.nan)
    cx_ = np.array(cx_); ok = ~np.isnan(cx_); cx_ = np.interp(ys_, ys_[ok], cx_[ok])
    cxv = np.interp(Q[:, 1], ys_, cx_)
    czv = np.full(len(Q), np.median(Q[m & (Q[:, 1] > MY), 2]))
    a = np.degrees(np.arctan2(Q[:, 2] - czv, (Q[:, 0] - cxv) * s))
    sel = (m[QF].all(1)) & (Q[QF, 1].min(1) > MY) & (np.abs(a[QF]).min(1) > MA)
    vs = np.unique(QF[sel]); rm = -np.ones(len(Q), int); rm[vs] = np.arange(len(vs)) + nv
    V = Q[vs].copy(); V[:, 0] = 2 * cxv[vs] - V[:, 0]; Nn = QN[vs].copy(); Nn[:, 0] *= -1
    addQ.append(V); addN.append(Nn); addU.append(QU[vs]); addF.append(rm[QF[sel]][:, ::-1]); nv += len(vs)
    print('mirror side', s, 'faces', int(sel.sum()))
Q = np.vstack(addQ); QN = np.vstack(addN); QU = np.vstack(addU); QF = np.vstack(addF)
KB = [F('b_boot', -0.28), F('b_knee', -0.13), F('b_top', 0.38)]
SH = F('sh', 0.75); out = np.zeros_like(Q); outN = QN.copy()
for side, s in (('Left', 1), ('Right', -1)):
    m = Q[:, 0] * s > 0
    c, ky = bone_line(side); KL = [F('l_boot', 0.475), ky, F('l_top', 0.88)]
    yb = Q[m, 1]; y2 = np.interp(yb, KB, KL, left=None, right=None)
    lo = yb < KB[0]; y2[lo] = KL[0] + (yb[lo] - KB[0]) * (KL[1] - KL[0]) / (KB[1] - KB[0])
    hi = yb > KB[2]; y2[hi] = KL[2] + (yb[hi] - KB[2]) * (KL[2] - KL[1]) / (KB[2] - KB[1])
    # B centre line per height (bbox centre of slices, smoothed)
    ys = np.arange(Q[m, 1].min(), Q[m, 1].max() + 0.02, 0.02); cs = []
    fs_ = QF[m[QF].all(1)]; rng = np.random.default_rng(0); bw = rng.dirichlet((1, 1, 1), (len(fs_), 12))
    SP = np.einsum('fkc,fcd->fkd', bw, Q[fs_]).reshape(-1, 3)  # points spread over the faces (decimated verts are sparse)
    for y in ys:
        S = SP[np.abs(SP[:, 1] - y) < 0.01]
        cs.append((S[:, [0, 2]].max(0) + S[:, [0, 2]].min(0)) / 2 if len(S) > 5 else [np.nan, np.nan])
    cs = np.array(cs); ok = ~np.isnan(cs[:, 0])
    cs = np.stack([np.interp(ys, ys[ok], cs[ok, k]) for k in (0, 1)], 1)
    for _ in range(3): cs[1:-1] = (cs[:-2] + 2 * cs[1:-1] + cs[2:]) / 4
    cb = np.stack([np.interp(yb, ys, cs[:, 0]), np.interp(yb, ys, cs[:, 1])], 1)
    cl = c(y2)
    dx = SH * (Q[m, 0] - cb[:, 0])
    # inner-thigh limit: the other leg's bone line mirrors this one; keep the inner surface gap/2 - gin from this leg's centre
    oc, _ = bone_line('Right' if side == 'Left' else 'Left'); half = np.abs(cl[:, 0] - oc(y2)[:, 0]) / 2 - F('gin', 0.006)
    din = -dx * s; inn = din > 0
    din[inn] = half[inn] * np.tanh(din[inn] / half[inn]); dx = np.where(inn, -din * s, dx)
    out[m, 0] = cl[:, 0] + dx; out[m, 2] = cl[:, 2] + SH * (Q[m, 2] - cb[:, 1]) + F('dz', 0.0); out[m, 1] = y2
    print(side, 'B y', yb.min().round(3), yb.max().round(3), '-> body y', y2.min().round(3), y2.max().round(3))
# normals: recompute from the mapped mesh
fn = np.cross(out[QF[:, 1]] - out[QF[:, 0]], out[QF[:, 2]] - out[QF[:, 0]]); nn = np.zeros_like(out)
for k in range(3): np.add.at(nn, QF[:, k], fn)
outN = nn / np.maximum(np.linalg.norm(nn, axis=1, keepdims=True), 1e-9)
# ---- weights: k-nearest transfer from the original body leg verts (same side), before any face drop
NJ = len(names); outJ = np.zeros((len(out), 4), int); outW = np.zeros((len(out), 4))
for side, s in (('Left', 1), ('Right', -1)):
    src = np.isin(dom, [side + 'UpLeg', side + 'Leg', side + 'Foot']) & (P[:, 1] > 0.38) & (P[:, 1] < 1.0)
    T = cKDTree(P[src]); m = out[:, 0] * s > 0 if s > 0 else out[:, 0] * s >= 0
    m = np.zeros(len(out), bool); m[np.where(Q[:, 0] * s > 0)] = True
    d, ix = T.query(out[m], int(F('k', 8))); wgt = 1 / np.maximum(d, 1e-4) ** 2
    dense = np.zeros((m.sum(), NJ))
    SJ, SW = J[src][ix], W[src][ix]
    for a in range(ix.shape[1]):
        for c4 in range(4): np.add.at(dense, (np.arange(m.sum()), SJ[:, a, c4]), SW[:, a, c4] * wgt[:, a])
    other = 'Right' if side == 'Left' else 'Left'
    allowed = [k for k, nm in enumerate(names) if not nm.startswith(other)]; mask = np.zeros(NJ); mask[allowed] = 1; dense *= mask
    top = np.argsort(-dense, 1)[:, :4]; tw_ = np.take_along_axis(dense, top, 1); tw_ /= tw_.sum(1, keepdims=True)
    outJ[m] = top; outW[m] = tw_
    print(side, 'top bones', dict(zip(*np.unique(np.array(names)[top[:, 0]], return_counts=True))))
# ---- slanted thigh top: inner side ends at ytin (the thigh tops met at the crotch in walk), outer side keeps the full height
YTIN = F('ytin', 0.0)
if YTIN > 0:
    keepf = np.ones(len(QF), bool)
    for side, s in (('Left', 1), ('Right', -1)):
        c, _ = bone_line(side); lat = (out[:, 0] - c(out[:, 1])[:, 0]) * s  # >0 outward
        cut_y = YTIN + np.clip(lat + 0.02, 0, 0.06) / 0.06 * (out[:, 1].max() - YTIN)
        bad = (Q[:, 0] * s > 0) & (out[:, 1] > cut_y)
        keepf &= ~bad[QF].any(1)
    QF = QF[keepf]; print('slant top: faces dropped', int((~keepf).sum()))
# ---- knee: smooth 2-bone blend (UpLeg/Leg) over +-kb around the knee joint (the kNN weights switch sharply -> edges tear when bent)
KBW = F('kb', 0.04)
if KBW > 0:
    for side, s in (('Left', 1), ('Right', -1)):
        _, ky = bone_line(side); m = (Q[:, 0] * s > 0) & (np.abs(out[:, 1] - ky) < KBW * 1.6)
        t = np.clip((out[m, 1] - (ky - KBW)) / (2 * KBW), 0, 1); t = t * t * (3 - 2 * t)
        blend = np.clip(1.6 - np.abs(out[m, 1] - ky) / KBW, 0, 1)[:, None]  # 1 inside +-0.6kb, fades to the kNN weights by 1.6kb
        Jn = np.zeros((m.sum(), 4), int); Wn = np.zeros((m.sum(), 4))
        Jn[:, 0] = names.index(side + 'UpLeg'); Jn[:, 1] = names.index(side + 'Leg'); Wn[:, 0] = t; Wn[:, 1] = 1 - t
        dense = np.zeros((m.sum(), NJ)); rr = np.arange(m.sum())
        for c4 in range(4): np.add.at(dense, (rr, outJ[m][:, c4]), outW[m][:, c4] * (1 - blend[:, 0]))
        for c4 in range(2): np.add.at(dense, (rr, Jn[:, c4]), Wn[:, c4] * blend[:, 0])
        top = np.argsort(-dense, 1)[:, :4]; tw_ = np.take_along_axis(dense, top, 1); tw_ /= tw_.sum(1, keepdims=True)
        outJ[m] = top; outW[m] = tw_
# ---- carve: keep the legs gap cm clear of the left hand/forearm + bow in every clip frame (points in UpLeg/Leg rest space, handpts20.py)
if 'hp' in O:
    HP = dict(np.load(O['hp'])); GAP = F('gap', 0.006); domb = np.array(names)[outJ[np.arange(len(outJ)), outW.argmax(1)]]
    T_ = cKDTree(out); disp = np.zeros(len(out))
    for side in ('Left', 'Right'):
        c, ky = bone_line(side)
        for key, bn in ((side[0], side + 'UpLeg'), (side[0] + 'L', side + 'Leg')):
            vm = np.where(domb == bn)[0]
            if not len(vm): continue
            Hq = HP[key]; Hq = Hq[(Hq[:, 1] > out[vm, 1].min() - 0.02) & (Hq[:, 1] < out[vm, 1].max() + 0.02)]
            if not len(Hq): continue
            th = cKDTree(Hq); cc = c(out[vm, 1]); rad = out[vm][:, [0, 2]] - cc[:, [0, 2]]; r = np.linalg.norm(rad, axis=1)
            # how far each vert must move inward (radially) to clear the points near it
            idx = th.query_ball_point(out[vm], 0.04)
            for n_, (v, ii) in enumerate(zip(vm, idx)):
                if not ii: continue
                q = Hq[ii]; u = rad[n_] / max(r[n_], 1e-6)
                qr = (q[:, [0, 2]] - cc[n_, [0, 2]]) @ u; lat = np.linalg.norm((q[:, [0, 2]] - cc[n_, [0, 2]]) - qr[:, None] * u, axis=1)
                ok = (lat < 0.012) & (np.abs(q[:, 1] - out[v, 1]) < 0.012) & (qr > 0)
                if ok.any(): disp[v] = min(disp[v], min(0.0, qr[ok].min() - GAP - r[n_]))
    nb = T_.query(out, 16)[1]
    for _ in range(3): disp = np.minimum(disp, disp[nb].mean(1)) * 0.5 + disp[nb].mean(1) * 0.5
    print('carve: verts moved', int((disp < -0.001).sum()), 'max cm', round(-disp.min() * 100, 2))
    for side, s in (('Left', 1), ('Right', -1)):
        c, _ = bone_line(side); mm = Q[:, 0] * s > 0; cc = c(out[mm, 1]); rad = out[mm][:, [0, 2]] - cc[:, [0, 2]]
        u = rad / np.maximum(np.linalg.norm(rad, axis=1, keepdims=True), 1e-6)
        out[mm, 0] += disp[mm] * u[:, 0]; out[mm, 2] += disp[mm] * u[:, 1]
    fn = np.cross(out[QF[:, 1]] - out[QF[:, 0]], out[QF[:, 2]] - out[QF[:, 0]]); nn = np.zeros_like(out)
    for k in range(3): np.add.at(nn, QF[:, k], fn)
    outN = nn / np.maximum(np.linalg.norm(nn, axis=1, keepdims=True), 1e-9)
# ---- new prim
def addview(raw):
    global b
    off = len(b); b = b + bytearray(raw) + bytearray((-len(raw)) % 4)
    j['bufferViews'].append({'buffer': 0, 'byteOffset': off, 'byteLength': len(raw)}); return len(j['bufferViews']) - 1
def addacc(arr, ct, typ, mm=False):
    arr = np.asarray(arr); raw = np.ascontiguousarray(arr.astype(CT[ct])).tobytes(); v = addview(raw)
    d = {'bufferView': v, 'componentType': ct, 'count': len(arr) if arr.ndim > 1 else arr.size, 'type': typ}
    if mm: d['min'] = [float(x) for x in arr.min(0)]; d['max'] = [float(x) for x in arr.max(0)]
    j['accessors'].append(d); return len(j['accessors']) - 1
iv = addview(limg); j['images'].append({'bufferView': iv, 'mimeType': lj['images'][0].get('mimeType', 'image/jpeg'), 'name': 'leg20'})
j['textures'].append({'source': len(j['images']) - 1, 'sampler': j['textures'][0].get('sampler', 0)})
mt = dict(j['materials'][mat('body-retex')]); mt['name'] = 'leg-meshy'
mt['pbrMetallicRoughness'] = dict(mt['pbrMetallicRoughness']); mt['pbrMetallicRoughness']['baseColorTexture'] = {'index': len(j['textures']) - 1}
j['materials'].append(mt)
jt = j['accessors'][A['JOINTS_0']]['componentType']
m0['primitives'].append({'attributes': {'POSITION': addacc(out, 5126, 'VEC3', True), 'NORMAL': addacc(outN, 5126, 'VEC3'),
    'TEXCOORD_0': addacc(QU, 5126, 'VEC2'), 'JOINTS_0': addacc(outJ, jt, 'VEC4'), 'WEIGHTS_0': addacc(outW, 5126, 'VEC4')},
    'indices': addacc(QF.ravel(), 5125 if len(out) > 65535 else 5123, 'SCALAR'), 'material': len(j['materials']) - 1})
print('leg prim tris', len(QF), 'verts', len(out))
save(OUT, j, b)
