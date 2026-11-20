"""glb_twosided.py IN.glb OUT.glb MATERIAL : the game's toon shader culls back faces and ignores glTF doubleSided, so a
one-shell coat seen through its open front shows the black inside of the ink shell. This adds a reversed copy of every
triangle of MATERIAL's primitive (same positions, UVs, skin; normals flipped; ink room 0 so the copy draws no line):
the coat's inside shows its own paint. Buffer repacked, unused views dropped."""
import sys, json, struct
import numpy as np
src, out, mat = sys.argv[1:4]
d = open(src, 'rb').read(); jl = struct.unpack('<I', d[12:16])[0]; j = json.loads(d[20:20 + jl]); b = d[20 + jl + 8:]
CT = {5126: np.float32, 5123: np.uint16, 5121: np.uint8, 5125: np.uint32}; NC = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4}
def read(i):
    ac = j['accessors'][i]; bv = j['bufferViews'][ac['bufferView']]; dt = np.dtype(CT[ac['componentType']]); n = NC[ac['type']]
    off = bv.get('byteOffset', 0) + ac.get('byteOffset', 0); st = bv.get('byteStride', dt.itemsize * n)
    raw = np.frombuffer(b, np.uint8, count=st * (ac['count'] - 1) + dt.itemsize * n, offset=off)
    return np.lib.stride_tricks.as_strided(raw, (ac['count'], dt.itemsize * n), (st, 1)).copy().view(dt).reshape(ac['count'], n)
new_views = []   # (accessor index, ndarray)
mi = [k for k, m in enumerate(j['materials']) if m['name'] == mat][0]
for m in j['meshes']:
    for pr in m['primitives']:
        if pr.get('material') != mi: continue
        at = pr['attributes']; nv = j['accessors'][at['POSITION']]['count']
        for k, ai in at.items():
            A = read(ai)
            B = A.copy()
            if k == 'NORMAL': B = -B
            if k == 'COLOR_0': B[:, 3] = 0
            new_views.append((ai, np.concatenate([A, B])))
        I = read(pr['indices']).reshape(-1, 3).astype(np.int64)
        I2 = np.concatenate([I, I[:, ::-1] + nv]).ravel()
        dt = np.uint32 if I2.max() > 65535 else np.uint16
        j['accessors'][pr['indices']]['componentType'] = 5125 if dt == np.uint32 else 5123
        new_views.append((pr['indices'], I2.astype(dt).reshape(-1, 1)))
        print('doubled', m['name'], mat, len(I), '->', len(I2) // 3, 'tris')
# every accessor touched gets its own tightly packed view; then repack all referenced views
for ai, arr in new_views:
    ac = j['accessors'][ai]; ac['count'] = len(arr); ac.pop('byteOffset', None)
    if 'min' in ac: ac['min'] = [float(x) for x in arr.min(0)]; ac['max'] = [float(x) for x in arr.max(0)]
    j['bufferViews'].append({'buffer': 0, 'byteOffset': 0, 'byteLength': arr.nbytes, '_data': arr.tobytes(),
                             **({'target': 34963} if ai in [p['indices'] for m in j['meshes'] for p in m['primitives']] else {'target': 34962})})
    ac['bufferView'] = len(j['bufferViews']) - 1
used = sorted({ac['bufferView'] for ac in j['accessors'] if 'bufferView' in ac} | {im['bufferView'] for im in j.get('images', []) if 'bufferView' in im})
remap = {o: n for n, o in enumerate(used)}; outb = bytearray(); views = []
for o in used:
    v = j['bufferViews'][o]; data = v.pop('_data', None)
    if data is None: data = b[v.get('byteOffset', 0):v.get('byteOffset', 0) + v['byteLength']]
    while len(outb) % 4: outb.append(0)
    v['byteOffset'] = len(outb); v['byteLength'] = len(data); v.pop('byteStride', None) if data is not None and o >= len(j['bufferViews']) - len(new_views) else None
    outb += data; views.append(v)
for ac in j['accessors']:
    if 'bufferView' in ac: ac['bufferView'] = remap[ac['bufferView']]
for im in j.get('images', []):
    if 'bufferView' in im: im['bufferView'] = remap[im['bufferView']]
j['bufferViews'] = views
while len(outb) % 4: outb.append(0)
j['buffers'][0]['byteLength'] = len(outb)
js = json.dumps(j, separators=(',', ':')).encode()
while len(js) % 4: js += b' '
open(out, 'wb').write(struct.pack('<III', 0x46546C67, 2, 28 + len(js) + len(outb)) + struct.pack('<II', len(js), 0x4E4F534A) + js + struct.pack('<II', len(outb), 0x004E4942) + bytes(outb))
print('wrote', out, 28 + len(js) + len(outb))
