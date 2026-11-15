"""Game-ready a raw Meshy GLB: bake the base colour onto a low-poly copy, normalise scale/feet/facing, export.

Run:  blender -b -P tools/blender/meshy_gameready.py -- <src.glb> <out_dir> <out_name> <size_class> [tris] [flip]
Writes <out_dir>/<out_name>.glb (mesh + UV, no materials, feet on y=0, front toward -Z, Y up),
<out_dir>/<out_name>_atlas.webp (1024 lossy baked colour) and <out_dir>/<out_name>.json (dimensions for the frame row).
size_class: small | medium | large (sets the on-screen size). flip=1 (default) turns the model 180 deg: Meshy fronts face +Z.
"""
import bpy, sys, os, json, math
from mathutils import Vector

a = sys.argv[sys.argv.index('--') + 1:]
src, out_dir, name, size_class = a[0], a[1], a[2], a[3]
tris_target = int(a[4]) if len(a) > 4 else 8000
flip = (a[5] != '0') if len(a) > 5 else True
SPAN = {"small": 0.55, "medium": 0.7, "large": 0.9}[size_class]   # metres: max(height, 0.7 * length)
TEX = 1024

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
meshes = [o for o in bpy.data.objects if o.type == 'MESH']
bpy.ops.object.select_all(action='DESELECT')
for o in meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
if len(meshes) > 1:
    bpy.ops.object.join()
high = bpy.context.view_layer.objects.active
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
high.name = "high"
high_tris = sum(len(p.vertices) - 2 for p in high.data.polygons)

# the base colour image of the high mesh (Meshy: Principled Base Color <- Image Texture)
base_img = None
for mat in high.data.materials:
    if mat and mat.use_nodes:
        for n in mat.node_tree.nodes:
            if n.type == 'BSDF_PRINCIPLED':
                l = n.inputs['Base Color'].links
                if l and l[0].from_node.type == 'TEX_IMAGE':
                    base_img = l[0].from_node.image
assert base_img is not None, "no base colour image"

# low-poly copy: collapse, then a fresh clean UV unwrap (Meshy's islands are shredded by the collapse)
low = high.copy(); low.data = high.data.copy(); low.name = "low"
bpy.context.collection.objects.link(low)
low.data.materials.clear()
bpy.ops.object.select_all(action='DESELECT')
bpy.context.view_layer.objects.active = low; low.select_set(True)
d = low.modifiers.new("dec", 'DECIMATE'); d.ratio = min(1.0, tris_target / max(high_tris, 1)); d.use_collapse_triangulate = True
bpy.ops.object.modifier_apply(modifier="dec")
while len(low.data.uv_layers) > 0:
    low.data.uv_layers.remove(low.data.uv_layers[0])
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.004)
bpy.ops.object.mode_set(mode='OBJECT')
bpy.ops.object.shade_smooth()

# bake target
img = bpy.data.images.new("atlas", TEX, TEX, alpha=False)
mat = bpy.data.materials.new("boki_coat"); mat.use_nodes = True
nt = mat.node_tree
tn = nt.nodes.new('ShaderNodeTexImage'); tn.image = img
nt.nodes.active = tn
low.data.materials.append(mat)

sc = bpy.context.scene
sc.render.engine = 'CYCLES'; sc.cycles.device = 'CPU'; sc.cycles.samples = 1; sc.render.threads_mode = 'FIXED'; sc.render.threads = 2
sc.cycles.use_denoising = False
bpy.ops.object.select_all(action='DESELECT')
high.select_set(True); low.select_set(True)
bpy.context.view_layer.objects.active = low
bpy.ops.object.bake(type='DIFFUSE', pass_filter={'COLOR'}, use_selected_to_active=True, cage_extrusion=0.04,
                    max_ray_distance=0.12, margin=6, margin_type='EXTEND')

# normalise: front toward -Z in the game (Blender: toward +Y after the exporter's axis swap), feet at 0, centred
bpy.ops.object.select_all(action='DESELECT')
high.select_set(True); bpy.ops.object.delete()
low.select_set(True); bpy.context.view_layer.objects.active = low
if flip:
    low.rotation_euler[2] = math.pi
    bpy.ops.object.transform_apply(rotation=True)
vs = [low.matrix_world @ v.co for v in low.data.vertices]
mn = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
mx = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
H = mx.z - mn.z; L = max(mx.x - mn.x, mx.y - mn.y)
s = SPAN / max(H, 0.7 * L)
for v in low.data.vertices:
    v.co = Vector(((v.co.x - (mn.x + mx.x) / 2) * s, (v.co.y - (mn.y + mx.y) / 2) * s, (v.co.z - mn.z) * s))
low.data.update()
tris = sum(len(p.vertices) - 2 for p in low.data.polygons)

# the atlas as webp
os.makedirs(out_dir, exist_ok=True)
img.file_format = 'WEBP'
sc.render.image_settings.file_format = 'WEBP'; sc.render.image_settings.quality = 82
img.save_render(os.path.join(out_dir, name + "_atlas.webp"), scene=sc)

# frame facts (game space: x right, y up, z back; front = -z)
vs = [v.co for v in low.data.vertices]
ys = [v.z for v in vs]; xs = [v.x for v in vs]; zs = [-v.y for v in vs]   # export maps blender -y to +z; front is blender +y -> game -z
res = {"tris": tris, "high_tris": high_tris, "height": round(max(ys), 3), "half_w": round(max(abs(x) for x in xs), 3),
       "front": round(min(zs), 3), "back": round(max(zs), 3), "scale": round(s, 4)}
front_third = [v for v in vs if -v.y < min(zs) * 0.3]
res["head_y"] = round(max((v.z for v in front_third), default=max(ys)), 3)
# palette from the baked pixels: body = mean, belly = the lightest tenth, glow = the most vivid few percent
import numpy as np, colorsys
px = np.array(img.pixels[:]).reshape(-1, 4)[:, :3]
px = px[px.sum(axis=1) > 0.003]
if len(px) > 50:
    px = px[::max(1, len(px) // 40000)]
    def hexc(c):
        c = np.clip(np.power(c, 1 / 2.2), 0, 1)     # baked pixels are linear
        return "#%02x%02x%02x" % tuple(int(round(v * 255)) for v in c)
    lum = px.mean(axis=1)
    hsv = np.array([colorsys.rgb_to_hsv(*c) for c in np.power(px, 1 / 2.2)])
    vivid = hsv[:, 1] * hsv[:, 2]
    res["colors"] = {"body": hexc(px.mean(axis=0)),
                     "belly": hexc(px[lum >= np.quantile(lum, 0.9)].mean(axis=0)),
                     "glow": hexc(px[vivid >= np.quantile(vivid, 0.97)].mean(axis=0))}
json.dump(res, open(os.path.join(out_dir, name + ".json"), "w"))

bpy.ops.object.select_all(action='DESELECT'); low.select_set(True)
low.data.materials.clear()
bpy.ops.export_scene.gltf(filepath=os.path.join(out_dir, name + ".glb"), export_format='GLB', use_selection=True,
                          export_materials='NONE', export_yup=True, export_apply=True)
print("RESULT", name, json.dumps(res))
