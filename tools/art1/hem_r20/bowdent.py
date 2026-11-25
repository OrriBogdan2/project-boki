"""bowdent.py IN OUT [gap=0.006 iters=2]: pose the leg-meshy prim and the bow at every 30 fps frame of every clip (linear blend
skinning from the glb's own skin, same sampling as tools/anim/geo_check.py) and push only the leg verts the bow/left hand comes
within `gap` of, inward along their normal (in bind space), smoothed over neighbours. Leg prim positions/normals change only."""
import sys; sys.path.insert(0, __file__.rsplit('/',1)[0])
from glbio import *
from scipy.spatial import cKDTree
from scipy.spatial.transform import Rotation as Rot, Slerp
IN, OUT = sys.argv[1:3]; O = dict(a.split('=') for a in sys.argv[3:]); GAP = float(O.get('gap', 0.006))
j, b = load(IN); N = j['nodes']; sk = j['skins'][0]; JN = sk['joints']; IB = acc(j, b, sk['inverseBindMatrices']).reshape(-1, 4, 4).transpose(0, 2, 1)
par = {c: i for i, n in enumerate(N) for c in n.get('children', [])}
def mats(an, t):
    tr = {}
    for c in an['channels']:
        s = an['samplers'][c['sampler']]; tr[(c['target']['node'], c['target']['path'])] = (acc(j, b, s['input'])[:, 0], acc(j, b, s['output']).astype(float))
    G = {}
    def g(i):
        if i in G: return G[i]
        n = N[i]; T = np.array(n.get('translation', [0, 0, 0]), float); R = Rot.from_quat(n.get('rotation', [0, 0, 0, 1])); S = np.array(n.get('scale', [1, 1, 1]), float)
        if (i, 'translation') in tr: ti, o = tr[(i, 'translation')]; T = np.array([np.interp(t, ti, o[:, k]) for k in range(3)])
        if (i, 'rotation') in tr:
            ti, o = tr[(i, 'rotation')]; R = Slerp(ti, Rot.from_quat(o))(np.clip(t, ti[0], ti[-1])) if len(ti) > 1 else Rot.from_quat(o[0])
        if (i, 'scale') in tr: ti, o = tr[(i, 'scale')]; S = np.array([np.interp(t, ti, o[:, k]) for k in range(3)])
        M = np.eye(4); M[:3, :3] = R.as_matrix() * S; M[:3, 3] = T
        G[i] = (g(par[i]) @ M) if i in par else M; return G[i]
    return np.array([g(k) @ IB[n] for n, k in enumerate(JN)])
def prims(pred):
    out = []
    for mi, m in enumerate(j['meshes']):
        for p in m['primitives']:
            if pred(mi, j['materials'][p['material']]['name']): out.append(p)
    return out
leg = prims(lambda mi, n: n == 'leg-meshy')[0]
obs = prims(lambda mi, n: n in ('leather-bow.live', 'cloth-thread.live', 'body-hand17'))
def ld(p): A = p['attributes']; return acc(j, b, A['POSITION']).astype(float), acc(j, b, A['JOINTS_0']).astype(int), acc(j, b, A['WEIGHTS_0']).astype(float)
LP, LJ, LW = ld(leg); LN = acc(j, b, leg['attributes']['NORMAL']).astype(float)
OB = [ld(p) for p in obs]
def skin(M, P, J, W):
    S = np.einsum('vk,vkab->vab', W, M[J]); return np.einsum('vab,vb->va', S[:, :3, :3], P) + S[:, :3, 3], S
LF = acc(j, b, leg['indices']).reshape(-1, 3)
nb = cKDTree(LP).query(LP, 12)[1]
for it in range(int(O.get('iters', 2))):
    push = np.zeros(len(LP)); dirb = np.zeros((len(LP), 3)); hits = 0
    for an in j['animations']:
        tmax = max(acc(j, b, s['input'])[:, 0].max() for s in an['samplers'])
        for t in np.arange(0, tmax + 1e-6, 1 / 30):
            M = mats(an, t); PL, S = skin(M, LP, LJ, LW); NL = np.einsum('vab,vb->va', S[:, :3, :3], LN); NL /= np.linalg.norm(NL, axis=1, keepdims=True)
            OP = np.vstack([skin(M, *o)[0] for o in OB])
            tr = cKDTree(PL); d, ix = tr.query(OP, 1)
            near = d < 0.03
            for q, v in zip(OP[near], ix[near]):
                sd = (q - PL[v]) @ NL[v]
                if sd < GAP and sd > -0.04:
                    need = sd - GAP
                    # push v and its posed neighbours within 1.5 cm
                    vs = tr.query_ball_point(PL[v], 0.015)
                    for u in vs:
                        if need < push[u]: push[u] = need; dirb[u] = np.linalg.solve(S[u, :3, :3], NL[u]); hits += 1
    print('iter', it, 'verts pushed', int((push < 0).sum()), 'max cm', round(-push.min() * 100, 2), 'hits', hits)
    if not (push < 0).any(): break
    for _ in range(2): push = np.minimum(push, push[nb].mean(1)); dirb = np.where((np.linalg.norm(dirb, axis=1) > 0)[:, None], dirb, dirb[nb].mean(1))
    dn = dirb / np.maximum(np.linalg.norm(dirb, axis=1, keepdims=True), 1e-9)
    LP = LP + push[:, None] * dn
fn = np.cross(LP[LF[:, 1]] - LP[LF[:, 0]], LP[LF[:, 2]] - LP[LF[:, 0]]); nn = np.zeros_like(LP)
for k in range(3): np.add.at(nn, LF[:, k], fn)
nn /= np.maximum(np.linalg.norm(nn, axis=1, keepdims=True), 1e-9)
put(j, b, leg['attributes']['POSITION'], LP.astype(np.float32)); put(j, b, leg['attributes']['NORMAL'], nn.astype(np.float32))
save(OUT, j, b)
