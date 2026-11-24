import bpy,sys,numpy as np
a=sys.argv[sys.argv.index('--')+1:]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=a[0])
ob=[o for o in bpy.data.objects if o.type=='MESH' and o.name!='Icosphere' and len(o.data.polygons)>1000][0]
arm=[o for o in bpy.data.objects if o.type=='ARMATURE'][0]
print('arm',arm.name,'actions',[x.name for x in bpy.data.actions])
me=ob.data
n=len(me.vertices)
E=np.array([e.vertices[:] for e in me.edges])
rest=np.array([v.co[:] for v in me.vertices])
# weld map by position
key=np.round(rest*1e4).astype(np.int64); u,inv=np.unique(key,axis=0,return_inverse=True); inv=inv.ravel()
vgn={g.index:g.name for g in ob.vertex_groups}
W=[sorted([(g.weight,vgn[g.group]) for g in v.groups],reverse=True) for v in me.vertices]
rl=np.linalg.norm(rest[E[:,0]]-rest[E[:,1]],axis=1)
dg=bpy.context.evaluated_depsgraph_get()
for act in bpy.data.actions:
    arm.animation_data_create(); arm.animation_data.action=act
    f0,f1=act.frame_range
    worst=[]
    for f in range(int(f0),int(f1)+1,3):
        bpy.context.scene.frame_set(f); dg.update()
        ev=ob.evaluated_get(dg); m=ev.to_mesh()
        P=np.array([v.co[:] for v in m.vertices]); ev.to_mesh_clear()
        L=np.linalg.norm(P[E[:,0]]-P[E[:,1]],axis=1)
        r=L/np.maximum(rl,1e-6)
        sel=(rl>1e-4)
        idx=np.argsort(-np.where(sel,r,0))[:6]
        worst.append((f,[(round(float(r[i]),1),tuple(np.round(rest[E[i,0]],2)),W[E[i,0]][0][1],round(W[E[i,0]][0][0],2)) for i in idx[:3]], int((r>3).sum())))
    print('ACTION',act.name)
    for w in worst[::4]: print(' ',w)
