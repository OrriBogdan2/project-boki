import bpy,sys
a=sys.argv[sys.argv.index('--')+1:]; src,dst,tris=a[0],a[1],int(a[2])
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
ms=[o for o in bpy.context.scene.objects if o.type=='MESH']
for o in ms:
    n=sum(len(p.vertices)-2 for p in o.data.polygons); print('in tris',n)
    m=o.modifiers.new('d','DECIMATE'); m.ratio=min(1.0,tris/n)
    bpy.context.view_layer.objects.active=o; bpy.ops.object.modifier_apply(modifier='d')
    print('out tris',sum(len(p.vertices)-2 for p in o.data.polygons))
bpy.ops.export_scene.gltf(filepath=dst,export_format='GLB',export_image_format='JPEG',export_jpeg_quality=90)
