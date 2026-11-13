"""out = main clip with (pilot - old) per bone: rotations q_main * inv(q_old) * q_pilot, translations t_main + (t_pilot - t_old).
All three glbs share bone names and key times. Usage: python3 tools/art1/glb_delta_clips.py main.glb old.glb pilot.glb out.glb clip,clip"""
import sys, numpy as np
sys.path.insert(0, __import__('os').path.dirname(__file__))
from glb_add_clips import read, write
M, O, P, OUT, CL = sys.argv[1:6]
def view(j, b, i):
    a = j['accessors'][i]; v = j['bufferViews'][a['bufferView']]; n = {'SCALAR': 1, 'VEC3': 3, 'VEC4': 4}[a['type']]
    assert a['componentType'] == 5126 and 'byteStride' not in v
    off = v.get('byteOffset', 0) + a.get('byteOffset', 0)
    return np.frombuffer(b, dtype='<f4', count=a['count'] * n, offset=off).reshape(a['count'], n), off
def chans(j, b, clip):
    an = [a for a in j['animations'] if a['name'] == clip][0]; out = {}
    for c in an['channels']:
        s = an['samplers'][c['sampler']]
        out[(j['nodes'][c['target']['node']]['name'], c['target']['path'])] = (view(j, b, s['input'])[0], s['output'])
    return out
def qmul(a, b):
    x1, y1, z1, w1 = a.T; x2, y2, z2, w2 = b.T
    return np.stack([w1*x2+x1*w2+y1*z2-z1*y2, w1*y2-x1*z2+y1*w2+z1*x2, w1*z2+x1*y2-y1*x2+z1*w2, w1*w2-x1*x2-y1*y2-z1*z2], 1)
def qinv(a): return a * np.array([-1, -1, -1, 1])
jm, bm = read(M); jo, bo = read(O); jp, bp = read(P)
for clip in CL.split(','):
    cm, co, cp = chans(jm, bm, clip), chans(jo, bo, clip), chans(jp, bp, clip)
    n = 0
    for key, (tp, op) in cp.items():
        if key[1] == 'scale' or key not in co or key not in cm: continue
        to, oo = co[key]; tm, om = cm[key]
        assert len(tp) == len(to) == len(tm) and np.allclose(tp, to) and np.allclose(tp, tm), (clip, key)
        vp = view(jp, bp, op)[0].astype(float); vo = view(jo, bo, oo)[0].astype(float)
        vm, off = view(jm, bm, om); vm = vm.astype(float)
        if key[1] == 'rotation':
            r = qmul(vm, qmul(qinv(vo), vp)); r /= np.linalg.norm(r, axis=1, keepdims=True)
        else:
            r = vm + (vp - vo)
        if np.abs(vp - vo).max() < 1e-6: continue
        bm[off:off + r.size * 4] = r.astype('<f4').tobytes(); n += 1
    print(clip, 'channels changed', n)
write(OUT, jm, bm)
