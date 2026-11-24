"""Meeko's sun and raincloud for the Meshy-native pack (art/wardens/pip/pip_meshy.glb), 11-23: bigger, tilted toward the
camera, bolder faces. Builds the five companion surfaces on their own (no body, no rig) with pip_companions.py's builders
and constants overridden here; tools/meshy/native_hunters/graft_companions.py swaps them into pip_meshy.glb.
  blender -b --factory-startup --python tools/art1/pip_companions_native.py -- OUT.glb OUT_faces.png [--sun-glb=S.glb --cloud-glb=C.glb [--sun-turn=deg --cloud-turn=deg]]
--sun-glb/--cloud-glb (11-24, plan meeko-comp-plan-1124 3.1/3.3): the bodies are Meshy image-to-3D models from the portrait
(imported, centred, scaled to the spans below, turned to face +Y, decimated to TRIS, their albedo kept at TEX_PX); the
procedural sun_body()/pc.cloud_body() are the fallback when they are not given.
Space: Blender's, facing +Y, her right +X (the sun floats on her left, -X), up +Z, contract metres.
Why (docs: Fable plan 11-23): the live sun/cloud were 12 px dots at the game camera (66 deg top-down), their vertical face decals
sank into the decimated bodies and were seen at a grazing angle, the cloud sat on the tinted `skin` slot (pink on pink)."""

import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pip_companions as pc  # noqa: E402

pc.SUN_R = (
    0.18  # was 0.105: a round ball 0.36 m wide, short rays to 1.4 R (span 0.50 m: 27 px at the game camera, was 12)
)
pc.CLOUD_W = 0.52  # was 0.36
pc.TRIS = {"sun": 700, "cloud": 800}  # (plan 11-24 budget; was 620 / 760)
# the cloud's face needs one smooth belly under it (the lumpy original left creases the decal could not lie on)
pc.CLOUD_LOBES = [
    (0.0, 0.04, 0.31),
    (-0.03, 0.2, 0.24),
    (-0.31, -0.03, 0.2),
    (0.29, -0.01, 0.22),
    (-0.17, -0.19, 0.17),
    (0.2, -0.18, 0.17),
    (-0.41, -0.11, 0.11),
]
TILT = 0.0  # (was 50 deg: facing is done in code now, warden_anim/pip.json companions.face 'camera': the disc squares up to the active camera in every pose)
SUN_CELL = 0.145
CLOUD_CELL = 0.16
LIFT = 0.007  # m the face sits off the body
LIFT_MESHY = 0.010  # m: on the decimated Meshy ball (its facets sag a flat 7 mm patch to 1.3 mm in places)
MIN_OUT = 0.002  # m: the build fails when a decal vertex or triangle centre is closer to (or inside) the body
SUN_RAY = 0.34  # ray length past the ball's skin, x SUN_R: short and wide like the splash (was 0.64; 0.80 read as a spiky star)
SUN_RAY_BASE = 0.38  # ray base radius, x SUN_R
SUN_FLAT = 0.62  # ray thickness along the view axis (was 0.72)
LEMON = (1.0, 0.86, 0.22)
CLOUD_COL = (0.97, 0.97, 1.0)
DROPS = (
    (-0.22, -0.60, 0.07),
    (0.02, -0.66, 0.085),
)  # x, z (x cloud width), radius (x cloud width): the drops hang clear of the nubs
SPAN = {"sun": 0.50, "cloud": 0.52}  # m: the sun across its petal tips (its widest of X/Z), the cloud's width (X)
TEX_PX = 512  # the Meshy albedo's size in the game file
CELL_FACE = {"sun": 1, "cloud": 5}  # the atlas cell each face is baked to (laugh; the cloud's happy)


# ----------------------------------------------------------------------------------------------------- bolder faces
def eyes_open(c, y=0.08, size=1.0):
    for s in (-1, 1):
        c.ellipse(0.38 * s, y, 0.14 * size, 0.18 * size, pc.PLUM)
        c.ellipse(0.38 * s + 0.04 * size, y + 0.07 * size, 0.05 * size, 0.06 * size, (1, 1, 1))
        c.ellipse(0.38 * s - 0.035 * size, y - 0.07 * size, 0.025 * size, 0.03 * size, (1, 1, 1), 0.85)


