"""Gil's in-game swordfish and satchel, rig and export only (shapes are the master's):
- the swordfish: gil.glb's is the master's own rapier decimated unwelded (1.4k tris: Meshy splits vertices at UV seams,
  so the seams open into shards). It is re-made from the master's rapier by the port's own make_low (welded, UV seams held) at SWORD_TRIS, placed by
  the affine map that takes the master rapier onto the game one (vertices paired through their shared UVs), on the same
  bone as before, a separate mesh with the game's material.
- the robe: the port's weight smoothing spread arm weight over the whole robe (hem and chest centre included), so it
  webbed out to his wrists whenever the arms rose. On the robe and leather, arm weight is kept in full within ARM_NEAR
  of the upper arm and forearm (the sleeves; not the hand, which hangs against the robe's front), faded out by ARM_FAR,
  and given back to the bones the vertex already had (or the skirt below the hips, the hips above). Skin keeps its own.
- the satchel: the leather in the hip box (either hip: the game frame is the fit frame mirrored, the bag hangs at -x)
  rides the hips only (it stretched out with the hand into a flat paddle).
Run: blender -b --factory-startup --python tools/art1/gil_sword_bag.py -- GAME.glb MASTER.glb OUT.glb"""

import os
import sys

import bpy
import numpy as np
from mathutils import Matrix
from mathutils.kdtree import KDTree

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "meshy"))
import bake_warden as BW  # noqa: E402

SWORD_TRIS = 3000  # the rapier's share of the game budget (it was 1.4k, shattered)
SWORD_MAT = "Material_0.001"  # the master's rapier material (gil_v95.json drop_mats)
BAG_MAT = "leather-v95"
BAG_BONE = "hips"
ARM_BONES = ("upper_arm", "forearm", "hand")  # .L/.R
SLEEVE_BONES = ("upper_arm", "forearm")  # the segments a sleeve hangs on
ARM_NEAR, ARM_FAR = 0.07, 0.13  # m from a sleeve bone's segment: full arm weight inside, none past
CLOTH_MATS = ("cloth-v95", "leather-v95")  # the surfaces eased (skin: the hands and arms keep their weights)
BAG_BOX = (
    (0.10, 0.45),
    (-9.0, 9.0),
    (0.40, 0.85),
)  # m, Blender frame |x|, y, z: the satchel and the leather at his hips
FLOATER_VERTS = 60  # loose crumbs under this many vertices are dropped (v95_swap.py's default)


def import_game(path):
    """The game .glb as v95_swap.py reads it (bone axes as exported, so the rest re-exports unchanged)."""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path, bone_heuristic="BLENDER")
    return [o for o in bpy.data.objects if o not in before]


def world_arrays(ob):
    me = ob.data
    co = np.empty(len(me.vertices) * 3)
    me.vertices.foreach_get("co", co)
    M = np.array(ob.matrix_world)
    co = co.reshape(-1, 3) @ M[:3, :3].T + M[:3, 3]
    uv = np.empty(len(me.loops) * 2)
    me.uv_layers.active.data.foreach_get("uv", uv)
    lv = np.empty(len(me.loops), int)
    me.loops.foreach_get("vertex_index", lv)
    vuv = np.zeros((len(me.vertices), 2))
    vuv[lv] = uv.reshape(-1, 2)
    return co, vuv


def uv_affine(src_ob, dst_ob):
    """Affine map (4x4) taking src's vertices onto dst's, pairs by nearest UV, refit without the worst 20%."""
    sco, suv = world_arrays(src_ob)
    dco, duv = world_arrays(dst_ob)
    kd = KDTree(len(suv))
    for i, u in enumerate(suv):
        kd.insert((u[0], u[1], 0.0), i)
    kd.balance()
    idx = np.array([kd.find((u[0], u[1], 0.0))[1] for u in duv])
    src, dst = np.c_[sco[idx], np.ones(len(idx))], dco
    keep = np.ones(len(idx), bool)
    for _ in range(3):
        X = np.linalg.lstsq(src[keep], dst[keep], rcond=None)[0]
        err = np.linalg.norm(src @ X - dst, axis=1)
        keep = err <= np.percentile(err, 80)
    print("GIL sword map residual median %.4f m" % np.median(err[keep]), flush=True)
    M = np.eye(4)
    M[:3, :] = X.T
    return Matrix(M.tolist())


