"""graft33.py BASE HAND_DEC OUT [--rig 0|1] [--scale S] [--mirror -1|0|1] [--curl F] [--tex 1024]
Lace r33: replace the RIGHT mitten fist (fused Meshy body fist, never rebuilt; r17 only did the left) with a Meshy
porcelain doll hand: open relaxed, separate fingers + thumb, wrist ball.
- body prim (material body-retex): faces with a vert dominated by RightHand* (or RightForeArm past the wrist plane,
  2.5 cm above RightHand) dropped. Run ../hem_r19/compact19.py after it (orphan verts).
- Meshy hand: wrist ball (cream) at the RightHand joint, fingers along RightHand -> RightHand_End, thumb on the
  Index1-Pinky1 side, palm medial. Chirality from the mesh (palm = side the fingertips curl to); --mirror forces it.
- --rig 0: every vert 1.0 on RightHand (rigid).
  --rig 1: fingers split into 5 connected parts (cut at a knuckle plane), matched to the 5 Mixamo finger chains;
  each vert skinned to its chain segment (blend 1 cm at the joints), palm/ball on RightHand.
- --curl F: scales the right finger-bone rotation deviations from rest in every clip (1 = clips as they are).
"""
import sys, io, argparse, itertools
sys.path.insert(0, __file__.rsplit('/', 2)[0] + '/hem_r17')
from glbio import *
from seg import loadhand, vcol
from PIL import Image
from scipy.spatial.transform import Rotation as Rot
from scipy.sparse import coo_matrix
from scipy.sparse.csgraph import connected_components

ap = argparse.ArgumentParser()
ap.add_argument('base'); ap.add_argument('hand'); ap.add_argument('out')
ap.add_argument('--rig', type=int, default=0); ap.add_argument('--scale', type=float, default=1.0)
ap.add_argument('--mirror', type=int, default=0); ap.add_argument('--curl', type=float, default=1.0)
ap.add_argument('--tex', type=int, default=1024); ap.add_argument('--ball', type=float, default=0.005)
ap.add_argument('--cutfa', type=float, default=-0.025); ap.add_argument('--bend', type=float, default=0); ap.add_argument('--spread', type=float, default=0); ap.add_argument('--knuckle', type=float, default=0.55); ap.add_argument('--tint', type=int, default=1)  # --ball <0: auto, ball top tucked into the forearm end ring
a = ap.parse_args()

j, b = load(a.base); N = j['nodes']; sk = j['skins'][0]; names = [N[n]['name'] for n in sk['joints']]
IB = acc(j, b, sk['inverseBindMatrices']).reshape(-1, 4, 4).transpose(0, 2, 1); G = np.linalg.inv(IB)
ix = names.index; pos = lambda n: G[ix(n)][:3, 3]
iRH = ix('RightHand'); wrist = pos('RightHand'); fdir = wrist - pos('RightForeArm'); fdir /= np.linalg.norm(fdir)
RHset = [i for i, n in enumerate(names) if 'RightHand' in n]

# ---------- 1. drop the fused right fist
pi = [k for k, p in enumerate(j['meshes'][1]['primitives']) if j['materials'][p['material']]['name'] == 'body-retex'][0]
p = j['meshes'][1]['primitives'][pi]; A = p['attributes']
P = acc(j, b, A['POSITION']).astype(float); J = acc(j, b, A['JOINTS_0']); W = acc(j, b, A['WEIGHTS_0']).astype(float)
F = acc(j, b, p['indices']).reshape(-1, 3).astype(np.int64)
dom = J[np.arange(len(J)), W.argmax(1)]
al = (P - wrist) @ fdir
cut = np.isin(dom, RHset) | ((dom == ix('RightForeArm')) & (al > a.cutfa))
keepF = F[~cut[F].any(1)]
print('body: dropped faces', len(F) - len(keepF))
ai = j['accessors'][p['indices']]
b = replace_view(j, b, ai['bufferView'], keepF.astype(np.uint16 if ai['componentType'] == 5123 else np.uint32).ravel().tobytes())
ai['count'] = keepF.size; ai.pop('min', None); ai.pop('max', None)
ring = np.unique(keepF); ring = ring[(dom[ring] == ix('RightForeArm')) & (al[ring] > -0.04)]
fend = P[ring].mean(0) if len(ring) else wrist
print('forearm end ring r %.2f cm, %.2f cm above the wrist' % (np.linalg.norm(P[ring] - fend, axis=1).mean() * 100, -(fend - wrist) @ fdir * 100))

