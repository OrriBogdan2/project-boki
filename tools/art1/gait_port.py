#!/usr/bin/env python3
"""gait_port.py SRC.glb DST.glb OUT.glb clip...: put SRC's gait clips on DST's rig (same joints, other leg lengths),
e.g. a judged walk_f/run_f onto an appeal body with longer legs. Rotations carry over; translation keys on bones whose
rest moved become dst_rest + (src - src_rest) * leg ratio (hips height); the hips drop so the lowest foot sits where it
did; time stretches so the planted foot keeps SRC's ground speed (= the archetype's walk_speed/run_speed at rate 1).
Writes through glb_swap.py, so nothing else in DST changes."""
import json, math, os, struct, subprocess, sys

def load(f):
    b = open(f, 'rb').read()
    n = struct.unpack('<I', b[12:16])[0]
    j = json.loads(b[20:20 + n]); o = 20 + n
    return j, b[o + 8:o + 8 + struct.unpack('<I', b[o:o + 4])[0]]

W = {'SCALAR': 1, 'VEC3': 3, 'VEC4': 4}

def acc_read(j, b, ai):
    a = j['accessors'][ai]; v = j['bufferViews'][a['bufferView']]
    s = v.get('byteOffset', 0) + a.get('byteOffset', 0); w = W[a['type']]
    f = struct.unpack_from(f'<{w * a["count"]}f', b, s)
    return [list(f[i:i + w]) for i in range(0, len(f), w)] if w > 1 else list(f)

def qmul(a, b):
    ax, ay, az, aw = a; bx, by, bz, bw = b
    return [aw*bx+ax*bw+ay*bz-az*by, aw*by-ax*bz+ay*bw+az*bx, aw*bz+ax*by-ay*bx+az*bw, aw*bw-ax*bx-ay*by-az*bz]

def qrot(q, v):
    p = qmul(qmul(q, [v[0], v[1], v[2], 0.0]), [-q[0], -q[1], -q[2], q[3]]); return p[:3]

def lerp(a, b, t, quat):
    if not quat: return [x + (y - x) * t for x, y in zip(a, b)]
    if sum(x*y for x, y in zip(a, b)) < 0: b = [-y for y in b]
    m = [x + (y - x) * t for x, y in zip(a, b)]; n = math.sqrt(sum(x*x for x in m)); return [x / n for x in m]

def sample(times, vals, t, quat):
    if t <= times[0]: return vals[0]
    for i in range(1, len(times)):
        if t <= times[i]:
            u = (t - times[i-1]) / max(times[i] - times[i-1], 1e-9); return lerp(vals[i-1], vals[i], u, quat)
    return vals[-1]

def tracks(j, b, name):
    A = next(a for a in j['animations'] if a['name'] == name); out = {}
    for c in A['channels']:
        s = A['samplers'][c['sampler']]
        out[(c['target']['node'], c['target']['path'])] = (acc_read(j, b, s['input']), acc_read(j, b, s['output']))
    return out

def world(j, tr, t, names):
    par = {}
    for i, n in enumerate(j['nodes']):
        for c in n.get('children', []): par[c] = i
    idx = {n.get('name'): i for i, n in enumerate(j['nodes'])}
    def local(i):
        n = j['nodes'][i]
        T = tr.get((i, 'translation')); R = tr.get((i, 'rotation'))
        tt = sample(*T, t, False) if T else n.get('translation', [0, 0, 0])
        rr = sample(*R, t, True) if R else n.get('rotation', [0, 0, 0, 1])
        return tt, rr, n.get('scale', [1, 1, 1])
    def wpos(i):
        chain = []
        while i is not None: chain.append(i); i = par.get(i)
        P, Q, S = [0, 0, 0], [0, 0, 0, 1], [1, 1, 1]
        for k in reversed(chain):
            tt, rr, ss = local(k)
            P = [p + d for p, d in zip(P, qrot(Q, [tt[a] * S[a] for a in range(3)]))]
            Q = qmul(Q, rr); S = [S[a] * ss[a] for a in range(3)]
        return P
    return {nm: wpos(idx[nm]) for nm in names}

