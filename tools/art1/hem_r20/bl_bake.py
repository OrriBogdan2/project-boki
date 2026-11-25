# blender -b -P bl_bake.py -- BGLB MASK.npz OUT.glb target_tris texsize
import bpy,sys,numpy as np,bmesh
a=sys.argv[sys.argv.index('--')+1:]; glb,mk,out,tt,ts=a[0],a[1],a[2],int(a[3]),int(a[4])
bpy.ops.wm.read_factory_settings(use_empty=True); bpy.ops.import_scene.gltf(filepath=glb)
ob=[o for o in bpy.context.scene.objects if o.type=='MESH'][0]; me=ob.data
fm=np.load(mk)['fm']; assert len(me.polygons)==len(fm)
bm=bmesh.new(); bm.from_mesh(me); bm.faces.ensure_lookup_table()
bmesh.ops.delete(bm,geom=[f for f in bm.faces if not fm[f.index]],context='FACES')
bmesh.ops.remove_doubles(bm,verts=bm.verts,dist=1e-5)
# drop tiny loose islands (< 30 faces)
bm.faces.ensure_lookup_table(); seen=set(); drop=[]
for f in bm.faces:
    if f in seen: continue
    st=[f]; isl=[]; seen.add(f)
    while st:
        g=st.pop(); isl.append(g)
        for e in g.edges:
            for h in e.link_faces:
                if h not in seen: seen.add(h); st.append(h)
    if len(isl)<30: drop+=isl
bmesh.ops.delete(bm,geom=drop,context='FACES'); print('dropped small-island faces',len(drop))
bm.to_mesh(me); bm.free()
for o in list(bpy.context.scene.objects):
    if o is not ob: bpy.data.objects.remove(o)
bpy.context.view_layer.objects.active=ob; ob.select_set(True)
n=len(me.polygons)
m=ob.modifiers.new('d','DECIMATE'); m.ratio=min(1,tt/n); m.use_collapse_triangulate=True
bpy.ops.object.modifier_apply(modifier='d'); print('tris',n,'->',len(ob.data.polygons))
src_uv=me.uv_layers[0].name
nu=me.uv_layers.new(name='bake'); me.uv_layers.active=nu
bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.uv.smart_project(angle_limit=1.15,island_margin=0.004); bpy.ops.object.mode_set(mode='OBJECT')
img=bpy.data.images.new('leg_bake',ts,ts); mat=ob.active_material; nt=mat.node_tree
srcimg=[n for n in nt.nodes if n.type=='TEX_IMAGE' and n.image and 'base' in (n.image.name+n.label).lower()] or [n for n in nt.nodes if n.type=='TEX_IMAGE']
src=srcimg[0]; print('src tex',src.image.name,src.image.size[:])
uvn=nt.nodes.new('ShaderNodeUVMap'); uvn.uv_map=src_uv; nt.links.new(uvn.outputs[0],src.inputs[0])
em=nt.nodes.new('ShaderNodeEmission'); outn=[n for n in nt.nodes if n.type=='OUTPUT_MATERIAL'][0]
nt.links.new(src.outputs[0],em.inputs[0]); nt.links.new(em.outputs[0],outn.inputs[0])
tn=nt.nodes.new('ShaderNodeTexImage'); tn.image=img; nt.nodes.active=tn
sc=bpy.context.scene; sc.render.engine='CYCLES'; sc.cycles.samples=1; sc.cycles.device='CPU'
sc.render.bake.margin=8
uvb=nt.nodes.new('ShaderNodeUVMap'); uvb.uv_map='bake'; nt.links.new(uvb.outputs[0],tn.inputs[0])
bpy.ops.object.bake(type='EMIT')
img.filepath_raw=out.replace('.glb','_tex.png'); img.file_format='PNG'; img.save()
# rebuild a clean material: baked tex on 'bake' UV, matte
for l in list(nt.links): nt.links.remove(l)
for nd in list(nt.nodes):
    if nd not in (tn,outn): nt.nodes.remove(nd)
bsdf=nt.nodes.new('ShaderNodeBsdfPrincipled'); bsdf.inputs['Roughness'].default_value=0.8; bsdf.inputs['Metallic'].default_value=0
nt.links.new(tn.outputs[0],bsdf.inputs['Base Color']); nt.links.new(bsdf.outputs[0],outn.inputs[0])
me.uv_layers.remove(me.uv_layers[src_uv]); mat.name='leg-meshy'
bpy.ops.export_scene.gltf(filepath=out,export_format='GLB',use_selection=True,export_image_format='JPEG',export_jpeg_quality=90)