def main():
    game_path, master_path, out = sys.argv[sys.argv.index("--") + 1 :][:3]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    new = import_game(game_path)
    arm = next(o for o in new if o.type == "ARMATURE")
    meshes = sorted((o for o in new if o.type == "MESH" and o.vertex_groups), key=lambda o: len(o.data.vertices))
    body, old = meshes[-1], meshes[0]
    bones = {old.vertex_groups[g.group].name for v in old.data.vertices for g in v.groups if g.weight > 0.01}
    assert len(bones) == 1, bones
    bone = bones.pop()

    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=master_path)
    src = next(
        o
        for o in bpy.data.objects
        if o not in before and o.type == "MESH" and o.data.materials and o.data.materials[0].name.startswith(SWORD_MAT)
    )
    for o in [o for o in bpy.data.objects if o not in before and o != src]:
        bpy.data.objects.remove(o)
    M = uv_affine(src, old)

    # the rapier: welded, decimated, mapped, on the old bone with the game's material
    src.data.transform(src.matrix_world)
    src.matrix_world.identity()
    bpy.ops.object.select_all(action="DESELECT")
    low = BW.make_low(src, SWORD_TRIS, FLOATER_VERTS, keep_uv=True)  # the port's own decimation (welded, seams held)
    bpy.data.objects.remove(src)
    src = low
    src.data.transform(M)
    src.data.materials.clear()
    src.data.materials.append(old.data.materials[0])
    vg = src.vertex_groups.new(name=bone)
    vg.add(list(range(len(src.data.vertices))), 1.0, "REPLACE")
    src.parent = arm
    src.matrix_parent_inverse = arm.matrix_world.inverted()
    src.modifiers.new("Armature", "ARMATURE").object = arm
    name, mesh_name = old.name, old.data.name
    bpy.data.objects.remove(old)
    src.name, src.data.name = name, mesh_name
    print("GIL sword tris", len(src.data.polygons), "bone", bone, flush=True)

    # the robe off the arms
    segs = []
    for b in arm.data.bones:
        if b.name.split(".")[0] in SLEEVE_BONES:
            segs.append((np.array(arm.matrix_world @ b.head_local), np.array(arm.matrix_world @ b.tail_local)))
    names = [g.name for g in body.vertex_groups]
    is_arm = [n.split(".")[0] in ARM_BONES for n in names]
    hips_z = (arm.matrix_world @ arm.data.bones["hips"].head_local).z
    co = np.array([(body.matrix_world @ v.co)[:] for v in body.data.vertices])
    dist = np.full(len(co), np.inf)
    for h, t in segs:
        d = t - h
        u = np.clip(((co - h) @ d) / (d @ d), 0, 1)
        dist = np.minimum(dist, np.linalg.norm(co - (h + u[:, None] * d), axis=1))
    keep = np.clip((ARM_FAR - dist) / (ARM_FAR - ARM_NEAR), 0, 1)
    cloth_idx = [i for i, m in enumerate(body.data.materials) if m.name in CLOTH_MATS]
    on_cloth = np.zeros(len(co), bool)
    for p in body.data.polygons:
        if p.material_index in cloth_idx:
            on_cloth[list(p.vertices)] = True
    keep[~on_cloth] = 1.0
    eased = 0
    for v in body.data.vertices:
        ws = {g.group: g.weight for g in v.groups}
        a = sum(w for gi, w in ws.items() if is_arm[gi])
        if a <= 0 or keep[v.index] >= 1:
            continue
        eased += 1
        new_a = {gi: w * keep[v.index] for gi, w in ws.items() if is_arm[gi]}
        rest = {gi: w for gi, w in ws.items() if not is_arm[gi] and w > 0}
        left = max(0.0, sum(ws.values()) - sum(new_a.values()))
        if not rest:
            rest = {names.index("skirt" if co[v.index][2] < hips_z else "hips"): 1.0}
        tot = sum(rest.values())
        for gi, w in new_a.items():
            if w > 1e-4:
                body.vertex_groups[gi].add([v.index], w, "REPLACE")
            else:
                body.vertex_groups[gi].remove([v.index])
        for gi, w in rest.items():
            body.vertex_groups[gi].add([v.index], left * w / tot, "REPLACE")
    print("GIL robe verts eased off the arms", eased, flush=True)

    # the satchel on the hips
    mi = [m.name for m in body.data.materials].index(BAG_MAT)
    on_bag = set()
    for p in body.data.polygons:
        if p.material_index == mi:
            on_bag.update(p.vertices)
    Mw = body.matrix_world
    hips = body.vertex_groups[BAG_BONE]
    moved = 0
    for i in on_bag:
        v = body.data.vertices[i]
        w = Mw @ v.co
        if all(lo <= c <= hi for c, (lo, hi) in zip((abs(w.x), w.y, w.z), BAG_BOX)):
            for g in list(v.groups):
                if g.group != hips.index:
                    body.vertex_groups[g.group].remove([i])
            hips.add([i], 1.0, "REPLACE")
            moved += 1
    print("GIL satchel verts on", BAG_BONE, moved, flush=True)

    for o in bpy.data.objects:
        o.select_set(o.type != "MESH" or o in (body, src))
    bpy.context.view_layer.objects.active = arm
    bpy.ops.export_scene.gltf(
        filepath=out,
        export_format="GLB",
        use_selection=True,
        export_apply=False,
        export_animations=True,
        export_animation_mode="ACTIONS",
        export_skins=True,
        export_yup=True,
        export_materials="EXPORT",
        export_image_format="JPEG",
        export_jpeg_quality=92,
        export_extras=False,
        export_vertex_color="ACTIVE",
        export_force_sampling=True,
        export_frame_step=1,
        export_optimize_animation_size=False,
        export_def_bones=False,
    )
    print("GIL exported", out, flush=True)


main()
