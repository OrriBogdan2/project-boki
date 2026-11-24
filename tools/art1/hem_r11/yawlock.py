"""yawlock.py IN.glb OUT.glb [clip=Idle] [head_keep=0.3]: lock the Hips' world yaw (about glTF +Y) in one clip to its
first-key value, and damp the Head's leftover yaw swing to head_keep of itself. Edits only those rotation keys."""
import sys, json, struct, numpy as np
src, dst = sys.argv[1], sys.argv[2]; kw = dict(a.split('=') for a in sys.argv[3:])
CLIP = kw.get('clip', 'Idle'); HK = float(kw.get('head_keep', 0.3))
raw = open(src, 'rb').read(); jl = struct.unpack('<I', raw[12:16])[0]; j = json.loads(raw[20:20 + jl])
binoff = 20 + jl + 8; b = bytearray(raw[binoff:binoff + struct.unpack('<I', raw[20 + jl:24 + jl])[0]])
CT = {5126: ('f', 4)}; NC = {'SCALAR': 1, 'VEC3': 3, 'VEC4': 4}
def acc(i):
    a = j['accessors'][i]; v = j['bufferViews'][a['bufferView']]; o = v.get('byteOffset', 0) + a.get('byteOffset', 0)
    n = NC[a['type']]; assert a['componentType'] == 5126 and v.get('byteStride', 4 * n) == 4 * n
    return np.frombuffer(bytes(b[o:o + 4 * n * a['count']]), '<f4').reshape(-1, n).astype(float), o
def put(i, arr):
    _, o = acc(i); b[o:o + arr.size * 4] = arr.astype('<f4').tobytes()
def qmul(a, c):
    x1, y1, z1, w1 = a; x2, y2, z2, w2 = c
    return np.array([w1*x2 + x1*w2 + y1*z2 - z1*y2, w1*y2 - x1*z2 + y1*w2 + z1*x2, w1*z2 + x1*y2 - y1*x2 + z1*w2, w1*w2 - x1*x2 - y1*y2 - z1*z2])
def qinv(q): return np.array([-q[0], -q[1], -q[2], q[3]]) / np.dot(q, q)
def qrot(q, v): return qmul(qmul(q, np.array([*v, 0.0])), qinv(q))[:3]
def qy(a): return np.array([0, np.sin(a / 2), 0, np.cos(a / 2)])
def slerp(a, c, t):
    if np.dot(a, c) < 0: c = -c
    r = a + (c - a) * t; return r / np.linalg.norm(r)
nodes = j['nodes']; parent = {}
for i, n in enumerate(nodes):
    for c in n.get('children', []): parent[c] = i
name = {n.get('name'): i for i, n in enumerate(nodes)}
anim = [a for a in j['animations'] if a['name'] == CLIP][0]
rch = {}
for ch in anim['channels']:
    if ch['target']['path'] == 'rotation':
        s = anim['samplers'][ch['sampler']]; t, _ = acc(s['input']); v, _ = acc(s['output'])
        rch[ch['target']['node']] = [t[:, 0], v, s['output']]
def lrot(n, tm):
    if n in rch:
        t, v, _ = rch[n]
        if tm <= t[0]: return v[0]
        if tm >= t[-1]: return v[-1]
        k = np.searchsorted(t, tm) - 1; return slerp(v[k], v[k + 1], (tm - t[k]) / (t[k + 1] - t[k]))
    return np.array(nodes[n].get('rotation', [0, 0, 0, 1.0]))
def wrot(n, tm):
    q = lrot(n, tm)
    while n in parent: n = parent[n]; q = qmul(lrot(n, tm), q)
    return q
def yaw(q, ax):
    f = qrot(q, ax); return np.arctan2(f[0], f[2])
def lock(bone, keep):
    n = name[bone]; t, v, oi = rch[n]; P = lambda tm: wrot(parent[n], tm)
    # a horizontal local axis: the one whose world image is flattest at t0
    W0 = qmul(P(t[0]), v[0]); ax = min(np.eye(3), key=lambda e: abs(qrot(W0, e)[1]))
    y0 = yaw(W0, ax); out = v.copy(); sw = []
    for k, tm in enumerate(t):
        Pq = P(tm); W = qmul(Pq, v[k]); d = (yaw(W, ax) - y0 + np.pi) % (2 * np.pi) - np.pi; sw.append(np.degrees(d))
        out[k] = qmul(qinv(Pq), qmul(qy(-(1 - keep) * d), W)); out[k] /= np.linalg.norm(out[k])
    rch[n][1] = out; put(oi, out)
    print('%s %s: world yaw swing %.0f..%.0f deg -> x%.2f' % (CLIP, bone, min(sw), max(sw), keep))
lock('Hips', float(kw.get('hips_keep', 0.0)))
lock('Head', HK)
bb = bytes(b); jb = json.dumps(j, separators=(',', ':')).encode(); jb += b' ' * (-len(jb) % 4); bb += b'\0' * (-len(bb) % 4)
out = struct.pack('<III', 0x46546C67, 2, 12 + 8 + len(jb) + 8 + len(bb)) + struct.pack('<II', len(jb), 0x4E4F534A) + jb + struct.pack('<II', len(bb), 0x004E4942) + bb
open(dst, 'wb').write(out)
