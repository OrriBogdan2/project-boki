"""merge_hand.py IN.glb OUT.glb: body weights: hand.X -> forearm.X (the game's hand matrix differs from the forearm's in the
procedural frames; main's hand-made sleeve is forearm-only), written back. Fish mesh untouched."""
import sys; sys.path.insert(0, __import__('os').path.dirname(__import__('os').path.abspath(__file__)))
import numpy as np, glb_relax as g, glb_add_clips as a
j,b=a.read(sys.argv[1]); names=[j['nodes'][x]['name'] for x in j['skins'][0]['joints']]
sm=g.skinned(j,b); body=max(sm,key=lambda k:sum(len(p['pos']) for p in sm[k]))
rest,w,maps=g.weld(sm[body],len(names)); tris=g.triangles(sm[body],maps)
for s in 'RL':
    h,f=names.index('hand.'+s),names.index('forearm.'+s); w[:,f]+=w[:,h]; w[:,h]=0
w/=w.sum(1,keepdims=True)
g.store(b,sm[body],w,maps,tris); a.write(sys.argv[2],j,b); print('ok')
