import bpy, sys, os, math
from mathutils import Vector
out = os.environ.get("OUT_DIR") or "out"
os.makedirs(out, exist_ok=True)
src = "/home/boki/meshy/v95/Grimble/r5/cg3d1115/A.glb"
print("exists", os.path.exists(src), os.path.exists("/home/boki/meshy/cinder-grimble-3d-1115/final/grimble_sheet.jpg"))
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
for o in bpy.data.objects:
    print("OBJ", o.name, o.type, tuple(round(x,3) for x in o.dimensions), len(o.data.vertices) if o.type=='MESH' else '', [m.name for m in o.data.materials] if o.type=='MESH' else '')
for im in bpy.data.images:
    print("IMG", im.name, im.size[:], im.filepath)
    try:
        im.filepath_raw = os.path.join(out, im.name.replace(' ','_')+".png"); im.file_format='PNG'; im.save()
    except Exception as e: print("save fail", e)
