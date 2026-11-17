#!/usr/bin/env python3
"""glb_swap.py DST.glb SRC.glb OUT.glb src_anim:dst_anim[:loop] [...]
Replace animations in DST (a game .glb) with animations from SRC (same joint names, same rest TRS), touching
nothing else: channels map by node name, times shift to start at 0, ':loop' eases the last LOOP_KEYS keys
of every track into its first so the loop closes exactly, the BIN is compacted (only referenced views)."""
import json, struct, sys

LOOP_KEYS = 4   # keys at the end of a loop eased into the first key (4 = 0.17 s at 24 fps)


def load(f):
    b = open(f, 'rb').read()
    n = struct.unpack('<I', b[12:16])[0]
    j = json.loads(b[20:20 + n])
    o = 20 + n
    return j, b[o + 8:o + 8 + struct.unpack('<I', b[o:o + 4])[0]]


def view_bytes(j, b, acc):
    v = j['bufferViews'][acc['bufferView']]
    s = v.get('byteOffset', 0) + acc.get('byteOffset', 0)
    w = {'SCALAR': 1, 'VEC3': 3, 'VEC4': 4}[acc['type']] * 4
    assert acc['componentType'] == 5126 and v.get('byteStride', w) == w
    return bytearray(b[s:s + w * acc['count']])


def close_loop(data, width):
    v = list(struct.unpack(f'<{len(data) // 4}f', data))
    keys = [v[i:i + width] for i in range(0, len(v), width)]
    first = keys[0]
    for i in range(min(LOOP_KEYS, len(keys) - 1)):
        k, w = len(keys) - LOOP_KEYS + i, (i + 1) / LOOP_KEYS
        cur = keys[k]
        sign = -1.0 if width == 4 and sum(a * b for a, b in zip(cur, first)) < 0 else 1.0
        mix = [a * (1 - w) + sign * b * w for a, b in zip(cur, first)]
        if width == 4:
            norm = sum(x * x for x in mix) ** 0.5
            mix = [x / norm for x in mix]
        keys[k] = mix
    return bytearray(struct.pack(f'<{len(v)}f', *[x for key in keys for x in key]))


def main():
    dst, src, out, pairs = sys.argv[1], sys.argv[2], sys.argv[3], [p.split(':') for p in sys.argv[4:]]
    D, DB = load(dst)
    S, SB = load(src)
    dnode = {n.get('name'): i for i, n in enumerate(D['nodes'])}
    new = bytearray()
    for sa, da, *opt in pairs:
        A = next(a for a in S['animations'] if a['name'] == sa)
        old = next(i for i, a in enumerate(D['animations']) if a['name'] == da)
        t0 = min(S['accessors'][s['input']]['min'][0] for s in A['samplers'])
        samplers, channels, seen = [], [], {}
        for c in A['channels']:
            sm = A['samplers'][c['sampler']]
            ids = []
            for k in ('input', 'output'):
                if sm[k] in seen:
                    ids.append(seen[sm[k]])
                    continue
                acc = dict(S['accessors'][sm[k]])
                data = view_bytes(S, SB, acc)
                if k == 'input':
                    ts = [x - t0 for x in struct.unpack(f'<{acc["count"]}f', data)]
                    data = bytearray(struct.pack(f'<{len(ts)}f', *ts))
                    acc['min'], acc['max'] = [min(ts)], [max(ts)]
                elif opt == ['loop']:
                    data = close_loop(data, {'VEC3': 3, 'VEC4': 4}[acc['type']])
                D['bufferViews'].append({'buffer': 0, 'byteOffset': len(DB) + len(new), 'byteLength': len(data)})
                new += data
                acc.pop('byteOffset', None)
                acc['bufferView'] = len(D['bufferViews']) - 1
                D['accessors'].append(acc)
                ids.append(len(D['accessors']) - 1)
                seen[sm[k]] = ids[-1]
            samplers.append({'input': ids[0], 'output': ids[1], 'interpolation': sm.get('interpolation', 'LINEAR')})
            node = dnode[S['nodes'][c['target']['node']]['name']]
            channels.append({'sampler': len(samplers) - 1, 'target': {'node': node, 'path': c['target']['path']}})
        D['animations'][old] = {'name': da, 'channels': channels, 'samplers': samplers}
        print('SWAP', sa, '->', da, len(channels), 'channels', D['accessors'][samplers[0]['input']]['count'], 'keys')
    blob = bytes(DB) + bytes(new)
    # compact: keep only accessors the file still uses, then only their views (plus image views)
    used_acc = set()
    for m in D.get('meshes', []):
        for p in m['primitives']:
            used_acc |= set(p['attributes'].values()) | ({p['indices']} if 'indices' in p else set())
            for t in p.get('targets', []):
                used_acc |= set(t.values())
    for s in D.get('skins', []):
        if 'inverseBindMatrices' in s:
            used_acc.add(s['inverseBindMatrices'])
    for a in D['animations']:
        for s in a['samplers']:
            used_acc |= {s['input'], s['output']}
    amap = {o: n for n, o in enumerate(sorted(used_acc))}
    image_views = {im['bufferView'] for im in D.get('images', []) if 'bufferView' in im}
    used_views = sorted({D['accessors'][a]['bufferView'] for a in used_acc} | image_views)
    vmap, outb, views = {}, bytearray(), []
    for o in used_views:
        v = dict(D['bufferViews'][o])
        s = v.get('byteOffset', 0)
        outb += b'\0' * (-len(outb) % 4)
        v['byteOffset'] = len(outb)
        outb += blob[s:s + v['byteLength']]
        vmap[o] = len(views)
        views.append(v)
    accs = []
    for o in sorted(used_acc):
        a = dict(D['accessors'][o]); a['bufferView'] = vmap[a['bufferView']]; accs.append(a)
    D['accessors'], D['bufferViews'] = accs, views
    for im in D.get('images', []):
        if 'bufferView' in im:
            im['bufferView'] = vmap[im['bufferView']]
    for m in D.get('meshes', []):
        for p in m['primitives']:
            p['attributes'] = {k: amap[v] for k, v in p['attributes'].items()}
            if 'indices' in p:
                p['indices'] = amap[p['indices']]
            if 'targets' in p:
                p['targets'] = [{k: amap[v] for k, v in t.items()} for t in p['targets']]
    for s in D.get('skins', []):
        if 'inverseBindMatrices' in s:
            s['inverseBindMatrices'] = amap[s['inverseBindMatrices']]
    for a in D['animations']:
        for s in a['samplers']:
            s['input'], s['output'] = amap[s['input']], amap[s['output']]
    outb += b'\0' * (-len(outb) % 4)
    D['buffers'][0]['byteLength'] = len(outb)
    js = json.dumps(D, separators=(',', ':')).encode()
    js += b' ' * (-len(js) % 4)
    total = 12 + 8 + len(js) + 8 + len(outb)
    with open(out, 'wb') as f:
        f.write(struct.pack('<III', 0x46546C67, 2, total) + struct.pack('<I', len(js)) + b'JSON' + js
                + struct.pack('<I', len(outb)) + b'BIN\0' + outb)
    print('WROTE', out, total, 'bytes')


main()
