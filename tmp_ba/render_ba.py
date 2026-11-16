"""blender -b --factory-startup -P render_ba.py -- HUNTER OUTDIR OLD.glb NEW.glb [res_h] [samples]
Per glb: REST pose, ortho cameras (front az0, three-quarter az40), same neutral studio light as v95/_tools/a1_render.py.
Writes OUTDIR/HUNTER_{old,new}_{front,tq}.png and OUTDIR/HUNTER_meta.json (bbox size, ortho scale, tri count) so the
sheet script can put both at one px-per-metre scale with feet aligned."""
import sys, math, json, os, bpy, hashlib
from mathutils import Vector
a = sys.argv[sys.argv.index("--") + 1:]
hun, outd, files = a[0], a[1], {"old": a[2], "new": a[3]}
res_h = int(a[4]) if len(a) > 4 else 1400
samples = int(a[5]) if len(a) > 5 else 32
os.makedirs(outd, exist_ok=True)
meta = {}
def sha(p):
    h = hashlib.sha1()
    with open(p, "rb") as f:
        for b in iter(lambda: f.read(1 << 24), b""): h.update(b)
    return h.hexdigest()[:12]
for tag, glb in files.items():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=glb)
    sc = bpy.context.scene
    for o in sc.objects:
        if o.type == "ARMATURE": o.data.pose_position = "REST"
    bpy.context.view_layer.update()
    meshes = [o for o in sc.objects if o.type == "MESH"]
    lo = Vector((1e9,) * 3); hi = Vector((-1e9,) * 3)
    for ob in meshes:
        for c in ob.bound_box:
            w = ob.matrix_world @ Vector(c)
            lo = Vector(map(min, lo, w)); hi = Vector(map(max, hi, w))
    ctr = (lo + hi) * 0.5
    H = (hi - lo).z * 1.06
    Wd = math.hypot((hi - lo).x, (hi - lo).y) * 1.06
    asp = max(0.7, Wd / H)
    tris = sum(len(m.data.polygons) for m in meshes)   # polys (v95 masters are tris)
    meta[tag] = {"glb": glb, "size": os.path.getsize(glb), "sha": sha(glb), "dims": list(hi - lo), "H_view": H, "res_h": res_h, "asp": asp, "polys": tris}
    sc.render.engine = "CYCLES"; sc.cycles.samples = samples; sc.cycles.use_denoising = True
    try:
        pr = bpy.context.preferences.addons["cycles"].preferences
        for t in ("OPTIX", "CUDA"):
            try:
                pr.compute_device_type = t; pr.get_devices()
                ds = [d for d in pr.devices if d.type == t]
                if ds:
                    for d in pr.devices: d.use = d.type == t
                    sc.cycles.device = "GPU"; meta[tag]["device"] = t; break
            except Exception: pass
        else: sc.cycles.device = "CPU"; meta[tag]["device"] = "CPU"
    except Exception: sc.cycles.device = "CPU"; meta[tag]["device"] = "CPU"
    sc.render.resolution_y = res_h; sc.render.resolution_x = int(res_h * asp)
    sc.view_settings.view_transform = "Standard"; sc.render.film_transparent = True
    sc.world = bpy.data.worlds.new("w"); sc.world.use_nodes = True
    bg = sc.world.node_tree.nodes["Background"]; bg.inputs[0].default_value = (0.86, 0.86, 0.87, 1); bg.inputs[1].default_value = 0.55
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); sc.collection.objects.link(cam); sc.camera = cam
    cam.data.type = "ORTHO"; cam.data.clip_end = 100; cam.data.sensor_fit = "VERTICAL"; cam.data.ortho_scale = H
    for name, az in (("front", 0.0), ("tq", 40.0)):
        for o in [o for o in sc.objects if o.type == "LIGHT"]: bpy.data.objects.remove(o)
        r = math.radians(az)
        d = Vector((math.sin(r), -math.cos(r), 0.0))
        cam.location = ctr + d * 10.0
        cam.rotation_euler = (math.radians(90), 0, r)
        for nm, rot, e in (("key", (math.radians(50), 0, r + math.radians(-30)), 2.6), ("fill", (math.radians(70), 0, r + math.radians(45)), 0.9), ("rim", (math.radians(60), 0, r + math.radians(180)), 1.2)):
            s = bpy.data.objects.new(nm, bpy.data.lights.new(nm, "SUN")); sc.collection.objects.link(s)
            s.data.energy = e; s.rotation_euler = rot; s.data.angle = math.radians(10)
        sc.render.filepath = f"{outd}/{hun}_{tag}_{name}.png"
        bpy.ops.render.render(write_still=True)
    print("RENDERED", hun, tag, meta[tag]["device"], flush=True)
json.dump(meta, open(f"{outd}/{hun}_meta.json", "w"), indent=1)
