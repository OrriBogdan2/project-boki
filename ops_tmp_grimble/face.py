import bpy, sys, os, math, shutil
from mathutils import Vector
out = "out"; os.makedirs(out, exist_ok=True)

src = os.environ.get("SRC","/home/boki/meshy/v95/Grimble/r5/cg3d1115/A.glb")
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
ob = [o for o in bpy.data.objects if o.type=='MESH'][0]
bb = [ob.matrix_world @ Vector(c) for c in ob.bound_box]
mn = Vector((min(v.x for v in bb),min(v.y for v in bb),min(v.z for v in bb)))
mx = Vector((max(v.x for v in bb),max(v.y for v in bb),max(v.z for v in bb)))
print("BBOX", tuple(mn), tuple(mx))
sc = bpy.context.scene
sc.render.engine='BLENDER_WORKBENCH'
sc.display.shading.light='FLAT'; sc.display.shading.color_type='TEXTURE'
sc.render.resolution_x=1000; sc.render.resolution_y=1000
sc.render.image_settings.file_format='JPEG'
sc.world = bpy.data.worlds.new("w"); sc.world.color=(0.5,0.5,0.5)
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("c")); sc.collection.objects.link(cam); sc.camera=cam
cam.data.type='ORTHO'
ctr = (mn+mx)/2
def shot(name, az, center, scale):
    cam.data.ortho_scale = scale
    d = 6
    # az 0 => camera at -Y looking +Y
    pos = Vector((center.x + d*math.sin(az), center.y - d*math.cos(az), center.z))
    cam.location = pos
    cam.rotation_euler = (center - pos).to_track_quat('-Z','Y').to_euler()
    sc.render.filepath = f"{out}/{name}.jpg"
    bpy.ops.render.render(write_still=True)

fc = Vector((0,0,0.30))
for a in (-60,-35,0,35,60):
    shot(f"face_{a}", math.radians(a), fc, 0.5)