# ---------- 2. the Meshy hand: ball, stub, axes
H, HN, UV, HF, I = loadhand(a.hand); c = vcol(I, UV)
# ball = density mode (mean shift) of the cream verts (porcelain is pinkish, so colour alone also hits the hand);
# hand axis u = ball -> the 10% of verts farthest from it (the fingertips; the stub is short)
from scipy.spatial import cKDTree
cream = (c[:, 0] - c[:, 2]) > 20
Qc = H[cream]; dens = np.array([len(x) for x in cKDTree(Qc).query_ball_point(Qc, 0.1)]); bc = Qc[dens.argmax()]
for _ in range(20): bc = Qc[np.linalg.norm(Qc - bc, axis=1) < 0.15].mean(0)
rb = 0.75 * np.percentile(np.linalg.norm(Qc[np.linalg.norm(Qc - bc, axis=1) < 0.2] - bc, axis=1), 80)
d = H - bc; dist = np.linalg.norm(d, axis=1)
far = dist > np.percentile(dist, 90); u = H[far].mean(0) - bc; u /= np.linalg.norm(u)
t = d @ u
L98 = np.percentile(t, 99.7)
keepv = t > -0.55 * rb  # stub beyond the ball top dropped
print('meshy: ball r %.3f, hand length %.3f, stub len %.3f, dropped stub verts %d' % (rb, L98, -t.min(), (~keepv).sum()))

# ---------- 3. finger split (connected parts past a knuckle plane)
E = np.r_[HF[:, [0, 1]], HF[:, [1, 2]], HF[:, [2, 0]]]
def parts(tk):
    m = keepv & (t > tk)
    e = E[m[E].all(1)]
    g = coo_matrix((np.ones(len(e)), (e[:, 0], e[:, 1])), shape=(len(H), len(H)))
    n, lab = connected_components(g, directed=False); lab = np.where(m, lab, -1)
    ids, cnt = np.unique(lab[lab >= 0], return_counts=True)
    big = ids[cnt > 0.01 * keepv.sum()]
    return lab, big
best = None
for f in np.arange(0.30, 0.80, 0.02):
    lab, big = parts(f * L98)
    if len(big) == 5: best = (f, lab, big); break
if best is None:
    for f in np.arange(0.30, 0.80, 0.02):
        lab, big = parts(f * L98); print('  knuckle %.2f -> %d parts' % (f, len(big)))
    if a.rig: sys.exit('no 5-finger split: fingers fused in the Meshy mesh; use --rig 0')
    fing = None
else:
    f, lab, big = best; fing = [np.where(lab == k)[0] for k in big]
    print('finger split at %.2f L: part sizes %s' % (f, [len(x) for x in fing]))

# palm frame: width axis v across the knuckles (PCA of verts in the 25-55% band, perpendicular to u)
band = keepv & (t > 0.25 * L98) & (t < 0.55 * L98)
db = d[band] - np.outer(d[band] @ u, u); v = np.linalg.svd(db - db.mean(0), full_matrices=False)[2][0]; v -= (v @ u) * u; v /= np.linalg.norm(v)
pc = H[band].mean(0)
if fing is not None:
    tmin = [np.percentile(t[x], 5) for x in fing]; ith = int(np.argmin(tmin))  # thumb: starts nearest the wrist
    thc = H[fing[ith]].mean(0)
    if (thc - pc) @ v < 0: v = -v
    others = [x for k, x in enumerate(fing) if k != ith]
    tips = np.array([H[x][np.argmax(t[x])] for x in others]); bases = np.array([H[x][np.argmin(t[x])] for x in others])
    nrm = np.cross(u, v)
    curl = ((tips - bases) @ nrm).mean()
    palm = nrm * np.sign(curl) if abs(curl) > 1e-4 else -nrm
