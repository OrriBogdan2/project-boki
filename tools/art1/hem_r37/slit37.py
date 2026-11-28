"""slit37.py IN.glb OUT.glb [--cx X] [--top Y] [--hw0 A] [--hw1 B] [--zmin Z] [--lean L]: Lace r37 front slit of the long red skirt.
Why: owner 11-27 "a cut in the front of the dress". The r35 slit is a ~5 cm gap on her right thigh with a flap
(cloth-skirtgodet) that reads as jagged white/red teeth from the side and as a dark shard at game view; from the game
camera (high, front) the gap is closed by the skirt's own fall, so no leg shows. The turnaround has a clean slit on her
right leg from the upper thigh to the hem, opening downward so the porcelain knee and boot show.
How (faces removed only, raw glb edit, verts/UVs/weights untouched): drop the godet primitive; in skirtmeshy and its
same-topology skirtlining (doubleSided, so the cut rim shows the red lining), drop the front faces (centroid z > Z) whose
centroid x is within the wedge centre(y) +- halfwidth(y): centre = X + L*(top - y) (her right is -x), halfwidth from A at
y=top to B at the hem, smooth top (no notch). New index accessors are appended; the old ones are orphaned."""
import sys, argparse
sys.path.insert(0, __file__.rsplit('/', 2)[0] + '/hem_r17')
import numpy as np
from glbio import load, acc, save, CT


def main():
    ap = argparse.ArgumentParser(); ap.add_argument('inp'); ap.add_argument('out')
    ap.add_argument('--cx', type=float, default=-0.115); ap.add_argument('--top', type=float, default=0.86)
    ap.add_argument('--hw0', type=float, default=0.012); ap.add_argument('--hw1', type=float, default=0.075)
    ap.add_argument('--zmin', type=float, default=0.0); ap.add_argument('--lean', type=float, default=0.0)
    ap.add_argument('--drop', default='cloth-skirtgodet'); ap.add_argument('--cut', default='cloth-skirtmeshy,cloth-skirtlining')
    a = ap.parse_args()
    j, b = load(a.inp); mat = lambda p: j['materials'][p['material']]['name']

    def addacc(arr, ct):
        nonlocal b
        raw = np.ascontiguousarray(arr.astype(CT[ct])).tobytes(); off = len(b); b = b + bytearray(raw) + bytearray((-len(raw)) % 4)
        j['bufferViews'].append({'buffer': 0, 'byteOffset': off, 'byteLength': len(raw)})
        j['accessors'].append({'bufferView': len(j['bufferViews']) - 1, 'componentType': ct, 'count': len(arr), 'type': 'SCALAR'})
        return len(j['accessors']) - 1
    for m in j['meshes']:
        n0 = len(m['primitives']); m['primitives'] = [p for p in m['primitives'] if mat(p) != a.drop]
        if len(m['primitives']) != n0: print('dropped %d %s prim(s)' % (n0 - len(m['primitives']), a.drop))
        for p in m['primitives']:
            if mat(p) not in a.cut.split(','): continue
            P = acc(j, b, p['attributes']['POSITION']).astype(float); F = acc(j, b, p['indices']).astype(np.int64).reshape(-1, 3)
            C = P[F].mean(1); y = C[:, 1]
            t = np.clip((a.top - y) / (a.top - 0.30), 0, 1)
            hw = a.hw0 + (a.hw1 - a.hw0) * t ** 0.8
            hw = np.where(y > a.top, a.hw0 * np.clip(1 - (y - a.top) / 0.03, 0, 1), hw)  # rounded top, 3 cm
            cen = a.cx + a.lean * np.clip(a.top - y, 0, None)
            cut = (C[:, 2] > a.zmin) & (np.abs(C[:, 0] - cen) < hw) & (y < a.top + 0.03)
            F2 = F[~cut]; ct = j['accessors'][p['indices']]['componentType']
            if len(P) > 65535: ct = 5125
            p['indices'] = addacc(F2.ravel(), ct)
            print('%s: cut %d of %d faces (y %.3f..%.3f)' % (mat(p), cut.sum(), len(F), y[cut].min(), y[cut].max()) if cut.any() else '%s: nothing cut' % mat(p))
    save(a.out, j, b); print('slit37 ->', a.out)


main()
