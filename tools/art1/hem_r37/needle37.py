"""needle37.py BASE.glb IN.obj OUT.obj [--gap G] [--r R] [--armgap A]: Lace r37 hair vs the crossed back needles, only under the needles.
Why: the l1 locks (best match to the turnaround: wide wavy back curtain) cross the needle plane (needles-retex = geo_check
torso.3/.4, front face z -0.135) so a lock sat ~1 cm inside a needle in idle; a global z clamp (l2) flattened and narrowed
the whole curtain. The ref back view has the needles lying ON the hair, so the hair only has to stay in front of them
where they are.
How: for each hair vertex, the needle verts within R in x/y; if any, z >= (their max z = the face toward the body) + G,
with the push blended out over the last R/2 so there is no step. --armgap: hair verts near the arm-skinned body verts slide
in x toward the torso centre. Faces/UVs kept."""
import sys, argparse
sys.path.insert(0, __file__.rsplit('/', 2)[0] + '/hem_r17')
import numpy as np
from scipy.spatial import cKDTree
from glbio import load, acc


def main():
    ap = argparse.ArgumentParser(); ap.add_argument('base'); ap.add_argument('inp'); ap.add_argument('out')
    ap.add_argument('--gap', type=float, default=0.008); ap.add_argument('--r', type=float, default=0.03)
    ap.add_argument('--armgap', type=float, default=0.0, help='slide hair verts closer than this to an arm-skinned body vertex toward the torso centre x')
    ap.add_argument('--cx', type=float, default=-0.03)
    a = ap.parse_args()
    j, b = load(a.base)
    NP = np.vstack([acc(j, b, p['attributes']['POSITION']) for m in j['meshes'] for p in m['primitives']
                    if j['materials'][p['material']]['name'] == 'needles-retex']).astype(float)
    lines = open(a.inp).read().splitlines(); vi = [i for i, l in enumerate(lines) if l.startswith('v ')]
    Q = np.array([[float(x) for x in lines[i].split()[1:4]] for i in vi])
    tr = cKDTree(NP[:, :2]); nb = tr.query_ball_point(Q[:, :2], a.r)
    X = Q.copy(); n = 0; worst = 0
    for i, c in enumerate(nb):
        if not c: continue
        dxy = np.linalg.norm(NP[c, :2] - Q[i, :2], axis=1); zf = NP[c, 2].max() + a.gap
        w = np.clip((a.r - dxy.min()) / (a.r / 2), 0, 1)
        if Q[i, 2] < zf and Q[i, 2] > NP[c, 2].min() - 0.05:
            X[i, 2] = Q[i, 2] + w * (zf - Q[i, 2]); n += 1; worst = max(worst, zf - Q[i, 2])
    if a.armgap > 0:  # r37 l3: curtain edges/side locks brushed the upper arms 0.6 cm in run/walk: slide them in x toward the torso
        names = [j['nodes'][n]['name'] for n in j['skins'][0]['joints']]
        bp = [p for p in j['meshes'][1]['primitives'] if j['materials'][p['material']]['name'] == 'body-retex']
        BP = np.vstack([acc(j, b, p['attributes']['POSITION']) for p in bp]).astype(float)
        BJ = np.vstack([acc(j, b, p['attributes']['JOINTS_0']) for p in bp]).astype(int)
        BW = np.vstack([acc(j, b, p['attributes']['WEIGHTS_0']) for p in bp]).astype(float)
        dom = np.array(names)[BJ[np.arange(len(BJ)), BW.argmax(1)]]
        arm = np.array([d.startswith(('Left', 'Right')) and 'Shoulder' not in d for d in dom]); at = cKDTree(BP[arm])
        moved = np.zeros(len(X), bool)
        for it in range(20):
            d = at.query(X)[0]; bad = d < a.armgap
            if not bad.any(): break
            X[bad, 0] -= np.sign(X[bad, 0] - a.cx) * np.minimum(a.armgap - d[bad], 0.004); moved |= bad
        print('armgap %.3f: slid %d verts toward the torso (max %.2f cm), still close %d' % (
            a.armgap, moved.sum(), np.abs(X[:, 0] - Q[:, 0]).max() * 100, (at.query(X)[0] < a.armgap - 1e-4).sum()))
    print('needle37: moved %d verts in front of the needles (worst %.2f cm)' % (n, worst * 100))
    for k, i in enumerate(vi): lines[i] = 'v %.6f %.6f %.6f' % tuple(X[k])
    open(a.out, 'w').write('\n'.join(lines) + '\n')


main()