else:
    # thumb side by skew of the band
    s_ = (db @ v); v = v if np.mean(s_ ** 3) > 0 else -v; palm = np.cross(v, u)
is_right = (palm @ np.cross(v, u)) > 0
print('meshy hand reads as', 'RIGHT' if is_right else 'LEFT', '(fingertip curl %.3f)' % (curl if fing is not None else 0))
mir = (not is_right) if a.mirror == 0 else (a.mirror == 1)
if mir:
    H = H.copy(); HN = HN.copy(); H[:, 0] *= -1; HN[:, 0] *= -1; HF = HF[:, ::-1]
    bc = bc * [-1, 1, 1]; u = u * [-1, 1, 1]; v = v * [-1, 1, 1]; palm = palm * [-1, 1, 1]; d = H - bc
    print('mirrored')
# orthonormal source frame [u, v, palm]
palm = np.cross(v, u); palm /= np.linalg.norm(palm)
if a.bend or a.spread:  # relaxed-hand pose in the rest mesh: arc the fingers toward the palm past the knuckles, fan them apart
    d = H - bc; tu, tw, tn = d @ u, d @ v, d @ palm; tk = a.knuckle * L98; m = tu > tk
    wc = np.median(tw[keepv & (tu > tk) & (tu < tk + 0.1 * L98)]); fr = (tu[m] - tk) / (L98 - tk)
    tw2 = tw.copy(); tw2[m] = tw[m] + a.spread * (tw[m] - wc) * fr
    kk = np.radians(a.bend) / (L98 - tk); R = 1 / kk if kk > 0 else 1e9; ph = (tu[m] - tk) * kk
    tu2, tn2 = tu.copy(), tn.copy(); tu2[m] = tk + (R - tn[m]) * np.sin(ph); tn2[m] = R - (R - tn[m]) * np.cos(ph)
    H = bc + np.outer(tu2, u) + np.outer(tw2, v) + np.outer(tn2, palm)
    hn = np.c_[HN @ u, HN @ v, HN @ palm]  # normals: rotate by the local arc angle
    phv = np.zeros(len(H)); phv[m] = ph; c_, s_ = np.cos(phv), np.sin(phv)
    HN = np.outer(hn[:, 0] * c_ - hn[:, 2] * s_, u) + np.outer(hn[:, 1], v) + np.outer(hn[:, 0] * s_ + hn[:, 2] * c_, palm)
    d = H - bc; t = d @ u  # L98 (scale) stays the unposed length
    print('pose: bend %.0f deg past %.2f L, spread %.2f; posed length %.3f (was %.3f)' % (a.bend, a.knuckle, a.spread, np.percentile(t[keepv], 99.7), L98))

# ---------- 4. target frame from the rest skeleton
tip = pos('RightHand_End'); ut = tip - wrist; Lt = np.linalg.norm(ut); ut /= Lt
vt = pos('RightHandIndex1') - pos('RightHandPinky1'); vt -= (vt @ ut) * ut; vt /= np.linalg.norm(vt)
pt = np.cross(vt, ut)
print('target: hand length %.3f, palm dir %s (medial = +x for the right hand)' % (Lt, pt.round(2)))
Rm = np.c_[ut, vt, pt] @ np.c_[u, v, palm].T
s = Lt / L98 * a.scale
used = np.where(keepv)[0]; kf = HF[keepv[HF].all(1)]
rm = -np.ones(len(H), np.int64); rm[used] = np.arange(len(used)); kf = rm[kf]
boff = a.ball if a.ball >= 0 else max(0.0, -(fend - wrist) @ fdir - 0.5 * rb * s)
print('ball centre %.1f cm up the forearm from the wrist' % (boff * 100))
Q = (Rm @ ((H[used] - bc) * s).T).T + wrist - fdir * boff
QN = (Rm @ HN[used].T).T; QN /= np.linalg.norm(QN, axis=1, keepdims=True)
UVk = UV[used]
print('hand kept verts %d tris %d scale %.4f (ball %.1f cm)' % (len(Q), len(kf), s, 2 * rb * s * 100))
sys.path.insert(0, __file__.rsplit('/', 3)[0] + '/anim'); from geo_check import hand_shape
hr = hand_shape(Q[np.asarray(Q @ fdir > wrist @ fdir - 0.0)], np.zeros(int((Q @ fdir > wrist @ fdir).sum()), bool)); print('geo hand_shape (new hand past the wrist): ratio %.2f sep %.2f' % (hr[0], hr[2]))

