"""locks37.py BASE.glb OUT.obj OUT_TEX.png [--gap G] [--seed S]: Lace r37 hair as clean wavy locks (replaces the hair35 blob).
Why: every Meshy hair cut (r35 back lock, r36 g1a, r37 g1f with front locks) remeshes into black blobs / a ruff collar at the
shoulders, and the owner said "the hair isnt right". The splash/turnaround have long wavy hair: a curtain down the back to the
waist and locks falling over the shoulders in front to the chest (her right side; her left shoulder carries the mask).
How: each lock is a Catmull-Rom path (control points relative to the torso centre x) swept with a lens cross-section
(width tapers root->tip, 1 cm thick) plus a lateral wave. Roots sit inside the head's own hair cap (hidden). Verts are pushed
off body-retex along the body normal to >= gap (several passes), so held poses do not clip. UV v runs along the lock;
the texture is near-black plum strands (live cap colour [25,24,30], splash dark plum-brown). Output: OBJ (v/vt/f) + PNG,
then hair35.py add (weights: head band + axial joints)."""
import sys, argparse
sys.path.insert(0, __file__.rsplit('/', 2)[0] + '/hem_r17')
import numpy as np
from scipy.spatial import cKDTree
from PIL import Image, ImageFilter
from glbio import load, acc

CX, ZC = -0.03, -0.005


def back_curtain(n=11):
    # r37b: needles-retex (geo_check torso.3/.4) front face is z -0.135 and the back is z -0.094..-0.107 at y 1.40-1.47:
    # the curtain lies in that 2.5 cm band (centre -0.119, 7 mm thick), deeper (-0.115) lower down where the back curves in.
    L = []
    for i in range(n):
        u = -1 + 2 * i / (n - 1); a = abs(u); lay = 0.0015 * (1 if i % 2 else -1)
        tip = 1.10 + 0.05 * a ** 1.5 + 0.015 * ((i * 7) % 3 - 1)
        pts = [(0.075 * u, 1.60, -0.090 + 0.02 * a), (0.092 * u, 1.53, -0.122), (0.108 * u, 1.47, -0.120 + lay),
               (0.122 * u, 1.40, -0.119 + lay), (0.128 * u, 1.30, -0.116 + lay), (0.120 * u, 1.20, -0.115 + lay),
               (0.105 * u, tip, -0.115 + lay)]
        L.append(dict(p=pts, w=0.024 if a < 0.95 else 0.020, ph=i * 1.7, back=True))
    return L


def side_locks():
    L = []
    # her right (-x): two locks over the shoulder, down the front to the chest (turnaround front view)
    L.append(dict(p=[(-0.085, 1.64, -0.015), (-0.105, 1.56, 0.000), (-0.108, 1.50, 0.030), (-0.102, 1.482, 0.075),
                     (-0.098, 1.45, 0.145), (-0.096, 1.40, 0.186), (-0.097, 1.34, 0.180), (-0.095, 1.28, 0.150)], w=0.020, ph=0.4))
    L.append(dict(p=[(-0.092, 1.63, -0.045), (-0.112, 1.55, -0.035), (-0.118, 1.49, -0.010), (-0.115, 1.478, 0.045),
                     (-0.112, 1.44, 0.125), (-0.110, 1.39, 0.160), (-0.108, 1.34, 0.145)], w=0.017, ph=2.1))
    # her right, behind the shoulder: joins the curtain
    L.append(dict(p=[(-0.088, 1.62, -0.075), (-0.108, 1.54, -0.090), (-0.118, 1.48, -0.112), (-0.122, 1.40, -0.119),
                     (-0.122, 1.30, -0.116), (-0.112, 1.20, -0.115)], w=0.020, ph=3.3, back=True))
    # her left (+x): short lock between neck and the mask, and one behind the shoulder
    L.append(dict(p=[(0.075, 1.64, -0.015), (0.090, 1.56, 0.000), (0.088, 1.50, 0.030), (0.082, 1.482, 0.075),
                     (0.078, 1.45, 0.135), (0.077, 1.41, 0.172)], w=0.016, ph=1.1))
    L.append(dict(p=[(0.083, 1.62, -0.075), (0.100, 1.54, -0.090), (0.110, 1.48, -0.112), (0.114, 1.40, -0.119),
                     (0.114, 1.30, -0.116), (0.104, 1.20, -0.115)], w=0.020, ph=4.2, back=True))
    return L


def catmull(P, step=0.008):
    P = np.array(P, float); P[:, 0] += CX
    Q = np.vstack([2 * P[0] - P[1], P, 2 * P[-1] - P[-2]]); out = []
    for k in range(1, len(Q) - 2):
        p0, p1, p2, p3 = Q[k - 1], Q[k], Q[k + 1], Q[k + 2]; n = max(2, int(np.linalg.norm(p2 - p1) / step))
        for t in np.linspace(0, 1, n, endpoint=False):
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3))
    out.append(Q[-2]); return np.array(out)