def eyes_arc(c, up, y=0.1):
    for s in (-1, 1):
        a0, a1 = (0.3, math.pi - 0.3) if up else (math.pi + 0.3, 2 * math.pi - 0.3)
        c.arc(0.38 * s, y - (0.08 if up else -0.08), 0.15, a0, a1, 0.075, pc.PLUM)


def blush(c, y=-0.14):
    for s in (-1, 1):
        c.ellipse(0.64 * s, y, 0.17, 0.1, pc.PINK, 0.85)


def brows(c, col, worried=True, y=0.36):
    for s in (-1, 1):
        yi, yo = (y + 0.06, y - 0.03) if worried else (y - 0.06, y + 0.05)
        c.stroke([(0.26 * s, yi), (0.52 * s, yo)], 0.06, col)


def mouth_o(c, y=-0.2):
    c.ellipse(0, y, 0.07, 0.09, pc.PLUM)
    c.ellipse(0, y, 0.045, 0.06, pc.MOUTH)


def mouth_frown(c, y=-0.24):
    c.arc(0, y - 0.1, 0.2, 0.45, math.pi - 0.45, 0.06, pc.PLUM)


def mouth_sad(c, y=-0.18):
    w = 0.24
    prof = np.clip(1 - (c.x / w) ** 2, 0, 1)
    inside = (c.y > y - 0.3) & (c.y < y - 0.3 + 0.3 * prof) & (abs(c.x) < w)
    c.lay(np.where(inside, -0.01, 0.05), pc.MOUTH)
    t = np.linspace(0, math.pi, 28)
    c.stroke(list(zip(w * np.cos(t), y - 0.3 + 0.3 * np.sin(t))), 0.05, pc.PLUM)


def tears(c):
    for s in (-1, 1):
        c.stroke([(0.38 * s, 0.0), (0.46 * s, -0.55)], 0.11, pc.TEAR)
        c.ellipse(0.46 * s, -0.55, 0.075, 0.075, pc.TEAR)


# ------------------------------------------------------------------- calm / happy faces as the portrait (11-24 plan 3.2/3.4)
def dot_eyes(c, y):
    """Solid plum dots with one small white highlight (the portrait's idle eyes)."""
    for s in (-1, 1):
        c.ellipse(0.36 * s, y, 0.10, 0.12, pc.PLUM)
        c.ellipse(0.36 * s + 0.035, y + 0.045, 0.03, 0.03, (1, 1, 1))


def closed_eyes(c, y):
    """Happy closed eyes: thin upturned arcs."""
    for s in (-1, 1):
        c.arc(0.36 * s, y - 0.06, 0.11, 0.35, math.pi - 0.35, 0.05, pc.PLUM)


def soft_brows(c, col, y):
    """Thin short brows, a touch raised and level (not the worried V, not angry): the top of a small arc."""
    for s in (-1, 1):
        c.arc(0.36 * s, y - 0.12, 0.12, 0.30 * math.pi, 0.70 * math.pi, 0.035, col)


def small_smile(c, y, w):
    """A small closed smile: an arc w wide each side, corners at y, stroke 0.045 (no open mouth, no teeth)."""
    r = w * 1.4
    a = math.acos(w / r)
    c.arc(0, y + r * math.sin(a), r, math.pi + a, 2 * math.pi - a, 0.045, pc.PLUM)


def soft_blush(c, y):
    """Soft blush at (+-0.62, y): four nested ellipses, about alpha 0.6 at the centre, fading out."""
    for s in (-1, 1):
        for k in range(4):
            f = 1 - 0.2 * k
            c.ellipse(0.62 * s, y, 0.18 * f, 0.11 * f, pc.PINK, 0.21)


