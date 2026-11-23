"""Meeko's sun and raincloud for the Meshy-native pack (art/wardens/pip/pip_meshy.glb), 11-23: bigger, tilted toward the
camera, bolder faces. Builds the five companion surfaces on their own (no body, no rig) with pip_companions.py's builders
and constants overridden here; tools/meshy/native_hunters/graft_companions.py swaps them into pip_meshy.glb.
  blender -b --factory-startup --python tools/art1/pip_companions_native.py -- OUT.glb OUT_faces.png
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

pc.SUN_R = 0.16          # was 0.105: span 0.50 m with the longer rays (27 px at the game camera, was 12)
pc.CLOUD_W = 0.52        # was 0.36
pc.TRIS = {"sun": 620, "cloud": 760}
# the cloud's face needs one smooth belly under it (the lumpy original left creases the decal could not lie on)
pc.CLOUD_LOBES = [(0.0, 0.04, 0.31), (-0.03, 0.2, 0.24), (-0.31, -0.03, 0.2), (0.29, -0.01, 0.22), (-0.17, -0.19, 0.17), (0.2, -0.18, 0.17),
                  (-0.41, -0.11, 0.11)]
TILT = math.radians(50)  # the sun disc and both faces lean back this far: the 66 deg camera sees them at 0.98 of full size
SUN_CELL = 0.145
CLOUD_CELL = 0.16
LIFT = 0.007             # m the face sits off the body
MIN_OUT = 0.002          # m: the build fails when a decal vertex or triangle centre is closer to (or inside) the body
SUN_RAY = 0.80           # ray length, x SUN_R (was 0.64)
SUN_FLAT = 0.5           # ray thickness along the view axis (was 0.72)
LEMON = (1.0, 0.86, 0.22)
CLOUD_COL = (0.97, 0.97, 1.0)
DROPS = ((-0.22, -0.60, 0.07), (0.02, -0.66, 0.085))   # x, z (x cloud width), radius (x cloud width): the drops hang clear of the nubs
CELL_FACE = {"sun": 1, "cloud": 5}    # the atlas cell each face is baked to (laugh; the cloud's happy)


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


def mouth_open(c, y=-0.18, w=0.3, depth=0.32):
    prof = np.clip(1 - (c.x / w) ** 2, 0, 1)
    inside = (c.y < y) & (c.y > y - depth * prof) & (abs(c.x) < w)
    c.lay(np.where(inside, -0.01, 0.05), pc.MOUTH)
    c.lay(np.where(inside & (c.y < y - depth * 0.45 * prof), -0.01, 0.05), (1.0, 0.55, 0.62), 0.9)
    c.stroke([(-w, y), (w, y)], 0.05, pc.PLUM)
    t = np.linspace(0, math.pi, 28)
    c.stroke(list(zip(w * np.cos(t), y - depth * np.sin(t))), 0.05, pc.PLUM)


def mouth_o(c, y=-0.2):
    c.ellipse(0, y, 0.07, 0.09, pc.PLUM)
    c.ellipse(0, y, 0.045, 0.06, pc.MOUTH)


def mouth_frown(c, y=-0.24):
    c.arc(0, y - 0.1, 0.2, 0.45, math.pi - 0.45, 0.06, pc.PLUM)


def mouth_wavy(c, y=-0.17):
    x = np.linspace(-0.2, 0.2, 24)
    c.stroke(list(zip(x, y + 0.04 * np.sin(x / 0.2 * 3 * math.pi))), 0.05, pc.PLUM)


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


def face_cell(who, name):
    c = pc.Cell()
    brow = pc.BROW_SUN if who == "sun" else pc.BROW_CLOUD
    if name == "happy" and who == "sun":
        blush(c); brows(c, brow); eyes_open(c); mouth_open(c)
    elif name == "laugh":
        blush(c); eyes_arc(c, True); mouth_open(c, w=0.34, depth=0.4)
    elif name == "grumpy":
        blush(c, -0.16); brows(c, brow, False, 0.28); eyes_open(c, 0.05, 0.85); mouth_frown(c)
    elif name == "sleep":
        blush(c); eyes_arc(c, False); mouth_o(c)
    elif name == "shy":
        blush(c); brows(c, brow); eyes_open(c); mouth_wavy(c)
    elif name == "happy":
        blush(c); eyes_arc(c, True); mouth_open(c)
    elif name == "cry":
        tears(c); blush(c); brows(c, brow); eyes_arc(c, False, 0.03); mouth_sad(c)
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
        length = R * SUN_RAY + (R * 0.2 if k % 2 == 0 else 0)
        m = Matrix.Translation(out * R * 0.82) @ Matrix.Rotation(a, 4, "Y") @ Matrix.Diagonal((1, SUN_FLAT, 1, 1))
        bmesh.ops.create_cone(bm, cap_ends=True, segments=10, radius1=R * 0.3, radius2=R * 0.055, depth=length + R * 0.18,
                              matrix=m @ Matrix.Translation((0, 0, (length + R * 0.18) / 2 - R * 0.1)))
    ob = pc.blob("sun", bm, 0.0065, 8, pc.TRIS["sun"])
    ob.data.transform(Matrix.Rotation(TILT, 4, "X"))
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
            if hit is not None and nrm.dot(n_dir) > steep:      # (not up the steep rim: a flat quad would sag into it)
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
    assert worst >= MIN_OUT, f"{name}: a face vertex or triangle centre is {worst * 1000:.1f} mm from the body (< {MIN_OUT * 1000} mm)"
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
    dst, faces_png = sys.argv[sys.argv.index("--") + 1:][:2]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    pc.face_cell = face_cell
    img = pc.build_atlas()
    img.filepath_raw, img.file_format = faces_png, "PNG"
    img.save()
    mats = {"sun": pc.flat_mat("glow-sun", LEMON), "cloud": pc.flat_mat("cloth-cloud", CLOUD_COL, 0.5),
            "drop": pc.flat_mat("ice-drop", (0.60, 0.78, 0.98), 0.15),
            "fsun": pc.face_mat("eyes-mood_sun", img), "fcloud": pc.face_mat("eyes-mood_cloud", img)}
    sun, cloud, dr = sun_body(), pc.cloud_body(), drops()
    for ob, mk in ((sun, "sun"), (cloud, "cloud"), (dr, "drop")):
        ob.data.materials.append(mats[mk])
    bpy.context.view_layer.update()
    check_drops(cloud, dr)
    objs = [sun, cloud, dr]
    f = face_patch("face_sun", sun, SUN_CELL, Vector((0, 0, 0)), TILT)
    f.data.materials.append(mats["fsun"])
    objs.append(f)
    f = face_patch("face_cloud", cloud, CLOUD_CELL, Vector((0, 0, 0.04 * pc.CLOUD_W)), TILT, 0.012, 0.45)
    f.data.materials.append(mats["fcloud"])
    objs.append(f)
    print("COMPANION tris", sum(len(p.vertices) - 2 for ob in objs for p in ob.data.polygons))
    bpy.ops.object.select_all(action="DESELECT")
    for ob in objs:
        ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB", use_selection=True, export_apply=False, export_animations=False,
                              export_materials="EXPORT", export_image_format="AUTO", export_yup=True)
    print("exported", dst)


if __name__ == "__main__":
    main()
