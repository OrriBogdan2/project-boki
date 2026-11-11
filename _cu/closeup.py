"""Textured close-up renders. blender -b --factory-startup -P closeup.py -- OUTDIR SPEC.json [--res=900] [--samples=24] [--views=face,face34,upper,full]
SPEC.json: [{"name":..,"tag":"cur"|"pick","glb":..,"face_z":frac,"face_s":size_frac,"cam_from":tag-of-glb-to-frame}] ; framing always from the 'cur' bbox of the same hunter."""
import sys, os, math, json, bpy
from mathutils import Vector
a = sys.argv[sys.argv.index("--") + 1:]
out = a[0]; spec = json.load(open(a[1]))
opt = dict(x[2:].split("=", 1) for x in a[2:] if "=" in x)
RES = int(opt.get("res", 900)); RH = int(RES * 1.2); SAMP = int(opt.get("samples", 24))
VIEWS = opt.get("views", "face,face34,upper,full").split(",")
frames = {}
def bbox(meshes):
    pts = [o.matrix_world @ Vector(c) for o in meshes for c in o.bound_box]
    return Vector([min(p[i] for p in pts) for i in range(3)]), Vector([max(p[i] for p in pts) for i in range(3)])
for job in spec:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=job["glb"])
    sc = bpy.context.scene
    root = bpy.data.objects.new("ROOT", None); sc.collection.objects.link(root)
    for o in list(sc.objects):
        if o is not root and o.parent is None: o.parent = root
    meshes = [o for o in sc.objects if o.type == "MESH"]
    bpy.context.view_layer.update()
    mn, mx = bbox(meshes)
    nm = job["name"]
    if nm not in frames:  # first job of a hunter = current: sets the frame
        import numpy as np
        P = []
        for o in meshes:
            n = len(o.data.vertices); c = np.empty(n * 3, np.float32); o.data.vertices.foreach_get("co", c); c = c.reshape(n, 3)
            M = np.array(o.matrix_world); P.append(c @ M[:3, :3].T + M[:3, 3])
        P = np.concatenate(P); hh = mx.z - mn.z
        band = P[(P[:, 2] > mn.z + 0.55 * hh) & (P[:, 2] < mn.z + 0.95 * hh)]
        frames[nm] = dict(cx=float(np.median(band[:, 0])), cy=float(np.median(band[:, 1])), z0=mn.z, h=hh)
    F = frames[nm]
    import numpy as np
    Pw = []
    for o in meshes:
        n_ = len(o.data.vertices); c_ = np.empty(n_ * 3, np.float32); o.data.vertices.foreach_get("co", c_); c_ = c_.reshape(n_, 3)
        M_ = np.array(o.matrix_world); Pw.append(c_ @ M_[:3, :3].T + M_[:3, 3])
    Pw = np.concatenate(Pw)
    pivot = bpy.data.objects.new("PIV", None); sc.collection.objects.link(pivot); root.parent = pivot
    bpy.context.view_layer.update()
    H = F["h"]
    sc.render.engine = "CYCLES"; sc.cycles.device = "CPU"; sc.cycles.samples = SAMP; sc.cycles.use_denoising = True
    sc.render.resolution_x = RES; sc.render.resolution_y = RH
    sc.render.image_settings.file_format = "JPEG"; sc.render.image_settings.quality = 93
    try: sc.view_settings.view_transform = "Khronos PBR Neutral"
    except Exception: sc.view_settings.view_transform = "Standard"
    w = bpy.data.worlds.new("w"); sc.world = w; w.use_nodes = True
    bg = w.node_tree.nodes["Background"]; bg.inputs[0].default_value = (0.5, 0.5, 0.53, 1); bg.inputs[1].default_value = 0.8
    # 3-point light, parented to camera so each view is lit the same way
    cam = bpy.data.cameras.new("c"); co = bpy.data.objects.new("c", cam); sc.collection.objects.link(co); sc.camera = co
    def area(nm_, loc, en, size):
        l = bpy.data.lights.new(nm_, "AREA"); l.energy = en; l.size = size
        lo = bpy.data.objects.new(nm_, l); sc.collection.objects.link(lo); lo.parent = co; lo.location = loc
        d = Vector((0, 0, 0)) - Vector(loc)  # camera local: aim at -Z axis point 6m ahead
        tgt = Vector((0, 0, -6)); dd = tgt - Vector(loc)
        lo.rotation_euler = dd.to_track_quat("-Z", "Y").to_euler()
    area("key", (-3.0, 2.5, 0.5), 750, 3.0); area("fill", (3.5, 0.5, 0.5), 300, 4.0); area("rim", (1.0, 3.0, -5.5), 700, 2.0)
    def shoot(view, tag):
        fz = job.get("face_z", 0.92); fs = job.get("face_s", 0.14)
        dx = job.get("dx", 0.0) if view in ("face", "face34") else job.get("up_dx", 0.0) if view == "upper" else 0.0
        px_, py_ = F["cx"] + dx * F["h"], F["cy"]
        if view in ("face", "face34") and job.get("auto_pivot"):
            hh = F["h"]
            m = (abs(Pw[:, 2] - (F["z0"] + fz * hh)) < 0.04 * hh) & (abs(Pw[:, 0] - px_) < 0.07 * hh)
            if m.sum() > 50:
                px_, py_ = float(np.median(Pw[m, 0])), float(np.median(Pw[m, 1]))
        root.location = -Vector((px_, py_, F["z0"]))
        if view in ("face", "face34"):
            lens, cz, span = 85, F["h"] * fz, H * fs
        elif view == "upper":
            lens, cz, span = 60, H * job.get("up_z", 0.78), H * job.get("up_s", 0.40)
        else:
            lens, cz, span = 50, H * 0.5, H * 1.08
        cam.lens = lens; cam.sensor_fit = "VERTICAL"; cam.sensor_width = 36
        # vertical fov covers `span` (RH px) at distance d
        sh = 36.0  # sensor height used for vertical fit
        cam.sensor_height = sh
        d = span / 2 / (sh / 2 / lens)
        co.location = (0, -d, cz); co.rotation_euler = (math.radians(90), 0, 0)
        ang = {"face": 0, "face34": 35, "upper": 30, "full": 0}[view]
        pivot.rotation_euler = (0, 0, math.radians(ang))
        # rotate about the figure axis (root origin is the model's centre offset) -> pivot at origin
        sc.render.filepath = os.path.join(out, nm, f"{tag}_{view}.jpg")
        os.makedirs(os.path.dirname(sc.render.filepath), exist_ok=True)
        bpy.ops.render.render(write_still=True)
    for v in VIEWS: shoot(v, job["tag"])
    print("CU done", nm, job["tag"], H, flush=True)
json.dump(frames, open(os.path.join(out, "frames.json"), "w"))