def face_calm(c, who, happy):
    eye_y, mouth_y, w = (0.08, -0.20, 0.16) if who == "sun" else (0.06, -0.18, 0.14)
    soft_blush(c, -0.16)
    if happy:
        closed_eyes(c, eye_y)
        small_smile(c, mouth_y, w + 0.04)
    else:
        soft_brows(c, pc.BROW_SUN if who == "sun" else pc.BROW_CLOUD, eye_y + 0.27)
        dot_eyes(c, eye_y)
        small_smile(c, mouth_y, w)


def face_cell(who, name):
    c = pc.Cell()
    brow = pc.BROW_SUN if who == "sun" else pc.BROW_CLOUD
    if (who, name) in (("sun", "happy"), ("cloud", "shy")):  # cells 0, 4: calm (idle)
        face_calm(c, who, False)
    elif (who, name) in (("sun", "laugh"), ("cloud", "happy")):  # cells 1, 5: happy (emotes)
        face_calm(c, who, True)
    elif name == "grumpy":
        blush(c, -0.16)
        brows(c, brow, False, 0.28)
        eyes_open(c, 0.05, 0.85)
        mouth_frown(c)
    elif name == "sleep":
        blush(c)
        eyes_arc(c, False)
        mouth_o(c)
    elif name == "cry":
        tears(c)
        blush(c)
        brows(c, brow)
        eyes_arc(c, False, 0.03)
        mouth_sad(c)
    return c


# ---------------------------------------------------------------------------------------------------------- shapes
def sun_body():
    """pip_companions.sun_body with longer, flatter rays, then the whole disc leant back by TILT."""
    R = pc.SUN_R
    bm = bmesh.new()
    pc.ellipsoid(bm, (0, 0, 0), (R, R * pc.SUN_DEPTH, R))
    n = 10
    for k in range(n):
        a = math.tau * (k + 0.5) / n
        out = Vector((math.sin(a), 0, math.cos(a)))
        length = R * SUN_RAY + (R * 0.14 if k % 2 == 0 else 0)
        m = Matrix.Translation(out * R * 0.82) @ Matrix.Rotation(a, 4, "Y") @ Matrix.Diagonal((1, SUN_FLAT, 1, 1))
        bmesh.ops.create_cone(
            bm,
            cap_ends=True,
            segments=10,
            radius1=R * SUN_RAY_BASE,
            radius2=R * 0.07,
            depth=length + R * 0.18,
            matrix=m @ Matrix.Translation((0, 0, (length + R * 0.18) / 2 - R * 0.1)),
        )
    ob = pc.blob("sun", bm, 0.0065, 8, pc.TRIS["sun"])
    ob.data.transform(Matrix.Rotation(TILT, 4, "X"))
    return ob