def ground_speed(j, b, clip, feet=('foot.L', 'foot.R'), n=96):
    """Mean horizontal speed of each foot over the frames it is lowest (the planted half)."""
    tr = tracks(j, b, clip); end = max(v[0][-1] for v in tr.values()); t0 = min(v[0][0] for v in tr.values())
    ts = [t0 + (end - t0) * i / n for i in range(n + 1)]
    P = [world(j, tr, t, feet) for t in ts]
    out = []
    for f in feet:
        ys = [p[f][1] for p in P]; lo = sorted(ys)[len(ys) // 4]
        sp = []
        for i in range(n):
            if ys[i] <= lo and ys[i+1] <= lo:
                dx = P[i+1][f][0] - P[i][f][0]; dz = P[i+1][f][2] - P[i][f][2]
                sp.append(math.hypot(dx, dz) / (ts[i+1] - ts[i]))
        out.append(sum(sp) / max(len(sp), 1))
    return end - t0, out


def save(f, j, b):
    js = json.dumps(j, separators=(',', ':')).encode(); js += b' ' * (-len(js) % 4); b = bytes(b) + b'\0' * (-len(b) % 4)
    open(f, 'wb').write(struct.pack('<III', 0x46546C67, 2, 28 + len(js) + len(b)) + struct.pack('<II', len(js), 0x4E4F534A) + js + struct.pack('<II', len(b), 0x004E4942) + b)

def write(j, b, ai, rows):
    a = j['accessors'][ai]; v = j['bufferViews'][a['bufferView']]; s = v.get('byteOffset', 0) + a.get('byteOffset', 0)
    flat = [x for r in rows for x in (r if isinstance(r, list) else [r])]; struct.pack_into(f'<{len(flat)}f', b, s, *flat)

def rest(j):
    return {n.get('name'): n.get('translation', [0, 0, 0]) for n in j['nodes']}

def foot_low(j, b, clip):
    tr = tracks(j, b, clip); end = max(v[0][-1] for v in tr.values()); t0 = min(v[0][0] for v in tr.values())
    return min(min(p[1] for p in world(j, tr, t0 + (end - t0) * i / 48, ('foot.L', 'foot.R')).values()) for i in range(49))

def main():
    src, dst, out, clips = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4:]
    S, SB = load(src); D, DB = load(dst); SB = bytearray(SB)
    rs, rd = rest(S), rest(D)
    ratio = rd['hips'][1] / rs['hips'][1]
    sidx = {n.get('name'): i for i, n in enumerate(S['nodes'])}
    lows = {c: foot_low(S, SB, c) for c in clips}
    speeds = {c: ground_speed(S, SB, c)[1] for c in clips}
    for c in clips:
        A = next(a for a in S['animations'] if a['name'] == c); done = set()
        for ch in A['channels']:
            nm = S['nodes'][ch['target']['node']]['name']; sm = A['samplers'][ch['sampler']]
            if ch['target']['path'] != 'translation' or nm not in rd or max(abs(x - y) for x, y in zip(rs[nm], rd[nm])) < 1e-4: continue
            if sm['output'] in done: continue
            done.add(sm['output'])
            vals = acc_read(S, SB, sm['output'])
            write(S, SB, sm['output'], [[rd[nm][k] + (v[k] - rs[nm][k]) * ratio for k in range(3)] for v in vals])
        # rest the source rig on dst's rest translations so FK below measures the new body
    for n in S['nodes']:
        if n.get('name') in rd and 'translation' in n: n['translation'] = rd[n['name']]
    hips = sidx['hips']
    for c in clips:
        A = next(a for a in S['animations'] if a['name'] == c)
        lift = lows[c] - foot_low(S, SB, c)
        tsm = next(A['samplers'][ch['sampler']] for ch in A['channels'] if ch['target'] == {'node': hips, 'path': 'translation'})
        write(S, SB, tsm['output'], [[v[0], v[1] + lift, v[2]] for v in acc_read(S, SB, tsm['output'])])
        new = ground_speed(S, SB, c)[1]
        k = (sum(new) / 2) / (sum(speeds[c]) / 2)
        for ai in {sm['input'] for sm in A['samplers']}:
            ts = [t * k for t in acc_read(S, SB, ai)]; write(S, SB, ai, ts)
            S['accessors'][ai]['min'], S['accessors'][ai]['max'] = [min(ts)], [max(ts)]
        print(c, 'ratio %.3f lift %+.3f m stretch x%.3f speed src %s new %s' % (ratio, lift, k, [round(x, 2) for x in speeds[c]], [round(x, 2) for x in ground_speed(S, SB, c)[1]]))
    tmp = out + '.src.glb'
    save(tmp, S, SB)
    subprocess.run([sys.executable, os.path.join(os.path.dirname(__file__), 'glb_swap.py'), dst, tmp, out] + [f'{c}:{c}' for c in clips], check=True)
    os.remove(tmp)

main()
