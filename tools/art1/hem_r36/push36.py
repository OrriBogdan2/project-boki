"""push36.py BASE.glb IN.obj OUT.obj [--gap G] [--y0 Y] [--needle Z] [--cell C] [--r R]: Lace r36 hair clearance.
Why: r35's solid lock (solid35.py solidifies the cut strands 1 cm toward the body, then voxel-remesh) spans z -0.137..-0.02
at the spine: its inner half sits INSIDE the torso (back surface z -0.07..-0.095), so the corset showed through the hair in
every clip (review 11-27 16:02, held 1.54 cm). A nearest-vertex-normal test misses such deep points.
How: torso height field from the body-retex verts skinned to the spine (grid C m in x,y): back z and front z per cell.
Per hair vertex below Y (blend to none at Y+6 cm) in a torso cell: behind the torso centre -> the lock's local z range
(R-ball) is remapped into [outer, back - G] keeping its order (thickness compressed, outer wall kept unless it was
itself too close: then outer = back - G - 8 mm), but never behind the needle plane Z (needles stay on top of the hair,
as in the ref back view). In front of the torso centre (front locks) mirrored: [front + G, ...]. Cells with no torso
(beside the arms, above the shoulders) are left as they are. UVs/faces kept."""
import sys, argparse
sys.path.insert(0, __file__.rsplit('/', 2)[0] + '/hem_r17')
import numpy as np
from scipy.spatial import cKDTree
from scipy.ndimage import grey_dilation, grey_erosion
from glbio import load, acc

AX = ['Hips', 'Spine', 'Spine01', 'Spine02', 'neck']


