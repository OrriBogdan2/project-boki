import bpy,sys,numpy as np
a=sys.argv[sys.argv.index('--')+1:]; G,clip,fr=a[0],a[1],int(a[2])
bpy.ops.wm.read_factory_settings(use_empty=True); bpy.ops.import_scene.gltf(filepath=G)
arm=[o for o in bpy.data.objects if o.type=='ARMATURE'][0]; ob={o.name:o for o in bpy.data.objects if o.type=='MESH'}
acts={x.name:x for x in bpy.data.actions}; arm.animation_data.action=acts[[n for n in acts if n.startswith(clip)][0]]
bpy.context.scene.frame_set(fr)
def ev(o):
    dg=bpy.context.evaluated_depsgraph_get(); e=o.evaluated_get(dg); me=e.to_mesh()
    co=np.array([o.matrix_world@v.co for v in me.vertices]); mats=[e.material_slots[p.material_index].material.name if e.material_slots else '' for p in me.polygons]
    vm={}
    for p,mn in zip(me.polygons,mats):
        for vi in p.vertices: vm[vi]=mn
    e.to_mesh_clear(); return co,np.array([vm.get(i,'') for i in range(len(co))])
sk,skm=ev(ob['Skirt']); bow,_=ev(ob['Bow'])
tl=sk[skm=='thigh-liner']
D=np.linalg.norm(bow[:,None,:]-tl[None,:,:],axis=2); i=D.argmin(1); d=D.min(1)
o=np.argsort(d)[:5]
for k in o: print('bow v z(up)=%.3f x=%.3f dist to liner %.3f cm, liner pt z=%.3f'%(bow[k,2],bow[k,0],d[k]*100,tl[i[k],2]))
print('liner z range', tl[:,2].min().round(3), tl[:,2].max().round(3))