# ---------- 5. skin
JJ = np.zeros((len(Q), 4)); WW = np.zeros((len(Q), 4)); JJ[:, 0] = iRH; WW[:, 0] = 1
if a.rig:
    chains = {}
    for fn in ['Thumb', 'Index', 'Middle', 'Ring', 'Pinky']:
        cj = [ix('RightHand%s%d' % (fn, k)) for k in (1, 2, 3)]
        endn = [n for n in ('mixamorig:RightHand%s4' % fn, 'RightHand%s4' % fn) if n in names]
        endp = pos(endn[0]) if endn else (pos('RightHand_End') if fn == 'Middle' else None)
        if endp is None: endp = G[cj[2]][:3, 3] + (G[cj[2]][:3, 3] - G[cj[1]][:3, 3])
        chains[fn] = (cj, np.array([G[k][:3, 3] for k in cj] + [endp]))
    fparts = [rm[x[keepv[x]]] for x in fing]
    cen_t = [Q[x].mean(0) for x in fparts]
    fnames = list(chains)
    th = int(np.argmin([np.percentile(((Q[x] - wrist) @ ut), 5) for x in fparts]))
    rest = [k for k in range(5) if k != th]
    best_c, best_perm = 1e9, None
    for perm in itertools.permutations(['Index', 'Middle', 'Ring', 'Pinky']):
        cst = sum(np.linalg.norm(cen_t[k] - chains[fn][1][:3].mean(0)) for k, fn in zip(rest, perm))
        if cst < best_c: best_c, best_perm = cst, perm
    assign = {th: 'Thumb', **dict(zip(rest, best_perm))}
    for k, x in enumerate(fparts):
        cj, cp = chains[assign[k]]
        base = Q[x][np.argmin((Q[x] - wrist) @ ut)]
        print('  part %d -> %-6s %4d verts, base %.1f cm from the %s1 pivot' % (k, assign[k], len(x), np.linalg.norm(base - cp[0]) * 100, assign[k]))
        # map each vert to the chain by its fraction along the mesh finger (robust to pivot offsets)
        fa = Q[x] - base; fd = Q[x][np.argmax(fa @ ut)] - base
        fr = np.clip((fa @ fd) / (fd @ fd), 0, 1)
        seg_len = np.linalg.norm(np.diff(cp, axis=0), axis=1); cum = np.r_[0, np.cumsum(seg_len)] / seg_len.sum()
        for vi, r in zip(x, fr):
            k2 = min(int(np.searchsorted(cum, r, 'right') - 1), 2)
            jj, ww = [cj[k2]], [1.0]
            blend = 0.012 / seg_len.sum()
            if k2 > 0 and r - cum[k2] < blend:  # near the lower joint: blend with the parent bone
                wl = 0.5 + 0.5 * (r - cum[k2]) / blend; jj, ww = [cj[k2], cj[k2 - 1]], [wl, 1 - wl]
            elif k2 == 0 and r < blend:  # knuckle: blend with the hand
                wl = 0.5 + 0.5 * r / blend; jj, ww = [cj[0], iRH], [wl, 1 - wl]
            JJ[vi] = 0; WW[vi] = 0; JJ[vi, :len(jj)] = jj; WW[vi, :len(ww)] = ww

