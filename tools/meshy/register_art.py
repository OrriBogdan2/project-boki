"""Registers an art view on the Meshy mesh per region (fit_warden project / project_late "k", "col0_at", "row0_at"):
renders the mesh flat at a guessed mapping (front: camera on -Y; --back: behind her), then searches the scale and
offset that best line up the render's edges with the art's inside each region box (Meshy frame x0,x1,z0,z1). Prints
k (m/px), col0 (x = 0 column), row0 (z = 0 row) per region: about 20 px better than the figure-height guess.
  blender -b --factory-startup --python tools/meshy/register_art.py -- MESH.glb ART.png K COL0 ROW0 name:x0,x1,z0,z1
      [...] [--back]
The guess: K ~ figure height (m) / its rows; ROW0 the row of z = 0; COL0 the column of x = 0."""
import sys, math, os
import bpy
import numpy as np
from mathutils import Vector
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import imgio  # noqa: E402
a = sys.argv[sys.argv.index("--") + 1:]
glb, art_path = a[0], a[1]
k, col0, row0 = float(a[2]), float(a[3]), float(a[4])
back = "--back" in a
regions = [(r.split(":")[0], [float(x) for x in r.split(":")[1].split(",")]) for r in a[5:] if not r.startswith("--")]
art = imgio.load(art_path)
H, W = art.shape[:2]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=glb)
for ob in bpy.context.scene.objects:
    if ob.type != "MESH": continue
    for m in ob.data.materials:
        nt = m.node_tree
        tex = next((n for n in nt.nodes if n.type == "TEX_IMAGE"), None)
        em = nt.nodes.new("ShaderNodeEmission")
        if tex: nt.links.new(tex.outputs[0], em.inputs[0])
        nt.links.new(em.outputs[0], next(n for n in nt.nodes if n.type == "OUTPUT_MATERIAL").inputs[0])
sc = bpy.context.scene
sc.render.engine = "CYCLES"; sc.cycles.samples = 4; sc.cycles.device = "CPU"
sc.render.resolution_x = W; sc.render.resolution_y = H
sc.view_settings.view_transform = "Standard"
sc.world = bpy.data.worlds.new("w"); sc.world.use_nodes = True
sc.world.node_tree.nodes["Background"].inputs[0].default_value = (art[5, 5, 0], art[5, 5, 1], art[5, 5, 2], 1)
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); sc.collection.objects.link(cam); sc.camera = cam
cam.data.type = "ORTHO"; cam.data.ortho_scale = W * k
# the image centre in the world under the guess
cx = (W / 2.0 - col0) * k
cz = (row0 - H / 2.0) * k
cam.location = (cx, -5.0, cz)
cam.rotation_euler = (math.pi / 2, 0, 0)
if back:
    # (the back view: the camera behind her, image right = her right = -X: col = col0 - x / k)
    cam.location = ((col0 - W / 2.0) * k, 5.0, cz)
    cam.rotation_euler = (math.pi / 2, 0, math.pi)
out = os.path.join(os.path.dirname(os.path.abspath(art_path)), "_register_render.png")
sc.render.filepath = out
bpy.ops.render.render(write_still=True)
ren = imgio.load(out)

def edges(img):
    l = img @ np.array([0.3, 0.59, 0.11], np.float32)
    gx = np.zeros_like(l); gy = np.zeros_like(l)
    gx[:, 1:-1] = l[:, 2:] - l[:, :-2]; gy[1:-1] = l[2:] - l[:-2]
    g = np.hypot(gx, gy)
    # a little blur: matching edges of two paintings of the same thing
    for _ in range(2):
        g = (g + np.roll(g, 1, 0) + np.roll(g, -1, 0) + np.roll(g, 1, 1) + np.roll(g, -1, 1)) / 5.0
    return g

ea, er = edges(art), edges(ren)
for name, (x0, x1, z0, z1) in regions:
    # the region's pixel box under the guess
    c0, c1 = (int(col0 - x1 / k), int(col0 - x0 / k)) if back else (int(col0 + x0 / k), int(col0 + x1 / k))
    r0, r1 = int(row0 - z1 / k), int(row0 - z0 / k)
    pc, pr = (c0 + c1) / 2.0, (r0 + r1) / 2.0
    best = None
    A = ea[r0:r1, c0:c1]
    A = (A - A.mean()) / (A.std() + 1e-6)
    for s in np.arange(0.92, 1.081, 0.004):
        # the render scaled by s about the region centre: sample it on the art's grid
        yy, xx = np.mgrid[r0 - 30:r1 + 30, c0 - 30:c1 + 30]
        sy = np.clip(((yy - pr) / s + pr).astype(int), 0, H - 1)
        sx = np.clip(((xx - pc) / s + pc).astype(int), 0, W - 1)
        R = er[sy, sx]
        for dy in range(-30, 31, 2):
            for dx in range(-30, 31, 2):
                B = R[30 + dy:30 + dy + (r1 - r0), 30 + dx:30 + dx + (c1 - c0)]
                B = (B - B.mean()) / (B.std() + 1e-6)
                v = float((A * B).mean())
                if best is None or v > best[0]:
                    best = (v, s, dx, dy)
    v, s, dx, dy = best
    # refine the offset at 1 px around the best
    yy, xx = np.mgrid[r0 - 30:r1 + 30, c0 - 30:c1 + 30]
    sy = np.clip(((yy - pr) / s + pr).astype(int), 0, H - 1)
    sx = np.clip(((xx - pc) / s + pc).astype(int), 0, W - 1)
    R = er[sy, sx]
    for ddy in range(dy - 2, dy + 3):
        for ddx in range(dx - 2, dx + 3):
            B = R[30 + ddy:30 + ddy + (r1 - r0), 30 + ddx:30 + ddx + (c1 - c0)]
            B = (B - B.mean()) / (B.std() + 1e-6)
            vv = float((A * B).mean())
            if vv > v:
                v, dx, dy = vv, ddx, ddy
    # art pixel p shows what the render shows at pc + (p - pc - d)/s; the render maps world x to col0 + x/k:
    # so the art maps world x to pc + s*(col0 + x/k - pc) + d  =>  k' = k/s, col0' = pc + s*(col0 - pc) - dx
    k2 = k / s
    col2 = pc + s * (col0 - pc) - dx
    row2 = pr + s * (row0 - pr) - dy
    v0 = float((A * ((er[r0:r1, c0:c1] - er[r0:r1, c0:c1].mean()) / (er[r0:r1, c0:c1].std() + 1e-6))).mean())
    print("REGISTER %s: score %.3f (guess %.3f), s %.3f, dx %d, dy %d -> k %.6f col0 %.2f row0 %.2f" % (
        name, v, v0, s, dx, dy, k2, col2, row2))