def main():
    ap = argparse.ArgumentParser(); ap.add_argument('base'); ap.add_argument('inp'); ap.add_argument('out')
    ap.add_argument('--gap', type=float, default=0.022); ap.add_argument('--y0', type=float, default=1.47)
    ap.add_argument('--needle', type=float, default=-0.130); ap.add_argument('--cell', type=float, default=0.01)
    ap.add_argument('--r', type=float, default=0.03); ap.add_argument('--minthick', type=float, default=0.008)
    ap.add_argument('--armtrim', type=float, default=0.0, help='drop hair faces with a vertex this close to an arm-skinned body vertex (bow excluded)')
    ap.add_argument('--lockhalfw', type=float, default=0.0, help='front locks (z > 3 cm, y 1.25..1.48): drop faces wider than this from the torso centre (arm swings into them in walk)')
    a = ap.parse_args()
    j, b = load(a.base); names = [j['nodes'][n]['name'] for n in j['skins'][0]['joints']]
    p = [q for q in j['meshes'][1]['primitives'] if j['materials'][q['material']]['name'] == 'body-retex'][0]
    P = acc(j, b, p['attributes']['POSITION']).astype(float); J = acc(j, b, p['attributes']['JOINTS_0']).astype(int)
    W = acc(j, b, p['attributes']['WEIGHTS_0']).astype(float)
    dom = J[np.arange(len(J)), W.argmax(1)]; T = P[np.isin(dom, [names.index(n) for n in AX if n in names])]
    x0, y0 = T[:, 0].min() - 0.05, T[:, 1].min() - 0.05; nx = int((T[:, 0].max() + 0.05 - x0) / a.cell) + 1; ny = int((T[:, 1].max() + 0.05 - y0) / a.cell) + 1
    ix = ((T[:, 0] - x0) / a.cell).astype(int); iy = ((T[:, 1] - y0) / a.cell).astype(int)
    zb = np.full((nx, ny), 9.0); zf = np.full((nx, ny), -9.0)
    np.minimum.at(zb, (ix, iy), T[:, 2]); np.maximum.at(zf, (ix, iy), T[:, 2])
    zb = grey_erosion(zb, size=(3, 3)); zf = grey_dilation(zf, size=(3, 3))  # conservative: 1 cell around
    lines = open(a.inp).read().splitlines(); vi = [i for i, l in enumerate(lines) if l.startswith('v ')]
    Q = np.array([[float(x) for x in lines[i].split()[1:4]] for i in vi])
    gx = np.clip(((Q[:, 0] - x0) / a.cell).astype(int), 0, nx - 1); gy = np.clip(((Q[:, 1] - y0) / a.cell).astype(int), 0, ny - 1)
    inx = (Q[:, 0] > x0) & (Q[:, 0] < x0 + nx * a.cell) & (Q[:, 1] > y0) & (Q[:, 1] < y0 + ny * a.cell)
    B, F = zb[gx, gy], zf[gx, gy]; has = inx & (B < 1) & (F > -1)
    w = np.clip((Q[:, 1] - a.y0) / 0.06, 0, 1); act = has & (w < 1)
    back = act & (Q[:, 2] < (B + F) / 2); front = act & ~back
    nb = cKDTree(Q).query_ball_point(Q, a.r)
    lo = np.array([Q[n, 2].min() for n in nb]); hi = np.array([Q[n, 2].max() for n in nb])
    X = Q.copy()
    # back: z range [lo (outer), hi (inner)] -> [outer', inner'] with inner' = min(hi, B - gap), outer' = min(lo, inner' - minthick), >= needle
    inner = np.minimum(hi, B - a.gap); outer = np.maximum(np.minimum(lo, inner - a.minthick), a.needle); inner = np.maximum(inner, outer)
    s = np.where(hi - lo > 1e-6, (Q[:, 2] - lo) / np.maximum(hi - lo, 1e-6), 0.5); zn = outer + s * (inner - outer)
    X[back, 2] = (1 - w[back]) * zn[back] + w[back] * Q[back, 2]
    # front locks: z range [lo (inner), hi (outer)] -> inner' = max(lo, F + gap)
    inF = np.maximum(lo, F + a.gap); outF = np.maximum(hi, inF + a.minthick)
    znf = inF + s * (outF - inF); X[front, 2] = (1 - w[front]) * znf[front] + w[front] * Q[front, 2]

    def report(Z, tag):
        bk = act & (Z[:, 2] < (B + F) / 2); fr = act & ~bk
        db = (Z[:, 2] - (B - a.gap))[bk]; df = ((F + a.gap) - Z[:, 2])[fr]
        print('%s: back verts %d, inside back+gap %d (worst %.1f cm), inside torso %d | front verts %d inside %d (worst %.1f cm); behind needles %d' % (
            tag, bk.sum(), (db > 1e-4).sum(), db.max() * 100 if bk.any() else 0, (Z[bk, 2] > B[bk]).sum(), fr.sum(), (df > 1e-4).sum(),
            df.max() * 100 if fr.any() else 0, (Z[act, 2] < a.needle - 1e-4).sum()))
    report(Q, 'before'); report(X, 'after')
    mv = np.abs(X[:, 2] - Q[:, 2]); print('moved %d verts, max %.1f cm, median of moved %.1f cm' % ((mv > 1e-4).sum(), mv.max() * 100, np.median(mv[mv > 1e-4]) * 100))
    for n, i in enumerate(vi): lines[i] = 'v %.6f %.6f %.6f' % tuple(X[n])
    if a.armtrim > 0:  # r36: the lock over the shoulder cap clipped the upper arm in idle/attack; drop it, compact the obj
        ARM = [n for n in names if n.startswith(('Left', 'Right')) and 'Shoulder' not in n]
        A = P[np.isin(dom, [names.index(n) for n in ARM])]
        near = cKDTree(A).query(X)[0] < a.armtrim
        if a.lockhalfw > 0:
            cx = np.median(T[:, 0]); wide = (X[:, 2] > 0.03) & (X[:, 1] > 1.25) & (X[:, 1] < 1.48) & (np.abs(X[:, 0] - cx) > a.lockhalfw)
            print('lockhalfw %.3f (cx %.3f): %d wide front-lock verts' % (a.lockhalfw, cx, wide.sum())); near |= wide
        fl = [i for i, l in enumerate(lines) if l.startswith('f ')]
        fv = [[int(t.split('/')[0]) - 1 for t in lines[i].split()[1:]] for i in fl]
        drop = {i for i, f in zip(fl, fv) if near[f].any()}
        keep = [i for i in fl if i not in drop]; used = sorted({v for i, f in zip(fl, fv) if i not in drop for v in f})
        ut = sorted({int(t.split('/')[1]) - 1 for i in keep for t in lines[i].split()[1:]})
        rv = {v: k + 1 for k, v in enumerate(used)}; rt = {v: k + 1 for k, v in enumerate(ut)}
        vt = [l for l in lines if l.startswith('vt ')]
        out = [lines[vi[v]] for v in used] + [vt[t] for t in ut]
        out += ['f ' + ' '.join('%d/%d' % (rv[int(t.split('/')[0]) - 1], rt[int(t.split('/')[1]) - 1]) for t in lines[i].split()[1:]) for i in keep]
        print('armtrim %.3f: dropped %d of %d faces (%d verts near the arms)' % (a.armtrim, len(drop), len(fl), near.sum()))
        lines = out
    open(a.out, 'w').write('\n'.join(lines) + '\n')


main()
