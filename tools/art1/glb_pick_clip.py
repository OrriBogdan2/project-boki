"""glb_pick_clip.py <candidate.glb> <clip> <new_name> <tile:int> <out.glb>
Writes a copy of the candidate GLB holding only <clip>, renamed <new_name> and played <tile> times end to end
(loops: the first key of each repeat is dropped because it equals the last key). Feed out.glb to glb_add_clips."""
import struct, sys
sys.path.insert(0, __import__('os').path.dirname(__file__))
from glb_add_clips import read, write

src, clip, name, tile, out = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4]), sys.argv[5]
j, b = read(src)
anim = next(a for a in j['animations'] if a['name'] == clip)
j['animations'] = [anim]
anim['name'] = name
NC = {'SCALAR': 1, 'VEC3': 3, 'VEC4': 4}


def get(ai):
    a = j['accessors'][ai]; v = j['bufferViews'][a['bufferView']]
    assert a['componentType'] == 5126 and 'byteStride' not in v
    n = a['count'] * NC[a['type']]
    off = v.get('byteOffset', 0) + a.get('byteOffset', 0)
    return list(struct.unpack_from('<%df' % n, b, off)), NC[a['type']]


def put(vals, typ, minmax=False):
    global b
    b += b'\0' * (-len(b) % 4)
    j['bufferViews'].append({'buffer': 0, 'byteOffset': len(b), 'byteLength': 4 * len(vals)})
    b += struct.pack('<%df' % len(vals), *vals)
    acc = {'bufferView': len(j['bufferViews']) - 1, 'componentType': 5126, 'count': len(vals) // NC[typ], 'type': typ}
    if minmax:
        acc['min'], acc['max'] = [min(vals)], [max(vals)]
    j['accessors'].append(acc)
    return len(j['accessors']) - 1


if tile > 1:
    L = max(get(s['input'])[0][-1] for s in anim['samplers'])
    for s in anim['samplers']:
        assert s.get('interpolation', 'LINEAR') != 'CUBICSPLINE'
        t, _ = get(s['input']); v, k = get(s['output'])
        if t[-1] < L - 1e-4:            # a short track holds its last key; pad it to the clip end first
            t = t + [L]; v = v + v[-k:]
        T, V = list(t), list(v)
        for r in range(1, tile):
            T += [x + r * L for x in t[1:]]; V += v[k:]
        s['input'] = put(T, 'SCALAR', True)
        s['output'] = put(V, j['accessors'][s['output']]['type'])
j['buffers'][0]['byteLength'] = len(b) + (-len(b) % 4)
write(out, j, b)
print('wrote', out, name, 'tile', tile)
