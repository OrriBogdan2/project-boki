"""bowkey20.py IN OUT [clip=walk gap=0.008 win=4]: the bow's lower limb enters the left knee in walk (geo 2.4 cm at f12). Instead of
denting the knee (it crumples the ball), re-key the Bow joint rotation of that clip at 30 fps with a small smoothed tilt about the
Bow joint (the grip) so the limb clears the leg by `gap`. Other clips and all meshes unchanged."""
import sys; sys.path.insert(0, __file__.rsplit('/',1)[0])
exec(open(__file__.rsplit('/',1)[0] + '/bowdent.py').read().split("LF = acc(j, b, leg['indices'])")[0].replace("IN, OUT = sys.argv[1:3]", "IN, OUT = sys.argv[1:3]; _x=0"))
CL = O.get('clip', 'walk'); GAP = float(O.get('gap', 0.008)); WIN = int(O.get('win', 4))
an = [a for a in j['animations'] if a['name'] == CL][0]
bowj = [i for i, n in enumerate(N) if n.get('name') == 'Bow' and 'mesh' not in n][0]; bk = JN.index(bowj)
bowp = [p for p in obs if j['materials'][p['material']]['name'] == 'leather-bow.live'][0]; BP = ld(bowp)
tmax = max(acc(j, b, s['input'])[:, 0].max() for s in an['samplers']); ts = np.arange(0, tmax + 1e-6, 1 / 30)
def need_at(t, extra=None):
    M = mats(an, t)
    if extra is not None: M = M.copy(); M[BP[1][:, 0][0]] = M[BP[1][:, 0][0]]  # placeholder (bow verts are rigid on Bow)
    PL, S = skin(M, LP, LJ, LW); NL = np.einsum('vab,vb->va', S[:, :3, :3], LN); NL /= np.linalg.norm(NL, axis=1, keepdims=True)
    PB = skin(M, *BP)[0]; d, ix = cKDTree(PL).query(PB, 1); best = (0, None, None)
    for q, v, dd in zip(PB, ix, d):
        if dd > 0.04: continue
        sd = (q - PL[v]) @ NL[v]
        if sd < GAP and sd > -0.05 and GAP - sd > best[0]: best = (GAP - sd, q, NL[v])
    return best, M
# world pivot = Bow joint origin; rotation that moves the contact point along the leg normal by `need`
ang = np.zeros(len(ts)); ax = np.zeros((len(ts), 3))
for k, t in enumerate(ts):
    (nd, q, n), M = need_at(t)
    if nd <= 0: continue
    G = M[bk] @ np.linalg.inv(IB[bk]); piv = G[:3, 3]; r = q - piv
    a = np.cross(r, n); a /= np.linalg.norm(a); rp = np.linalg.norm(r - (r @ a) * a)
    ang[k] = nd / rp * 1.15; ax[k] = a
print('frames needing tilt', int((ang > 0).sum()), 'max deg', np.degrees(ang.max()).round(2))
if ang.max() > 0:
    A0 = ax[ang.argmax()]
    a2 = np.array([ang[max(0, k - WIN):k + WIN + 1].max() for k in range(len(ts))])
    for _ in range(3): a2 = np.maximum(a2, np.convolve(np.pad(a2, 2, mode='edge'), np.ones(5) / 5, 'valid'))
    for _ in range(2): a2 = np.convolve(np.pad(a2, 2, mode='edge'), np.ones(5) / 5, 'valid')
    # local delta per frame: Grot^T Rw Grot (rotate about the joint's own origin)
    ch = [c for c in an['channels'] if c['target']['node'] == bowj and c['target']['path'] == 'rotation'][0]; s = an['samplers'][ch['sampler']]
    ti, qo = acc(j, b, s['input'])[:, 0], acc(j, b, s['output']).astype(float)
    base = Slerp(ti, Rot.from_quat(qo))(np.clip(ts, ti[0], ti[-1])) if len(ti) > 1 else Rot.from_quat(np.repeat(qo[:1], len(ts), 0))
    outq = []
    for k, t in enumerate(ts):
        M = mats(an, t); G = M[bk] @ np.linalg.inv(IB[bk]); Gr = G[:3, :3] / np.linalg.norm(G[:3, :3], axis=0)
        Rw = Rot.from_rotvec(A0 * a2[k]).as_matrix(); dl = Rot.from_matrix(Gr.T @ Rw @ Gr)
        outq.append((base[k] * dl).as_quat())
    outq = np.array(outq, np.float32)
    def addacc(arr, typ, mm=False):
        global b
        raw = np.ascontiguousarray(arr.astype(np.float32)).tobytes(); off = len(b); b = b + bytearray(raw) + bytearray((-len(raw)) % 4)
        j['bufferViews'].append({'buffer': 0, 'byteOffset': off, 'byteLength': len(raw)})
        d = {'bufferView': len(j['bufferViews']) - 1, 'componentType': 5126, 'count': len(arr), 'type': typ}
        if mm: d['min'] = [float(arr.min())]; d['max'] = [float(arr.max())]
        j['accessors'].append(d); return len(j['accessors']) - 1
    an['samplers'].append({'input': addacc(ts.reshape(-1, 1), 'SCALAR', True), 'output': addacc(outq, 'VEC4'), 'interpolation': 'LINEAR'})
    ch['sampler'] = len(an['samplers']) - 1
    j['buffers'][0]['byteLength'] = len(b)
    print('tilt frames >0.1deg', int((np.degrees(a2) > 0.1).sum()), 'max deg', np.degrees(a2.max()).round(2))
    save(OUT, j, b)
