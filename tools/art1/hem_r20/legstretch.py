import sys; sys.path.insert(0,'.')
exec(open('bowdent.py').read().split("LF = acc(j, b, leg['indices'])")[0].replace("IN, OUT = sys.argv[1:3]","IN, OUT = sys.argv[1], None"))
LF = acc(j, b, leg['indices']).reshape(-1, 3)
E = np.unique(np.sort(np.r_[LF[:, [0, 1]], LF[:, [1, 2]], LF[:, [2, 0]]], 1), axis=0)
bl = np.linalg.norm(LP[E[:, 0]] - LP[E[:, 1]], axis=1); E = E[bl >= 0.005]; bl = bl[bl >= 0.005]
worst = np.ones(len(E)); wclip = [''] * len(E)
for an in j['animations']:
    tmax = max(acc(j, b, s['input'])[:, 0].max() for s in an['samplers'])
    for t in np.arange(0, tmax + 1e-6, 1 / 30):
        PL, _ = skin(mats(an, t), LP, LJ, LW); r = np.linalg.norm(PL[E[:, 0]] - PL[E[:, 1]], axis=1) / bl
        up = r > worst; worst[up] = r[up]
names = [N[k]['name'] for k in JN]
bad = worst > 3; dom = LJ[np.arange(len(LJ)), LW.argmax(1)]
print('edges', len(E), '>3x', bad.sum(), 'worst', worst.max().round(2))
v = E[bad].ravel(); print('y of bad verts', np.percentile(LP[v, 1], [5, 50, 95]).round(3))
from collections import Counter; print(Counter(names[dom[a]] + '-' + names[dom[c]] for a, c in E[bad]).most_common(6))
print('bind len of bad edges cm', np.percentile(bl[bad] * 100, [5, 50, 95]).round(2))
vb = np.unique(E[bad].ravel())
cnt = Counter()
for v_ in vb:
    for k in range(4):
        if LW[v_, k] > 0.05: cnt[names[LJ[v_, k]]] += 1
print('bones on bad verts (w>0.05)', cnt.most_common(10))
print('sample', [(names[LJ[v_,k]], round(float(LW[v_,k]),2)) for v_ in vb[:3] for k in range(4)])