# ---------- 6. new primitive in the body mesh
if a.tint:  # match the porcelain of the forearm: hand texture luminance x forearm mean colour
    bi = j['images'][j['textures'][j['materials'][p['material']]['pbrMetallicRoughness']['baseColorTexture']['index']]['source']]
    bv = j['bufferViews'][bi['bufferView']]; BI = np.asarray(Image.open(io.BytesIO(bytes(b[bv.get('byteOffset', 0):bv.get('byteOffset', 0) + bv['byteLength']]))).convert('RGB')).astype(float)
    buv = acc(j, b, A['TEXCOORD_0']).astype(float); fa = np.where((dom == ix('RightForeArm')) & (al > -0.12) & (al < a.cutfa))[0]
    xy = np.clip((buv[fa] * [BI.shape[1], BI.shape[0]]).astype(int), 0, [BI.shape[1] - 1, BI.shape[0] - 1]); armc = np.median(BI[xy[:, 1], xy[:, 0]], 0)
    HI = np.asarray(I.convert('RGB')).astype(float); lum = HI.mean(2, keepdims=True)
    huv = np.clip((UV[used] * [HI.shape[1], HI.shape[0]]).astype(int), 0, [HI.shape[1] - 1, HI.shape[0] - 1]); hl = np.median(lum[huv[:, 1], huv[:, 0], 0])
    I = Image.fromarray(np.clip(lum / hl * armc, 0, 255).astype(np.uint8)); print('tint: forearm colour %s, hand median lum %.0f' % (armc.round(), hl))
tex = I.resize((a.tex, a.tex), Image.LANCZOS); bio = io.BytesIO(); tex.save(bio, 'JPEG', quality=90)
def addview(raw):
    global b
    off = len(b); b = b + bytearray(raw) + bytearray((-len(raw)) % 4)
    j['bufferViews'].append({'buffer': 0, 'byteOffset': off, 'byteLength': len(raw)}); return len(j['bufferViews']) - 1
def addacc(arr, ct, typ, mm=False):
    raw = np.ascontiguousarray(arr.astype(CT[ct])).tobytes(); vv = addview(raw)
    dd = {'bufferView': vv, 'componentType': ct, 'count': len(arr), 'type': typ}
    if mm: dd['min'] = [float(x) for x in arr.min(0)]; dd['max'] = [float(x) for x in arr.max(0)]
    j['accessors'].append(dd); return len(j['accessors']) - 1
iv = addview(bio.getvalue()); j['images'].append({'bufferView': iv, 'mimeType': 'image/jpeg', 'name': 'hand33'})
j['textures'].append({'source': len(j['images']) - 1, **({'sampler': j['textures'][0]['sampler']} if 'sampler' in j['textures'][0] else {})})
bm = j['materials'][p['material']]; mat = dict(bm); mat['name'] = 'body-hand33'
mat['pbrMetallicRoughness'] = dict(bm['pbrMetallicRoughness']); mat['pbrMetallicRoughness']['baseColorTexture'] = {'index': len(j['textures']) - 1}
j['materials'].append(mat)
jt = j['accessors'][A['JOINTS_0']]['componentType']
prim = {'attributes': {'POSITION': addacc(Q, 5126, 'VEC3', True), 'NORMAL': addacc(QN, 5126, 'VEC3'),
                       'TEXCOORD_0': addacc(UVk, 5126, 'VEC2'), 'JOINTS_0': addacc(JJ, jt, 'VEC4'), 'WEIGHTS_0': addacc(WW, 5126, 'VEC4')},
        'indices': addacc(kf.ravel(), 5125 if len(Q) > 65535 else 5123, 'SCALAR'), 'material': len(j['materials']) - 1}
j['meshes'][1]['primitives'].append(prim)

# ---------- 7. finger curl scale
if a.curl != 1.0:
    fn_nodes = set(sk['joints'][i] for i in RHset if i != iRH)
    for an in j['animations']:
        for ch in an['channels']:
            nd = ch['target']['node']
            if nd not in fn_nodes or ch['target']['path'] != 'rotation': continue
            sp = an['samplers'][ch['sampler']]; q = acc(j, b, sp['output']).astype(float)
            r0 = Rot.from_quat(N[nd].get('rotation', [0, 0, 0, 1]))
            qn = (r0 * Rot.from_rotvec((r0.inv() * Rot.from_quat(q)).as_rotvec() * a.curl)).as_quat()
            for k in range(1, len(qn)):
                if qn[k] @ qn[k - 1] < 0: qn[k] = -qn[k]
            an['samplers'].append({'input': sp['input'], 'output': addacc(qn, 5126, 'VEC4'), 'interpolation': sp.get('interpolation', 'LINEAR')})
            ch['sampler'] = len(an['samplers']) - 1
    print('right finger curl x%.2f' % a.curl)
save(a.out, j, b); print('saved', a.out)
