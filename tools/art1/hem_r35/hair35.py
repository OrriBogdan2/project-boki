"""hair35.py: Lace r35 long back hair (the turnaround's waist-length wavy hair; the game model has bun + nape only).
  cut   BASE.glb MESHY.glb OUTDIR [--cut Y] [--gap M]   Meshy upper-body (multi-image-to-3D of the turnaround) -> hair only:
        dark hair texels by colour (voted over the mesh), aligned to the game rest pose by a trimmed scale+shift ICP on the
        whole bust, kept below Y (overlap under the live nape hair), pushed out of the body; writes OUTDIR/hair_raw.obj
        + OUTDIR/hair_tex.jpg (Meshy hair luminance x live hair colour). Decimate with dec35.py (Blender), then:
  add   BASE.glb OUTDIR/hair_dec.obj OUTDIR/hair_tex.jpg OUT.glb   adds primitive 'hair35' to mesh 1 (raw glb edit:
        every existing byte range is kept); skin = nearest torso/neck/head vertex weights (no arm/leg joints), smoothed.
glTF space (Y up, front +Z). Every existing primitive is unchanged.
"""
import sys, io, argparse
sys.path.insert(0, __file__.rsplit('/', 2)[0] + '/hem_r17')
from glbio import *
from seg import loadhand, vcol
from PIL import Image
from scipy.spatial import cKDTree
from scipy.sparse import coo_matrix
from scipy.sparse.csgraph import connected_components

AXIAL = ['Hips', 'Spine02', 'Spine01', 'Spine', 'neck', 'Head', 'head_end', 'headfront', 'LeftShoulder', 'RightShoulder']


def prims(j, b, mesh, names=None):
    out = []
    for p in j['meshes'][mesh]['primitives']:
        mn = j['materials'][p['material']]['name']
        if names and mn not in names: continue
        A = p['attributes']
        out.append(dict(name=mn, P=acc(j, b, A['POSITION']).astype(float), N=acc(j, b, A['NORMAL']).astype(float),
                        J=acc(j, b, A['JOINTS_0']).astype(int), W=acc(j, b, A['WEIGHTS_0']).astype(float),
                        UV=acc(j, b, A['TEXCOORD_0']).astype(float), F=acc(j, b, p['indices']).reshape(-1, 3), mat=p['material']))
    return out


def image_of(j, b, mat):
    ti = j['materials'][mat]['pbrMetallicRoughness']['baseColorTexture']['index']
    bv = j['bufferViews'][j['images'][j['textures'][ti]['source']]['bufferView']]; o = bv.get('byteOffset', 0)
    return Image.open(io.BytesIO(bytes(b[o:o + bv['byteLength']]))).convert('RGB')


def hsv(c):
    mx = c.max(1); mn = c.min(1); d = mx - mn + 1e-9; r, g, bb = c[:, 0], c[:, 1], c[:, 2]
    h = np.where(mx == r, ((g - bb) / d) % 6, np.where(mx == g, (bb - r) / d + 2, (r - g) / d + 4)) / 6.0
    return h % 1.0, d / np.maximum(mx, 1e-9), mx


def vote(lab, F, it=8):
    n = len(lab); a = np.r_[F[:, 0], F[:, 1], F[:, 2], F[:, 1], F[:, 2], F[:, 0]]; c = np.r_[F[:, 1], F[:, 2], F[:, 0], F[:, 0], F[:, 1], F[:, 2]]
    deg = np.bincount(a, minlength=n) + 1.0; x = lab.astype(float)
    for _ in range(it): x = (np.bincount(a, weights=x[c], minlength=n) + x) / deg
    return x


def is_hair(c):  # dark, not red (corset/skirt/ribbons), not grey metal
    h, s, v = hsv(c / 255.0)
    red = ((h < 0.06) | (h > 0.90)) & (s > 0.45) & (v > 0.18)
    return (v < 0.34) & ~red & ~((s < 0.12) & (v > 0.25))


