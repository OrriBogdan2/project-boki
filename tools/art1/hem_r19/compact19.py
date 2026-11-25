"""compact19.py IN OUT [material=body-retex]: drop vertices no triangle uses from one primitive (r17 removed the old
left mitten's faces but kept its 890 verts; geo_check counted them as hand_L -> false FLAT). Visible mesh unchanged:
same triangles, same attribute values; only unreferenced rows go and the indices are remapped."""
import sys, collections, numpy as np
sys.path.insert(0, __file__.rsplit('/', 2)[0] + '/hem_r17')
import glbio
src, out = sys.argv[1:3]; matn = sys.argv[3] if len(sys.argv) > 3 else 'body-retex'
j, b = glbio.load(src)
use = collections.Counter(a.get('bufferView') for a in j['accessors'])
for m in j['meshes']:
    for p in m['primitives']:
        if j['materials'][p['material']]['name'] != matn: continue
        assert 'targets' not in p
        I = glbio.acc(j, b, p['indices']).reshape(-1); n = j['accessors'][p['attributes']['POSITION']]['count']
        used = np.zeros(n, bool); used[I] = True; remap = np.cumsum(used) - 1
        print(m['name'], matn, 'verts', n, '->', used.sum())
        for name, ai in list(p['attributes'].items()) + [('indices', p['indices'])]:
            a = j['accessors'][ai]; vi = a['bufferView']
            assert use[vi] == 1 and a.get('byteOffset', 0) == 0, (name, 'shared view')
            arr = glbio.acc(j, b, ai)
            arr = remap[I].astype(arr.dtype).reshape(-1, 1) if name == 'indices' else arr[used]
            b = glbio.replace_view(j, b, vi, np.ascontiguousarray(arr).tobytes())
            a['count'] = int(len(arr) if name != 'indices' else arr.size)
            if 'min' in a and name != 'indices':
                a['min'] = [float(x) for x in arr.min(0)]; a['max'] = [float(x) for x in arr.max(0)]
            if name == 'indices' and 'min' in a: a['min'] = [int(arr.min())]; a['max'] = [int(arr.max())]
glbio.save(out, j, b)
