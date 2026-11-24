"""skirtex.py IN.glb OUT.glb TEX.png : point the skirt-meshy and skirt-liner materials at a new base colour (a Meshy
retexture of the same gen with enable_original_uv, so the UVs match). Texture only, geometry untouched."""
import bpy, sys
A = sys.argv[sys.argv.index('--') + 1:]; IN, OUT, TEX = A[:3]
bpy.ops.wm.read_factory_settings(use_empty=True); bpy.ops.import_scene.gltf(filepath=IN)
img = bpy.data.images.load(TEX); img.scale(2048, 2048); img.name = 'r10_skirt'
for m in bpy.data.materials:
    if m.name.startswith('skirt-') and m.use_nodes:
        for n in m.node_tree.nodes:
            if n.type == 'TEX_IMAGE': n.image = img; print('tex ->', m.name)
bpy.ops.export_scene.gltf(filepath=OUT, export_format='GLB', export_animation_mode='ACTIONS', export_apply=False, export_skins=True, export_morph=False, export_image_format='JPEG')