def sweep(lock, k, nseg=8, thick=0.005):
    if lock.get('back'): thick = 0.0035
    C = catmull(lock['p']); d = np.linalg.norm(np.diff(C, axis=0), axis=1); s = np.r_[0, np.cumsum(d)]; L = s[-1]; t = s / L
    T = np.gradient(C, axis=0); T /= np.linalg.norm(T, axis=1, keepdims=True)
    O = C - np.array([CX, 0, ZC]); O[:, 1] = 0
    O -= (O * T).sum(1, keepdims=True) * T; O /= np.linalg.norm(O, axis=1, keepdims=True) + 1e-9
    S = np.cross(T, O); S /= np.linalg.norm(S, axis=1, keepdims=True)
    wave = 0.009 * np.clip(s / 0.10, 0, 1) * np.sin(2 * np.pi * s / 0.11 + lock['ph'])
    C = C + S * wave[:, None] + (0 if lock.get('back') else O * (0.003 * np.sin(2 * np.pi * s / 0.07 + lock['ph'] * 2))[:, None])
    w = lock['w'] * np.interp(t, [0, 0.2, 0.7, 1], [0.75, 1.0, 0.8, 0.15]); th = thick * np.interp(t, [0, 0.8, 1], [1, 0.8, 0.4])
    V, UV = [], []
    for r in range(len(C)):
        for q in range(nseg + 1):
            a = 2 * np.pi * q / nseg
            V.append(C[r] + S[r] * w[r] * np.cos(a) + O[r] * th[r] * np.sin(a))
            UV.append(((k % 4) * 0.25 + 0.25 * q / nseg, t[r]))
    F = []
    for r in range(len(C) - 1):
        for q in range(nseg):
            a, b2 = r * (nseg + 1) + q, (r + 1) * (nseg + 1) + q; F += [(a, b2, a + 1), (a + 1, b2, b2 + 1)]
    tipc = len(V); V.append(C[-1]); UV.append(((k % 4) * 0.25 + 0.125, 1.0))
    r = len(C) - 1; F += [(r * (nseg + 1) + q, tipc, r * (nseg + 1) + q + 1) for q in range(nseg)]
    return np.array(V), np.array(UV), np.array(F)


def texture(path, seed):
    rng = np.random.default_rng(seed); W, H = 512, 1024
    col = rng.random(W); col = np.convolve(col, np.ones(5) / 5, 'same'); col = (col - col.min()) / (col.max() - col.min())
    st = np.tile(col, (H, 1)) + 0.15 * rng.random((H, W))
    y = np.linspace(0, 1, H)[:, None]
    sheen = np.exp(-((y - 0.22) / 0.06) ** 2) * 0.6 + np.exp(-((y - 0.55) / 0.08) ** 2) * 0.35
    base = np.array([30, 22, 28.0]); hi = np.array([92, 60, 76.0])
    m = np.clip(0.25 * st + sheen * (0.4 + 0.6 * st), 0, 1)[..., None]
    img = base * (1 - m) + hi * m
    Image.fromarray(img.clip(0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.8)).save(path)


def main():
    ap = argparse.ArgumentParser(); ap.add_argument('base'); ap.add_argument('out'); ap.add_argument('tex')
    ap.add_argument('--gap', type=float, default=0.008); ap.add_argument('--seed', type=int, default=37); ap.add_argument('--needle', type=float, default=-0.1265)
    a = ap.parse_args()
    j, b = load(a.base)
    p = [q for q in j['meshes'][1]['primitives'] if j['materials'][q['material']]['name'] == 'body-retex']
    BP = np.vstack([acc(j, b, q['attributes']['POSITION']) for q in p]).astype(float)
    BN = np.vstack([acc(j, b, q['attributes']['NORMAL']) for q in p]).astype(float)
    tr = cKDTree(BP)
    Vs, Us, Fs, n = [], [], [], 0
    for k, lk in enumerate(back_curtain() + side_locks()):
        V, U, F = sweep(lk, k); Vs.append(V); Us.append(U); Fs.append(F + n); n += len(V)
    V, U, F = np.vstack(Vs), np.vstack(Us), np.vstack(Fs)
    for it in range(6):
        d, i = tr.query(V, 4); nn = BN[i].mean(1); nn /= np.linalg.norm(nn, axis=1, keepdims=True) + 1e-9
        sd = ((V[:, None, :] - BP[i]) * nn[:, None, :]).sum(2).min(1)
        bad = (sd < a.gap) & (d[:, 0] < 0.04) & (V[:, 1] < 1.545)
        V[bad] += nn[bad] * (a.gap - sd[bad])[:, None]
        print('pass %d: pushed %d verts (worst %.2f cm)' % (it, bad.sum(), (a.gap - sd[bad]).max() * 100 if bad.any() else 0))
    nd = (V[:, 1] < 1.50) & (V[:, 2] < a.needle)  # stay in front of the needles (they are on top of the hair, ref back view)
    print('needle clamp: %d verts (worst %.2f cm)' % (nd.sum(), (a.needle - V[nd, 2]).max() * 100 if nd.any() else 0)); V[nd, 2] = a.needle
    with open(a.out, 'w') as f:
        f.write(''.join('v %.6f %.6f %.6f\n' % tuple(v) for v in V)); f.write(''.join('vt %.5f %.5f\n' % (u[0], 1 - u[1]) for u in U))
        f.write(''.join('f %d/%d %d/%d %d/%d\n' % (x + 1, x + 1, y + 1, y + 1, z + 1, z + 1) for x, y, z in F))
    texture(a.tex, a.seed)
    print('locks37: %d verts %d tris, y %.3f..%.3f -> %s' % (len(V), len(F), V[:, 1].min(), V[:, 1].max(), a.out))


main()