def live_parts(j, b):
    body = prims(j, b, 1, ['body-retex', 'head']) + prims(j, b, 2)
    P = np.vstack([p['P'] for p in body]); N = np.vstack([p['N'] for p in body])
    J = np.vstack([p['J'] for p in body]); W = np.vstack([p['W'] for p in body])
    face = prims(j, b, 2)[0]; c = vcol(image_of(j, b, face['mat']), face['UV']).astype(float)
    hair = is_hair(c) & (face['P'][:, 1] > 1.5)
    return P, N, J, W, face, c, hair


def cut(a):
    j, b = load(a.base)
    P, N, J, W, face, fc, lhair = live_parts(j, b)
    LH = face['P'][lhair]; print('live hair verts %d, y %.3f..%.3f' % (len(LH), LH[:, 1].min(), LH[:, 1].max()))
    allP = np.vstack([P] + [p['P'] for p in prims(j, b, 1, ['needles-retex'])])
    M, MN, MUV, MF, MI = loadhand(a.meshy)
    print('meshy verts %d tris %d bbox %s %s' % (len(M), len(MF), M.min(0).round(3), M.max(0).round(3)))
    # init: Meshy top (needle eyes) -> live top; height = 54% of the live top (turnaround crop rows 80..960 of a 95..1700 figure)
    top = allP[:, 1].max(); H = M[:, 1].max() - M[:, 1].min()
    s = a.frac * top / H; t = np.array([np.median(allP[allP[:, 1] > 1.0, 0]) - s * np.median(M[:, 0]), top - s * M[:, 1].max(), np.median(allP[allP[:, 1] > 1.2, 2]) - s * np.median(M[:, 2])])
    if a.fullbody:  # Meshy made the whole figure: scale = top-to-floor height ratio, ICP moves only
        s = (top - allP[:, 1].min()) / H; t = np.array([t[0], top - s * M[:, 1].max(), t[2]])
    ref = allP[allP[:, 1] > top - (top - 0.0) * 0.6]; tree = cKDTree(ref)
    sub = M[np.random.default_rng(0).choice(len(M), min(40000, len(M)), replace=False)]
    for it in range(60):
        X = s * sub + t; d, k = tree.query(X); keep = d < np.quantile(d, 0.7); Xs, Y = sub[keep], ref[k[keep]]
        mx, my = Xs.mean(0), Y.mean(0); A0 = Xs - mx
        if not a.fullbody: s = float((A0 * (Y - my)).sum() / (A0 * A0).sum())
        t = my - s * mx
    d, _ = tree.query(s * sub + t)
    print('align s %.4f t %s trimmed-70%% mean %.2f cm, median %.2f cm' % (s, t.round(3), np.sort(d)[:int(.7 * len(d))].mean() * 100, np.median(d) * 100))
    X = s * M + t
    c = vcol(MI, MUV).astype(float)
    hv = vote(is_hair(c), MF, a.vote) > a.thr
    # the black choker / lace at the throat front is not hair
    hv &= ~((X[:, 1] > 1.44) & (X[:, 1] < 1.60) & (X[:, 2] > LH[:, 2].mean() - 0.0) & (np.abs(X[:, 0] - LH[:, 0].mean()) < 0.06))
    hv &= ~((X[:, 1] < 1.50) & (X[:, 2] > a.front))  # no strands in front of the shoulders (arms swing through them)
    hv &= ~((X[:, 1] < 1.50) & (np.abs(X[:, 0] - LH[:, 0].mean()) > a.halfw - a.taper * (1.50 - X[:, 1])))  # clear of the shoulder balls/arms
    hv &= (X[:, 1] < a.cut) & (X[:, 1] > a.floor)
    hf = hv[MF].all(1)
    Fh = MF[hf]
    n = len(M); g = coo_matrix((np.ones(len(Fh) * 2), (np.r_[Fh[:, 0], Fh[:, 1]], np.r_[Fh[:, 1], Fh[:, 2]])), shape=(n, n))
    nc, lab = connected_components(g, directed=False)
    cnt = np.bincount(lab[Fh[:, 0]], minlength=nc)
    ytop = np.full(nc, -9.0); np.maximum.at(ytop, lab[Fh[:, 0]], X[Fh[:, 0], 1])
    big = np.where((cnt >= a.minpart) & (ytop > a.hang))[0]  # hair hangs from above; belt/spool shadows are low parts
    Fh = Fh[np.isin(lab[Fh[:, 0]], big)]
    print('hair faces %d in %d parts (sizes %s)' % (len(Fh), len(big), sorted(cnt[big])[::-1][:8]))
    used = np.unique(Fh); Q = X[used].copy()
    # push out of the body: nearest body vertex + its normal, keep a gap
    bt = cKDTree(P); d, k = bt.query(Q); depth = ((Q - P[k]) * N[k]).sum(1)
    if a.squeeze < 1:  # lay the hair against the back so the crossed needles stay on top of it (ref back view)
        sq = (Q[:, 1] < a.headgap_y) & (depth > a.gap); nd = np.minimum(a.gap + (depth - a.gap) * a.squeeze, a.maxdepth)
        Q[sq] -= (depth - nd)[sq][:, None] * N[k[sq]]  # needles sit 4-7 cm off the back: hair depth capped under them
        d, k = bt.query(Q); depth = ((Q - P[k]) * N[k]).sum(1)
    gap = np.where(Q[:, 1] > a.headgap_y, a.headgap, a.gap); pushed = depth < gap  # thin gap over the live head hair
    Q[pushed] += (gap - depth)[pushed][:, None] * N[k[pushed]]
    print('pushed out %d/%d verts (max %.1f cm)' % (pushed.sum(), len(Q), (gap - depth)[pushed].max() * 100 if pushed.any() else 0))
    lim = Q[:, 1] < a.cut + 0.01; zc = lim & (Q[:, 2] < a.zback); Q[zc, 2] = a.zback  # stay in front of the needle plane (z -0.135..-0.16)
    print('needle-plane clamp %d verts' % zc.sum())
    rm = -np.ones(n, int); rm[used] = np.arange(len(used)); Fo = rm[Fh]; UVo = MUV[used]
    with open(a.outdir + '/hair_raw.obj', 'w') as f:
        for p in Q: f.write('v %.6f %.6f %.6f\n' % tuple(p))
        for u in UVo: f.write('vt %.6f %.6f\n' % (u[0], 1 - u[1]))
        for t3 in Fo + 1: f.write('f %d/%d %d/%d %d/%d\n' % (t3[0], t3[0], t3[1], t3[1], t3[2], t3[2]))
    # texture: Meshy luminance x live hair colour (median of the live hair texels)
    lc = np.median(fc[lhair], 0); I = np.asarray(MI).astype(float); lum = I.mean(2, keepdims=True)
    ml = np.median(c[used].mean(1)); T = np.clip(lum / max(ml, 1) * lc, 0, 255).astype(np.uint8)
    Image.fromarray(T).resize((a.tex, a.tex), Image.LANCZOS).save(a.outdir + '/hair_tex.jpg', quality=90)
    print('live hair colour %s, meshy hair median lum %.0f; hair y %.3f..%.3f' % (lc.round(), ml, Q[:, 1].min(), Q[:, 1].max()))


