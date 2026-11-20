"""fish_rot.py IN.glb OUT.glb GX,GY,GZ PITCH YAW [LEN]: the swordfish mesh (rigid on hand.R) turned about the grip G (skeleton
space, the fist) so its bill points d(pitch under level, yaw to the right) in rest space; same shape, same size (LEN rescales)."""
import sys; sys.path.insert(0, __import__('os').path.dirname(__import__('os').path.abspath(__file__)))
import numpy as np, glb_relax as g, glb_add_clips as a
src, out = sys.argv[1:3]; G = np.array([float(x) for x in sys.argv[3].split(',')]); p, y = np.radians(float(sys.argv[4])), np.radians(float(sys.argv[5]))
j, b = a.read(src)
fish = [m for m in j['meshes'] if m['name'] != 'Body.002'][0]
pr = fish['primitives'][0]['attributes']
P, po, ps = g.accessor(j, b, pr['POSITION']); N, no, ns = g.accessor(j, b, pr['NORMAL'])
P = P.astype(float)
c = P.mean(0); u, s, vt = np.linalg.svd(P - c); ax = vt[0]; pj = (P - c) @ ax
tip = P[np.argmax(np.abs(pj))]
if (tip - c) @ ax < 0: ax = -ax
d = np.array([np.cos(p) * np.sin(y), -np.sin(p), -np.cos(p) * np.cos(y)])
v = np.cross(ax, d); s_, c_ = np.linalg.norm(v), ax @ d
K = np.array([[0, -v[2], v[1]], [v[2], 0, -v[0]], [-v[1], v[0], 0]])
R = np.eye(3) + K + K @ K * ((1 - c_) / (s_ ** 2 + 1e-12)) if s_ > 1e-6 else np.eye(3)
print('old bill dir', np.round(ax, 3), 'new', np.round(d, 3), 'len', round(float(np.ptp((P - c) @ ax)), 3))
P2 = (P - G) @ R.T + G
N2 = N.astype(float) @ R.T
for arr, off, st, cnt in ((P2, po, ps, len(P2)), (N2, no, ns, len(N2))):
    for i in range(cnt):
        b[off + i * st: off + i * st + 12] = arr[i].astype(np.float32).tobytes()
ac = j['accessors'][pr['POSITION']]; ac['min'] = [float(x) for x in P2.min(0)]; ac['max'] = [float(x) for x in P2.max(0)]
if len(sys.argv) > 6:      # the bone the fist's vertices ride (the fish rides it too: hand.R's matrix is not the forearm's in the game's frames)
    names = [j['nodes'][x]['name'] for x in j['skins'][0]['joints']]; k = names.index(sys.argv[6])
    J, jo, js = g.accessor(j, b, pr['JOINTS_0']); W, wo, ws = g.accessor(j, b, pr['WEIGHTS_0'])
    for i in range(len(J)):
        b[jo + i * js: jo + i * js + 4 * J.dtype.itemsize] = np.array([k, 0, 0, 0], J.dtype).tobytes()
        b[wo + i * ws: wo + i * ws + 16] = np.array([1, 0, 0, 0], np.float32).tobytes()
    print('fish rides', sys.argv[6])
a.write(out, j, b); print('wrote', out)
