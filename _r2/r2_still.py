"""r2_render.py (Cinder round 2, from hybrid-rig-Cinder-1121/tools/vid_render.py): blender -b -P r2_render.py -- RIG.glb OUTDIR
 --anims=a.glb,b.glb,c.glb --tags=,walk,run --views=game,eye,knee,face. Same light/ground/game camera as round 1; adds knee-level
 and face close-up views; GPU Cycles (OptiX/CUDA/HIP/Metal, whatever the worker has). knee/face use stride 3."""
import sys, os, math, bpy, numpy as np
from mathutils import Vector
a = sys.argv[sys.argv.index("--") + 1:]; glb, out = a[0], a[1]; opt = dict(x[2:].split("=", 1) for x in a[2:] if "=" in x)
VIEWS = opt.get("views", "game,eye,knee,face").split(","); ANIMS = opt["anims"].split(","); TAGS = opt.get("tags", "").split(","); STRIDE = opt.get("stride", "")
os.makedirs(out, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=glb); sc = bpy.context.scene
meshes = [o for o in sc.objects if o.type == "MESH"]
print("TRIS", sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in meshes), flush=True)
def hexc(h, s=1.0): return tuple(((int(h[i:i+2], 16) / 255) ** 2.2) * s for i in (0, 2, 4)) + (1,)
sc.render.engine = "CYCLES"; sc.cycles.device = "GPU"
cp = bpy.context.preferences.addons["cycles"].preferences; DEV = "CPU"
for kind in ("OPTIX", "CUDA", "HIP", "METAL", "ONEAPI"):
    try:
        cp.compute_device_type = kind; cp.get_devices()
        g = [d for d in cp.devices if d.type == kind]
        if g:
            for d in cp.devices: d.use = (d.type == kind)
            DEV = kind; break
    except Exception: pass
if DEV == "CPU": sc.cycles.device = "CPU"
print("RENDER DEVICE", DEV, flush=True)
if DEV == "CPU" and "--allow-cpu" not in sys.argv: print("NO GPU: exit (real-GPU renders only)", flush=True); sys.exit(3); sc.cycles.samples = 12; sc.cycles.use_denoising = True
sc.render.resolution_x = 960; sc.render.resolution_y = 1080
sc.render.image_settings.file_format = "JPEG"; sc.render.image_settings.quality = 90
sc.view_settings.view_transform = "Standard"
w = bpy.data.worlds.new("w"); sc.world = w; w.use_nodes = True; nt = w.node_tree
bg = nt.nodes["Background"]; bg.inputs[0].default_value = hexc("b9c4e6"); bg.inputs[1].default_value = 0.5
sky = nt.nodes.new("ShaderNodeBackground"); sky.inputs[0].default_value = hexc("2a3050"); sky.inputs[1].default_value = 1.0
lp = nt.nodes.new("ShaderNodeLightPath"); mx = nt.nodes.new("ShaderNodeMixShader")
nt.links.new(lp.outputs["Is Camera Ray"], mx.inputs[0]); nt.links.new(bg.outputs[0], mx.inputs[1]); nt.links.new(sky.outputs[0], mx.inputs[2])
nt.links.new(mx.outputs[0], nt.nodes["World Output"].inputs[0])
# sun: Godot rot (-55,-35,0) YXZ -> travel dir (0.329,-0.819,-0.470) Godot = (0.329,0.470,-0.819) Blender
L = bpy.data.lights.new("sun", "SUN"); L.energy = 3.2; L.color = hexc("fff1dc")[:3]; L.angle = math.radians(3)
lo = bpy.data.objects.new("sun", L); sc.collection.objects.link(lo)
lo.rotation_euler = Vector((0.329, 0.470, -0.819)).to_track_quat("-Z", "Y").to_euler()
# grass ground
bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, 0)); gp = bpy.context.object
gm = bpy.data.materials.new("grass"); gm.use_nodes = True; n = gm.node_tree.nodes; bs = n["Principled BSDF"]
tc = n.new("ShaderNodeTexCoord"); nz = n.new("ShaderNodeTexNoise"); nz.inputs["Scale"].default_value = 0.6; nz.inputs["Detail"].default_value = 8
cr = n.new("ShaderNodeValToRGB"); cr.color_ramp.elements[0].color = hexc("4a7538"); cr.color_ramp.elements[1].color = hexc("5f8d45")
cr.color_ramp.elements[0].position = 0.35; cr.color_ramp.elements[1].position = 0.65
gm.node_tree.links.new(tc.outputs["Object"], nz.inputs["Vector"]); gm.node_tree.links.new(nz.outputs["Fac"], cr.inputs[0])
gm.node_tree.links.new(cr.outputs[0], bs.inputs["Base Color"]); bs.inputs["Roughness"].default_value = 0.95
gp.data.materials.append(gm)
cam = bpy.data.cameras.new("c"); co = bpy.data.objects.new("c", cam); sc.collection.objects.link(co); sc.camera = co
cam.sensor_fit = "VERTICAL"; cam.sensor_height = 36; cam.clip_end = 400
def bounds():
    dg = bpy.context.evaluated_depsgraph_get(); pts = []
    for o in meshes:
        ev = o.evaluated_get(dg); m = ev.to_mesh(); k = len(m.vertices); c = np.empty(k * 3, np.float32)
        m.vertices.foreach_get("co", c); c = c.reshape(k, 3); M = np.array(ev.matrix_world); pts.append(c @ M[:3, :3].T + M[:3, 3]); ev.to_mesh_clear()
    P = np.concatenate(pts); return P.min(0), P.max(0)
def aim(pos, tgt, span_m, dist):
    co.location = pos; co.rotation_euler = (Vector(tgt) - Vector(pos)).to_track_quat("-Z", "Y").to_euler()
    cam.lens = 18.0 / (span_m * 0.5 / dist)
H = 1.9
mn, mxb = bounds(); cx, cy = (mn[0] + mxb[0]) / 2, (mn[1] + mxb[1]) / 2; top = mxb[2]; sz = 1.9 / max(top - mn[2], 1e-3)
for o in meshes: pass
d = os.path.join(out, "v95"); os.makedirs(d, exist_ok=True); print("HEIGHT", top - mn[2], flush=True)
def rs(nm): sc.render.filepath = os.path.join(d, nm + ".jpg"); bpy.ops.render.render(write_still=True)
Hh = top - mn[2]; f = Hh / 1.9
p = math.radians(66); D = 23.0 * f; tgt = Vector((cx, cy, 0.95 * f)); aim(tgt + Vector((0, -D * math.cos(p), D * math.sin(p))), tgt, 1.55 * f, D); rs("game")
y = math.radians(35); D = 6.5 * f; tgt = Vector((cx, cy, 0.92 * f)); aim(Vector((cx + D * math.sin(y), cy - D * math.cos(y), 1.55 * f)), tgt, 2.25 * f, D); rs("eye")
y = math.radians(-30); D = 5.5 * f; tgt = Vector((cx, cy, 0.85 * f)); aim(Vector((cx + D * math.sin(y), cy - D * math.cos(y), 0.5 * f)), tgt, 2.3 * f, D); rs("knee")
hz = top - 0.2 * f; y = math.radians(20); D = 2.0 * f; tgt = Vector((cx, cy, hz)); aim(Vector((cx + D * math.sin(y), cy - D * math.cos(y), hz + 0.06 * f)), tgt, 0.62 * f, D); rs("face")
print("VID done", flush=True)