def read_obj(p):
    V, T, F = [], [], []
    for ln in open(p):
        s = ln.split()
        if not s: continue
        if s[0] == 'v': V.append([float(x) for x in s[1:4]])
        elif s[0] == 'vt': T.append([float(x) for x in s[1:3]])
        elif s[0] == 'f':
            c = [x.split('/') for x in s[1:]]
            for k in range(1, len(c) - 1): F.append([(int(c[0][0]), int(c[0][1])), (int(c[k][0]), int(c[k][1])), (int(c[k + 1][0]), int(c[k + 1][1]))])
    V, T = np.array(V), np.array(T); keys = {}; P, UV, Fo = [], [], []
    for f in F:
        tri = []
        for vi, ti in f:
            if (vi, ti) not in keys: keys[(vi, ti)] = len(P); P.append(V[vi - 1]); UV.append([T[ti - 1][0], 1 - T[ti - 1][1]])
            tri.append(keys[(vi, ti)])
        Fo.append(tri)
    return np.array(P), np.array(UV), np.array(Fo)


def add(a):
    j, b = load(a.base); N0 = j['nodes']; sk = j['skins'][0]; names = [N0[n]['name'] for n in sk['joints']]
    P, Nn, J, W, *_ = live_parts(j, b)
    ok = np.isin(J, [names.index(n) for n in AXIAL if n in names]) | (W < 1e-4)
    src = ok.all(1); print('weight sources: %d axial-only body verts of %d' % (src.sum(), len(P)))
    Q, UV, F = read_obj(a.hair)
    # normals
    fn = np.cross(Q[F[:, 1]] - Q[F[:, 0]], Q[F[:, 2]] - Q[F[:, 0]]); QN = np.zeros_like(Q)
    for k in range(3): np.add.at(QN, F[:, k], fn)
    QN /= np.linalg.norm(QN, axis=1, keepdims=True) + 1e-12
    # weights: k nearest axial body verts, distance weighted, as a dense joint vector, then smoothed over the hair mesh
    nj = len(names); tr = cKDTree(P[src]); d, k = tr.query(Q, 8); Js, Ws = J[src][k], W[src][k]
    Wd = np.zeros((len(Q), nj)); iw = 1 / (d + 0.01)
    for m in range(8):
        for c in range(4): np.add.at(Wd, (np.arange(len(Q)), Js[:, m, c]), Ws[:, m, c] * iw[:, m])
    # shoulders -> Spine (hair hangs off the back, not the clavicles)
    for sh in ('LeftShoulder', 'RightShoulder'):
        Wd[:, names.index('Spine')] += Wd[:, names.index(sh)]; Wd[:, names.index(sh)] = 0
    # roots (top of the new hair, under the nape hair) follow the head
    yt = Q[:, 1].max(); hw = np.clip((Q[:, 1] - (yt - a.headband)) / a.headband, 0, 1)[:, None]
    Wd /= Wd.sum(1, keepdims=True); hd = np.zeros(nj); hd[names.index('Head')] = 1; Wd = (1 - hw) * Wd + hw * hd
    Wd = vote_rows(Wd, F, 6)
    order = np.argsort(-Wd, 1)[:, :4]; JJ = order; WW = np.take_along_axis(Wd, order, 1); WW /= WW.sum(1, keepdims=True)
    dom = np.bincount(JJ[:, 0], minlength=nj); print('hair dominant joints', {names[i]: int(c) for i, c in enumerate(dom) if c})
    I = Image.open(a.tex).convert('RGB'); bio = io.BytesIO(); I.save(bio, 'JPEG', quality=90)

    def addview(raw):
        nonlocal b
        off = len(b); b = b + bytearray(raw) + bytearray((-len(raw)) % 4)
        j['bufferViews'].append({'buffer': 0, 'byteOffset': off, 'byteLength': len(raw)}); return len(j['bufferViews']) - 1

    def addacc(arr, ct, typ, mm=False):
        vv = addview(np.ascontiguousarray(arr.astype(CT[ct])).tobytes())
        dd = {'bufferView': vv, 'componentType': ct, 'count': len(arr), 'type': typ}
        if mm: dd['min'] = [float(x) for x in arr.min(0)]; dd['max'] = [float(x) for x in arr.max(0)]
        j['accessors'].append(dd); return len(j['accessors']) - 1
    iv = addview(bio.getvalue()); j['images'].append({'bufferView': iv, 'mimeType': 'image/jpeg', 'name': 'hair35'})
    j['textures'].append({'source': len(j['images']) - 1, **({'sampler': j['textures'][0]['sampler']} if 'sampler' in j['textures'][0] else {})})
    hm = [m['name'] for m in j['materials']].index('body-face'); base = j['materials'][hm]
    mat = {k: v for k, v in base.items() if k not in ('normalTexture', 'occlusionTexture', 'emissiveTexture')}; mat['name'] = 'hair35'; mat['doubleSided'] = True
    mat['pbrMetallicRoughness'] = {'baseColorTexture': {'index': len(j['textures']) - 1}, 'metallicFactor': 0.0, 'roughnessFactor': a.rough}
    j['materials'].append(mat)
    jt = j['accessors'][j['meshes'][1]['primitives'][0]['attributes']['JOINTS_0']]['componentType']
    pr = {'attributes': {'POSITION': addacc(Q, 5126, 'VEC3', True), 'NORMAL': addacc(QN, 5126, 'VEC3'), 'TEXCOORD_0': addacc(UV, 5126, 'VEC2'),
                         'JOINTS_0': addacc(JJ, jt, 'VEC4'), 'WEIGHTS_0': addacc(WW, 5126, 'VEC4')},
          'indices': addacc(F.ravel(), 5125 if len(Q) > 65535 else 5123, 'SCALAR'), 'material': len(j['materials']) - 1}
    j['meshes'][1]['primitives'].append(pr)
    save(a.out, j, b); print('added hair35: %d verts %d tris -> %s' % (len(Q), len(F), a.out))


