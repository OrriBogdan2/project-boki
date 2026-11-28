"""hairw37.py IN.glb OUT.glb [--k K] [--headband H] [--armfold 1]: Lace r37 hair weights = the body surface under the hair.
Why: hair35.py add weights the hair from axial-only body verts and folds the shoulders into Spine, so the curtain over the
upper back (body there is skinned Spine01 + Left/RightShoulder + some RightArm) got neck/Head weights and swung through the
back in run/idle (geo_check l2: hair.10-13 > torso.2 1.4-1.7 cm held). Hair lying on the back must follow the back.
How: for every hair35 vertex, inverse-distance mix of the full joint weights of the K nearest body-retex verts (the
--armfold fraction of arm/hand bone weight moved to that side's Shoulder; 1 = the hair never follows the arm); hair close to the
needles (rigid on Spine, geo_check torso.3/.4) shares their weights by relative distance (back vs needle), then the head band
(top H m of the hair -> Head, roots stay in the head's own hair cap), smoothed over the hair mesh, top 4 kept.
In-place accessor rewrite (same count/type): positions, UVs, indices untouched."""
import sys, argparse
sys.path.insert(0, __file__.rsplit('/', 2)[0] + '/hem_r17')
import numpy as np
from scipy.spatial import cKDTree
from scipy.sparse import coo_matrix
from glbio import load, acc, put, save


def smooth(X, F, it):
    n = len(X); a_ = np.r_[F[:, 0], F[:, 1], F[:, 2], F[:, 1], F[:, 2], F[:, 0]]; c = np.r_[F[:, 1], F[:, 2], F[:, 0], F[:, 0], F[:, 1], F[:, 2]]
    A = coo_matrix((np.ones(len(a_)), (a_, c)), shape=(n, n)).tocsr(); deg = np.asarray(A.sum(1)) + 1
    for _ in range(it): X = (A @ X + X) / deg
    return X


def main():
    ap = argparse.ArgumentParser(); ap.add_argument('inp'); ap.add_argument('out')
    ap.add_argument('--k', type=int, default=6); ap.add_argument('--headband', type=float, default=0.08)
    ap.add_argument('--armfold', type=float, default=1.0); ap.add_argument('--smooth', type=int, default=4)
    ap.add_argument('--needles', type=float, default=0.03, help='share needle (rigid Spine) weights with hair within this distance of the needles; 0 = off')
    a = ap.parse_args()
    j, b = load(a.inp); names = [j['nodes'][n]['name'] for n in j['skins'][0]['joints']]; nj = len(names)
    pr = j['meshes'][1]['primitives']; mat = lambda p: j['materials'][p['material']]['name']
    body = [p for p in pr if mat(p) == 'body-retex']; hair = [p for p in pr if mat(p) == 'hair35'][0]
    P = np.vstack([acc(j, b, p['attributes']['POSITION']) for p in body]).astype(float)
    J = np.vstack([acc(j, b, p['attributes']['JOINTS_0']) for p in body]).astype(int)
    W = np.vstack([acc(j, b, p['attributes']['WEIGHTS_0']) for p in body]).astype(float)
    if a.armfold > 0:  # fraction of each arm/hand bone weight moved to that side's Shoulder (1 = hair never follows the arm)
        for side in ('Left', 'Right'):
            sh = names.index(side + 'Shoulder'); arm = np.isin(J, [i for i, n in enumerate(names) if n.startswith(side) and 'Shoulder' not in n])
            if a.armfold >= 1: J[arm] = sh; continue
            J = np.hstack([J, np.where(arm, sh, J)]); W = np.hstack([np.where(arm, W * (1 - a.armfold), W), np.where(arm, W * a.armfold, 0)])
    Q = acc(j, b, hair['attributes']['POSITION']).astype(float); F = acc(j, b, hair['indices']).astype(int).reshape(-1, 3)
    d, k = cKDTree(P).query(Q, a.k); iw = 1 / (d + 0.005)
    Wd = np.zeros((len(Q), nj))
    for m in range(a.k):
        for c in range(J.shape[1]): np.add.at(Wd, (np.arange(len(Q)), J[k[:, m], c]), W[k[:, m], c] * iw[:, m])
    Wd /= Wd.sum(1, keepdims=True)
    if a.needles:  # hair between the back and the needles (rigid on Spine): share the motion by relative distance
        NP = np.vstack([acc(j, b, p['attributes']['POSITION']) for p in pr if mat(p) == 'needles-retex']).astype(float)
        NJ = np.vstack([acc(j, b, p['attributes']['JOINTS_0']) for p in pr if mat(p) == 'needles-retex']).astype(int)
        NW = np.vstack([acc(j, b, p['attributes']['WEIGHTS_0']) for p in pr if mat(p) == 'needles-retex']).astype(float)
        dn, kn = cKDTree(NP).query(Q); db = d[:, 0]
        f = (db / (db + dn + 1e-9)) * np.clip((a.needles - dn) / (a.needles / 2), 0, 1)
        Wn = np.zeros((len(Q), nj))
        for c in range(4): np.add.at(Wn, (np.arange(len(Q)), NJ[kn, c]), NW[kn, c])
        Wd = (1 - f[:, None]) * Wd + f[:, None] * Wn; print('needle share: %d verts, mean %.2f' % ((f > 0.01).sum(), f[f > 0.01].mean() if (f > 0.01).any() else 0))
    yt = Q[:, 1].max(); hw = np.clip((Q[:, 1] - (yt - a.headband)) / a.headband, 0, 1)[:, None]
    hd = np.zeros(nj); hd[names.index('Head')] = 1; Wd = (1 - hw) * Wd + hw * hd
    Wd = smooth(Wd, F, a.smooth)
    order = np.argsort(-Wd, 1)[:, :4]; WW = np.take_along_axis(Wd, order, 1); WW /= WW.sum(1, keepdims=True)
    jt = j['accessors'][hair['attributes']['JOINTS_0']]['componentType']
    from glbio import CT
    put(j, b, hair["attributes"]["JOINTS_0"], order.astype(CT[jt]))
    put(j, b, hair["attributes"]["WEIGHTS_0"], WW.astype(np.float32))
    dom = np.bincount(order[:, 0], minlength=nj); print('hair dominant joints', {names[i]: int(c) for i, c in enumerate(dom) if c})
    save(a.out, j, b); print('hairw37: reweighted %d hair verts (k %d, headband %.2f) -> %s' % (len(Q), a.k, a.headband, a.out))


main()
