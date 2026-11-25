# inkzero23.py IN.glb OUT.glb MATERIAL[@JOINT:r0:r1]... : ink room 0 (COLOR_0 alpha 0, rgb 1) on every prim of the named materials, so the game's
# ink shell (outline.gdshader ink_mask) is not drawn there. Lace r23: the r17 Meshy bow fist (body-hand17) is near triangle soup
# (2,542 open edges); its back faces' black shell showed through the cracks as a black patch on the bow-grip hand.
# @JOINT:r0:r1 keeps the ink (room 1) within r0 m of that joint's rest position, fading to 0 at r1 (the fist's open wrist end:
# without it the forearm/fist gap shows through).
import sys, numpy as np
sys.path.insert(0, 'tools/art1/hem_r17'); import glbio
src, out = sys.argv[1:3]; mats = {a.split('@')[0]: (a.split('@')[1].split(':') if '@' in a else None) for a in sys.argv[3:]}
j, b = glbio.load(src); b = bytearray(b); n = 0
for me in j['meshes']:
    for p in me['primitives']:
        if j['materials'][p['material']]['name'] not in mats: continue
        P = glbio.acc(j, b, p['attributes']['POSITION']).astype(float); c = len(P); al = np.zeros(c)
        keep = mats[j['materials'][p['material']]['name']]
        if keep:
            jn = [j['nodes'][k]['name'] for k in j['skins'][0]['joints']]
            ib = glbio.acc(j, b, j['skins'][0]['inverseBindMatrices']).reshape(-1, 4, 4)
            q = np.linalg.inv(ib[jn.index(keep[0])].T)[:3, 3]; r0, r1 = float(keep[1]), float(keep[2])
            al = np.clip((r1 - np.linalg.norm(P - q, axis=1)) / (r1 - r0), 0, 1)
        col = np.c_[np.ones((c, 3)), al].astype(np.float32)
        b += b'\0' * ((-len(b)) % 4); j['bufferViews'].append({'buffer': 0, 'byteOffset': len(b), 'byteLength': col.nbytes, 'target': 34962})
        b += col.tobytes(); j['accessors'].append({'bufferView': len(j['bufferViews']) - 1, 'componentType': 5126, 'count': c, 'type': 'VEC4'})
        p['attributes']['COLOR_0'] = len(j['accessors']) - 1; n += c
glbio.save(out, j, b); print('ink room 0 on', n, 'verts ->', out)