def vote_rows(X, F, it):
    n = len(X); a_ = np.r_[F[:, 0], F[:, 1], F[:, 2], F[:, 1], F[:, 2], F[:, 0]]; c = np.r_[F[:, 1], F[:, 2], F[:, 0], F[:, 0], F[:, 1], F[:, 2]]
    A = coo_matrix((np.ones(len(a_)), (a_, c)), shape=(n, n)).tocsr(); deg = np.asarray(A.sum(1)) + 1
    for _ in range(it): X = (A @ X + X) / deg
    return X


ap = argparse.ArgumentParser(); sp = ap.add_subparsers(dest='cmd')
c1 = sp.add_parser('cut'); c1.add_argument('base'); c1.add_argument('meshy'); c1.add_argument('outdir')
c1.add_argument('--cut', type=float, default=1.62); c1.add_argument('--gap', type=float, default=0.012); c1.add_argument('--frac', type=float, default=0.54)
c1.add_argument('--vote', type=int, default=8); c1.add_argument('--thr', type=float, default=0.5); c1.add_argument('--halfw', type=float, default=0.13); c1.add_argument('--zback', type=float, default=-0.128); c1.add_argument('--taper', type=float, default=0.12); c1.add_argument('--squeeze', type=float, default=0.3); c1.add_argument('--maxdepth', type=float, default=0.035); c1.add_argument('--fullbody', type=int, default=1); c1.add_argument('--front', type=float, default=0.0); c1.add_argument('--hang', type=float, default=1.25); c1.add_argument('--headgap', type=float, default=0.004); c1.add_argument('--headgap_y', type=float, default=1.50); c1.add_argument('--floor', type=float, default=1.05); c1.add_argument('--minpart', type=int, default=200); c1.add_argument('--tex', type=int, default=1024)
c2 = sp.add_parser('add'); c2.add_argument('base'); c2.add_argument('hair'); c2.add_argument('tex'); c2.add_argument('out')
c2.add_argument('--headband', type=float, default=0.08); c2.add_argument('--rough', type=float, default=0.75)
a = ap.parse_args(); {'cut': cut, 'add': add}[a.cmd](a)