def meshy_body(name, path, mat_name, turn=0.0):
    """A Meshy image-to-3D body: joined, centred on its bounds, scaled to SPAN, its front (glTF +Z, Blender -Y on import) turned
    to +Y (then `turn` degrees about Z: a model whose portrait-like side is Meshy's back), decimated to pc.TRIS, smooth-shaded; one material `mat_name` with only Meshy's base colour (TEX_PX square)."""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    meshes = [o for o in bpy.data.objects if o not in before and o.type == "MESH"]
    for o in set(bpy.data.objects) - before - set(meshes):
        bpy.data.objects.remove(o)
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    ob.parent = None
    ob.data.transform(ob.matrix_world)
    ob.matrix_world = Matrix.Identity(4)
    src = next(
        n.image
        for m in ob.data.materials
        if m and m.use_nodes
        for n in m.node_tree.nodes
        if n.type == "TEX_IMAGE" and n.image and any(lk.to_socket.name == "Base Color" for lk in n.outputs[0].links)
    )
    vs = np.array([v.co[:] for v in ob.data.vertices])
    lo, hi = vs.min(0), vs.max(0)
    span = (hi[0] - lo[0]) if name == "cloud" else max(hi[0] - lo[0], hi[2] - lo[2])
    ob.data.transform(
        Matrix.Rotation(math.pi + math.radians(turn), 4, "Z")
        @ Matrix.Scale(SPAN[name] / span, 4)
        @ Matrix.Translation(Vector(-(lo + hi) / 2))
    )
    bm = (
        bmesh.new()
    )  # (weld Meshy's UV-seam splits first: decimated apart they open as cracks; loop UVs survive the weld)
    bm.from_mesh(ob.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bm.to_mesh(ob.data)
    bm.free()
    d = ob.modifiers.new("d", "DECIMATE")
    d.ratio = min(1.0, pc.TRIS[name] / max(1, sum(len(p.vertices) - 2 for p in ob.data.polygons)))
    bpy.ops.object.modifier_apply(modifier=d.name)
    t = ob.modifiers.new("t", "TRIANGULATE")
    bpy.ops.object.modifier_apply(modifier=t.name)
    ob.data.polygons.foreach_set("use_smooth", [True] * len(ob.data.polygons))
    img = src.copy()
    img.scale(TEX_PX, TEX_PX)
    img.name = mat_name + "_albedo"
    if bpy.data.materials.get(mat_name):  # (the flat fallback material of that name: it keeps a suffix, unused)
        bpy.data.materials[mat_name].name = mat_name + "_flat"
    m = bpy.data.materials.new(mat_name)
    m.use_nodes = True
    tex = m.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = img
    bsdf = m.node_tree.nodes["Principled BSDF"]
    m.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.5
    ob.data.materials.clear()
    ob.data.materials.append(m)
    ob.name = name
    print("MESHY", name, path, "tris", len(ob.data.polygons), "span m", SPAN[name])
    return ob


def drops():
    W = pc.CLOUD_W
    bm = bmesh.new()
    for x, z, r in DROPS:
        r *= W
        sub = bmesh.new()
        bmesh.ops.create_uvsphere(sub, u_segments=10, v_segments=6, radius=1.0)
        for v in sub.verts:
            if v.co.z > 0:
                k = 1 - 0.78 * v.co.z
                v.co.x *= k
                v.co.y *= k
                v.co.z *= 1.9
            v.co *= r
            v.co += Vector((x * W, W * 0.04, z * W))
        me = bpy.data.meshes.new("t")
        sub.to_mesh(me)
        sub.free()
        bm.from_mesh(me)
    ob = pc.new_obj("drops", bm)
    ob.data.polygons.foreach_set("use_smooth", [True] * len(ob.data.polygons))
    return ob


def height_above(bvh, p, n):
    """How far p stands off the body, along the body's own normal there: >0 outside, <=0 buried or touching."""
    loc, nrm, _, _ = bvh.find_nearest(p)
    return (p - loc).dot(nrm) if loc is not None else 9.0


def face_patch(name, body, cell_half, centre, tilt, lift=LIFT, steep=0.55):
    """A grid of quads on the body's front-up (rays cast along n, the front leant back by `tilt`), lifted LIFT off the skin,
    UV 0..1 over the cell. Fails the build when any vertex or triangle centre ends up closer than MIN_OUT to the body."""
    n_g = 10
    bvh = BVHTree.FromObject(body, bpy.context.evaluated_depsgraph_get())
    n_dir = Matrix.Rotation(tilt, 3, "X") @ Vector((0, 1, 0))
    v_dir = Matrix.Rotation(tilt, 3, "X") @ Vector((0, 0, 1))
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    grid = {}
    for j in range(n_g + 1):
        for i in range(n_g + 1):
            p = centre + Vector((1, 0, 0)) * ((i / n_g * 2 - 1) * cell_half) + v_dir * ((j / n_g * 2 - 1) * cell_half)
            hit, nrm, _, _ = bvh.ray_cast(p + n_dir * 2.0, -n_dir)
            if hit is not None and nrm.dot(n_dir) > steep:  # (not up the steep rim: a flat quad would sag into it)
                grid[i, j] = bm.verts.new(hit + nrm * lift)
    for j in range(n_g):
        for i in range(n_g):
            ring = ((i, j), (i, j + 1), (i + 1, j + 1), (i + 1, j))
            q = [grid.get(k) for k in ring]
            if None in q:
                continue
            f = bm.faces.new(q)
            for lp, (a, b) in zip(f.loops, ring):
                lp[uv].uv = (1 - a / n_g, b / n_g)
    worst = 9.0
    for f in bm.faces:
        for p in [v.co for v in f.verts] + [f.calc_center_median()]:
            worst = min(worst, height_above(bvh, p, n_dir))
    print("DECAL", name, "quads", len(bm.faces), "lowest above the body (mm)", round(worst * 1000, 1))
    assert len(bm.faces) >= 24, f"{name}: the face patch lost most of its quads"
    assert worst >= MIN_OUT, (
        f"{name}: a face vertex or triangle centre is {worst * 1000:.1f} mm from the body (< {MIN_OUT * 1000} mm)"
    )
    ob = pc.new_obj(name, bm)
    ob.data.polygons.foreach_set("use_smooth", [True] * len(ob.data.polygons))
    return ob


def check_drops(cloud, dr):
    """The drops hang clear of the cloud: their top is >= 20 mm below the cloud's lowest point."""
    cz = min((cloud.matrix_world @ v.co).z for v in cloud.data.vertices)
    dz = max((dr.matrix_world @ v.co).z for v in dr.data.vertices)
    print("DROPS gap below the cloud (mm)", round((cz - dz) * 1000, 1))
    assert cz - dz >= 0.02, "a drop touches the cloud"


def main():
    args = sys.argv[sys.argv.index("--") + 1 :]
    dst, faces_png = args[:2]
    opt = dict(a[2:].split("=", 1) for a in args[2:] if a.startswith("--"))
    bpy.ops.wm.read_factory_settings(use_empty=True)
    pc.face_cell = face_cell
    img = pc.build_atlas()
    img.filepath_raw, img.file_format = faces_png, "PNG"
    img.save()
    mats = {
        "sun": pc.flat_mat("glow-sun", LEMON),
        "cloud": pc.flat_mat("cloth-cloud", CLOUD_COL, 0.5),
        "drop": pc.flat_mat("ice-drop", (0.60, 0.78, 0.98), 0.15),
        "fsun": pc.face_mat("eyes-mood_sun", img),
        "fcloud": pc.face_mat("eyes-mood_cloud", img),
    }
    sun = (
        meshy_body("sun", opt["sun-glb"], "glow-sun", float(opt.get("sun-turn", 0))) if "sun-glb" in opt else sun_body()
    )
    cloud = (
        meshy_body("cloud", opt["cloud-glb"], "cloth-cloud", float(opt.get("cloud-turn", 0)))
        if "cloud-glb" in opt
        else pc.cloud_body()
    )
    dr = drops()
    for ob, mk in ((sun, "sun"), (cloud, "cloud"), (dr, "drop")):
        if not ob.data.materials:
            ob.data.materials.append(mats[mk])
    bpy.context.view_layer.update()
    check_drops(cloud, dr)
    objs = [sun, cloud, dr]
    f = face_patch("face_sun", sun, SUN_CELL, Vector((0, 0, 0)), TILT, LIFT_MESHY if "sun-glb" in opt else LIFT)
    f.data.materials.append(mats["fsun"])
    objs.append(f)
    f = face_patch("face_cloud", cloud, CLOUD_CELL, Vector((0, 0, 0.04 * pc.CLOUD_W)), TILT, 0.012, 0.45)
    f.data.materials.append(mats["fcloud"])
    objs.append(f)
    print("COMPANION tris", sum(len(p.vertices) - 2 for ob in objs for p in ob.data.polygons))
    bpy.ops.object.select_all(action="DESELECT")
    for ob in objs:
        ob.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=dst,
        export_format="GLB",
        use_selection=True,
        export_apply=False,
        export_animations=False,
        export_materials="EXPORT",
        export_image_format="AUTO",
        export_yup=True,
    )
    print("exported", dst)


if __name__ == "__main__":
    main()
