# blender -b -P bl_prep.py -- IN.glb OUT.glb target_tris texsize : weld, drop tiny islands, decimate (UV kept), base colour resized, matte
import bpy,sys,bmesh
a=sys.argv[sys.argv.index('--')+1:]; src,out,tt,ts=a[0],a[1],int(a[2]),int(a[3])
bpy.ops.wm.read_factory_settings(use_empty=True); bpy.ops.import_scene.gltf(filepath=src)
obs=[o for o in bpy.context.scene.objects if o.type=='MESH']
for o in bpy.context.scene.objects: o.select_set(o in obs)
bpy.context.view_layer.objects.active=obs[0]
if len(obs)>1: bpy.ops.object.join()
ob=bpy.context.view_layer.objects.active; bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
me=ob.data; bm=bmesh.new(); bm.from_mesh(me); bmesh.ops.remove_doubles(bm,verts=bm.verts,dist=1e-5)
bm.faces.ensure_lookup_table(); seen=set(); drop=[]
for f in bm.faces:
    if f in seen: continue
    st=[f]; isl=[]; seen.add(f)
    while st:
        g=st.pop(); isl.append(g)
        for e in g.edges:
            for h in e.link_faces:
                if h not in seen: seen.add(h); st.append(h)
    if len(isl)<40: drop+=isl
bmesh.ops.delete(bm,geom=drop,context='FACES'); print('dropped small-island faces',len(drop)); bm.to_mesh(me); bm.free()
n=len(me.polygons); m=ob.modifiers.new('d','DECIMATE'); m.ratio=min(1,tt/n); m.use_collapse_triangulate=True
bpy.ops.object.modifier_apply(modifier='d'); print('tris',n,'->',len(ob.data.polygons))
for mat in me.materials:
    for nd in mat.node_tree.nodes:
        if nd.type=='TEX_IMAGE' and nd.image and nd.image.size[0]>ts: nd.image.scale(ts,ts)
        if nd.type=='BSDF_PRINCIPLED': nd.inputs['Roughness'].default_value=0.9; nd.inputs['Metallic'].default_value=0
    # base colour only (drop normal/metal-rough maps: the game skirt material is matte base colour)
    nt=mat.node_tree; bs=[x for x in nt.nodes if x.type=='BSDF_PRINCIPLED'][0]
    for inp in ('Metallic','Roughness','Normal'):
        for l in list(bs.inputs[inp].links): nt.links.remove(l)
for o in list(bpy.context.scene.objects):
    if o is not ob: bpy.data.objects.remove(o)
bpy.ops.export_scene.gltf(filepath=out,export_format='GLB',use_selection=False,export_image_format='JPEG',export_jpeg_quality=90)
