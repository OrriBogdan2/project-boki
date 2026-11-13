"""v95 swap, step 2 (docs/art/wardens/V95_SWAP.md): a v95 master (Meshy, ~1.5M triangles, 8k paint) into a game Warden, on the
Warden's own skeleton, clips and anchors, which come from its current .glb and stay as they are.
 1. Bake (once, cached in WORK): bake_warden.py's low mesh (`tris`, `head_tris` round `head`) and UVs, the old model's parts
    that ride the `keep` bones (Grimble's junk ball) packed beside it, and one `tex` atlas: the master's base colour on the
    low mesh, the old atlas on the kept parts. The game .glb is copied to WORK/game.glb: later runs start from it.
 2. Fit (grimble_source.py's method): each limb segment of the master (its `joints`) moves onto the rig's, a length along
    the bone and a girth across it; the limbs take the rig's joint heights and keep the master's spread, or with `spread`
    "rig" sit on the rig's joints; past a segment's ends the master keeps its own scale (a hook, a gauntlet keep their shape).
 3. Weights: bone heat on the body bones, `past_wrist` (the bone that takes each hand's weights: Grimble's hook), then
    `regions` in order (a later one wins): boxes moved whole onto one bone, minus `except_segs` capsules and `except_boxes`, within `in_segs` capsules if given.
    `detach` bone pairs ("*": any other) are cut apart and both openings capped: a scan fuses the gun to the belt and the
    pack to the shoulders, and the clips swing those apart. `smooth` passes widen the blends.
 4. Toon slots per triangle (`slots`, first match wins: hue/sat/value ranges of the paint, a bone, a box), the ink room per
    bone (`room`), the anchors moved onto the new mesh (`anchors`, through the same fit), `move_bones` (a kept part's bone
    moved at rest, its clips' translation keys corrected), skin_relax (no edge past 1.3x in any clip), and the .glb.
Points in the spec are in the fit frame: his front +Y, his right +X, soles on z 0, the master's metres (v95_grid.py).
Run: blender -b --factory-startup --python tools/art1/v95_swap.py -- SPEC WORK OUT_GLB"""
import json
import os
import shutil
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path[:0] = [HERE, os.path.join(REPO, "tools", "meshy")]
import bake_warden as BW
import fit_warden as FW
import skin_relax
from meshkit import smooth
from posekit import FPS

ARGS = sys.argv[sys.argv.index("--") + 1:]
SPEC = json.load(open(ARGS[0]))
WORK = os.path.expanduser(ARGS[1])
OUT = os.path.abspath(ARGS[2])
F = np.float32
LIMBS = ("upper_arm", "forearm", "thigh", "shin")
CAGE, RAY, MARGIN_PX = 0.008, 0.03, 16       # (m, m, px) bake_warden's defaults
CAP_SIDES = 2000             # the longest opening a detach caps (edges round it)
BODY = ("hips", "head", "upper_arm.R", "upper_arm.L", "forearm.R", "forearm.L", "hand.R", "hand.L", "thigh.R", "thigh.L", "shin.R",
        "shin.L", "foot.R", "foot.L")        # the bones bone heat weighs
KEPT_DENSITY = 0.5           # the kept parts' texels per metre, x the body's (the junk ball hides in the sack at rest)


def verts(ob):
    a = np.empty(len(ob.data.vertices) * 3)
    ob.data.vertices.foreach_get("co", a)
    return a.reshape(-1, 3)


def set_verts(ob, v):
    ob.data.vertices.foreach_set("co", np.asarray(v, F).ravel())
    ob.data.update()


def select(obs, active):
    bpy.ops.object.select_all(action="DESELECT")
    for o in obs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = active


def import_game(path):
    """The game .glb: its armature (bone axes as exported, so the rest re-exports unchanged), clips, anchors and mesh."""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path, bone_heuristic="BLENDER")
    new = [o for o in bpy.data.objects if o not in before]
    meshes = [o for o in new if o.type == "MESH"]       # the body is the biggest (Hem's bow and arrow are meshes of their own)
    return next(o for o in new if o.type == "ARMATURE"), max(meshes, key=lambda o: len(o.data.vertices))


def kept_parts(old, bones, mats):
    """A copy of the old mesh's faces whose vertices ride mostly `bones` or whose material is in `mats` (Kael's skinned sword),
    unparented, its UVs as layer "old"."""
    ob = old.copy()
    ob.data = old.data.copy()
    ob.name = "Kept"
    bpy.context.scene.collection.objects.link(ob)
    mw = ob.matrix_world.copy()
    ob.parent = None
    ob.matrix_world = mw
    ob.modifiers.clear()
    name = {g.index: g.name for g in ob.vertex_groups}
    by_mat = {i for p in ob.data.polygons if ob.data.materials[p.material_index].name in mats for i in p.vertices}
    drop = [v.index for v in ob.data.vertices if v.index not in by_mat
            and (not v.groups or name[max(v.groups, key=lambda e: e.weight).group] not in bones)]
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bm.verts.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[bm.verts[i] for i in drop], context="VERTS")
    bm.to_mesh(ob.data)
    bm.free()
    ob.data.uv_layers[0].name = "old"
    ob.data.uv_layers.new(name="UVMap", do_init=True)
    ob.data.uv_layers["UVMap"].active = True
    ob.data.uv_layers["UVMap"].active_render = True
    ob["slots"] = ",".join(ob.data.materials[p.material_index].name for p in ob.data.polygons)     # (whole: "flame-jet")
    return ob


def uv_density(ob):
    """UV area per 3D area."""
    me = ob.data
    lv = np.empty(len(me.loops), np.int32)
    me.loops.foreach_get("vertex_index", lv)
    uv = np.empty(len(me.loops) * 2, F)
    me.uv_layers["UVMap"].data.foreach_get("uv", uv)
    t3, tu = verts(ob)[lv.reshape(-1, 3)], uv.reshape(-1, 3, 2)
    a3 = np.linalg.norm(np.cross(t3[:, 1] - t3[:, 0], t3[:, 2] - t3[:, 0]), axis=1).sum()
    e1, e2 = tu[:, 1] - tu[:, 0], tu[:, 2] - tu[:, 0]
    return np.abs(e1[:, 0] * e2[:, 1] - e1[:, 1] * e2[:, 0]).sum() / max(a3, 1e-9), uv


def fill_misses(body, steps):
    """Base-colour texels the bake missed take their neighbours' colour, up to `steps` texels in (in place). A miss is
    exactly black: a ray that found no surface, as from a triangle the decimation folded under (Sparkle's forehead,
    Cinder's arm in the 11-12 swaps; no cage size reached them). Painted black never bakes to exactly 0, and the empty
    space between islands only gains padding."""
    rgb = body[..., :3]
    hole = rgb.max(-1) == 0
    for _ in range(steps):
        if not hole.any():
            break
        acc, cnt = np.zeros_like(rgb), np.zeros(hole.shape, F)
        for ax, sh in ((0, 1), (0, -1), (1, 1), (1, -1)):
            ok = np.roll(~hole, sh, ax)
            acc += np.roll(rgb, sh, ax) * ok[..., None]
            cnt += ok
        new = hole & (cnt > 0)
        rgb[new] = acc[new] / cnt[new][:, None]
        hole &= ~new


def lay_kept(old, kept, body, tex, socket="Base Color"):
    """The old atlas (or the image on its `socket`) baked onto the kept parts' new UVs, laid over the body's pixels (in place)."""
    old_img = BW.base_image(old, socket)
    if old_img is None:
        return
    ks = kept.copy()
    ks.data = kept.data.copy()
    bpy.context.scene.collection.objects.link(ks)
    ks.data.uv_layers["old"].active_render = True
    ks.data.materials.clear()
    m = bpy.data.materials.new("kept_src")
    m.use_nodes = True
    nt = m.node_tree
    t = nt.nodes.new("ShaderNodeTexImage")
    t.image = old_img
    em = nt.nodes.new("ShaderNodeEmission")
    nt.links.new(t.outputs[0], em.inputs[0])
    nt.links.new(em.outputs[0], nt.nodes["Material Output"].inputs["Surface"])
    ks.data.materials.append(m)
    over = bpy.data.images.new("kept", tex, tex, alpha=True)
    over.generated_color = (0, 0, 0, 0)
    km = bpy.data.materials.new("kept_dst")
    km.use_nodes = True
    kn = km.node_tree.nodes.new("ShaderNodeTexImage")
    kn.image = over
    km.node_tree.nodes.active = kn
    kept.data.materials.clear()
    kept.data.materials.append(km)
    select([ks, kept], kept)
    bpy.ops.object.bake(type="EMIT", use_selected_to_active=True, cage_extrusion=0.004, max_ray_distance=0.01, margin=2,
                        margin_type="EXTEND", use_clear=False)
    top = np.array(over.pixels[:], F).reshape(tex, tex, 4)
    body[:] = np.where(top[..., 3:] > 0.5, top, body)


def bake():
    """Step 1: WORK/bake.blend (Low in the master's frame, Kept in the game's, the atlas packed) and WORK/game.glb."""
    os.makedirs(WORK, exist_ok=True)
    game = os.path.join(WORK, "game.glb")
    if not os.path.exists(game):
        shutil.copy(os.path.join(REPO, SPEC["game"]), game)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    high = BW.import_dense(os.path.expanduser(SPEC["master"]))
    sole = min(v.co.z for v in high.data.vertices)
    hd = SPEC.get("head")
    if hd:          # (fit frame -> the master's)
        x, y, z = hd["centre"]
        hd = {"centre": [-x, -y, z + sole], "r": hd["r"]}
    low = BW.make_low(high, int(SPEC["tris"]), int(SPEC.get("floater_verts", 60)), hd, int(SPEC.get("head_tris", 0)))
    BW.unwrap(low, hd, float(SPEC.get("head_uv", 2.0)), float(SPEC.get("uv_margin", 0.0008)), float(SPEC.get("uv_angle", 66.0)),
              int(SPEC.get("uv_smooth", 30)))
    arm, old = import_game(game)
    kept = kept_parts(old, SPEC.get("keep", []), SPEC.get("keep_mats", []))
    d_low, _ = uv_density(low)
    d_kept, uv = uv_density(kept)
    kept.data.uv_layers["UVMap"].data.foreach_set("uv", (uv * np.sqrt(d_low * KEPT_DENSITY / max(d_kept, 1e-12))).ravel())
    select([low, kept], low)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.context.scene.tool_settings.use_uv_select_sync = True
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.pack_islands(rotate=True, scale=True, margin_method="FRACTION", margin=float(SPEC.get("uv_margin", 0.0008)),
                            shape_method="CONCAVE")
    bpy.ops.object.mode_set(mode="OBJECT")
    tex = int(SPEC.get("tex", 2048))
    layers = [("atlas", "Base Color", None)]
    if SPEC.get("emit"):        # the master's emission map (Cinder's lava seams) on a second image, the game's emissive texture
        layers.append(("emit", "Emission Color", BW.base_image(high, "Emission Color")))
    for name, socket, src in layers:
        low.data.materials.clear()
        img = BW.bake_colour(high, low, tex, CAGE, RAY, MARGIN_PX, src)
        body = np.array(img.pixels[:], F).reshape(tex, tex, 4)
        if name == "atlas":     # (not the emission map, where black is no glow)
            fill_misses(body, max(32, tex // 64))
        if kept.data.polygons:  # the kept parts: the old image onto their new UVs, on an image of their own, laid over the body's
            lay_kept(old, kept, body, tex, socket)
        body[..., 3] = 1
        img.pixels = body.ravel()
        if name in bpy.data.images:     # (the game glb's own image of that name: Cinder's "atlas" and "emit")
            bpy.data.images[name].name = name + "-game"
        img.name = name
        img.filepath_raw = os.path.join(WORK, name + ".png")
        img.file_format = "PNG"
        img.save()
        img.pack()
        img.use_fake_user = True
    for o in list(bpy.data.objects):
        if o not in (low, kept):
            bpy.data.objects.remove(o)
    low.data.materials.clear()
    kept.data.materials.clear()
    bpy.context.scene["sole"] = sole
    bpy.ops.outliner.orphans_purge(do_recursive=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(WORK, "bake.blend"))


# ----------------------------------------------------- step 2: the fit (grimble_source.py's, from the spec)
S_J = {k: np.array(v, float) for k, v in SPEC["joints"].items()}
SEG = [("torso", "pelvis", "neck", 0.30), ("headseg", "neck", "crown", 0.12)]
for _sd in "RL":
    SEG += [("upper_arm." + _sd, "shoulder." + _sd, "elbow." + _sd, 0.10), ("forearm." + _sd, "elbow." + _sd, "wrist." + _sd, 0.09),
            ("thigh." + _sd, "hip." + _sd, "knee." + _sd, 0.13), ("shin." + _sd, "knee." + _sd, "ankle." + _sd, 0.10)]
SEG_NAMES = [s[0] for s in SEG]


def targets(arm):
    """The rig's joints for the master's: the limbs keep the master's spread (x K) and take the rig's joint heights, or with
    `spread` "rig" sit on the rig's joints."""
    head = {b.name: np.array(b.head_local, float) for b in arm.data.bones}
    k = head["hips"][2] / S_J["pelvis"][2]

    def on_rig(j, z, at=None):
        if at is not None and SPEC.get("spread") == "rig":
            return at
        return (S_J[j] - (S_J["pelvis"][0], S_J["pelvis"][1], 0)) * (k, k, 0) + (0, 0, z)

    t = {"pelvis": head["hips"], "neck": on_rig("neck", head["head"][2])}
    t["crown"] = t["neck"] + (S_J["crown"] - S_J["neck"]) * k
    for sd in "RL":
        for j, b in (("shoulder", "upper_arm"), ("elbow", "forearm"), ("wrist", "hand"), ("hip", "thigh"), ("knee", "shin")):
            t[j + "." + sd] = on_rig(j + "." + sd, head[b + "." + sd][2], head[b + "." + sd])
        t["ankle." + sd] = on_rig("ankle." + sd, S_J["ankle." + sd][2] * k, head.get("foot." + sd))
    return t, k


def seg_off(P, j0, j1):
    """Each point's offset from its nearest point on the segment j0-j1."""
    a0, u = S_J[j0], S_J[j1] - S_J[j0]
    h = np.clip(((P - a0) @ u) / (u @ u), 0, 1)
    return P - (a0 + h[:, None] * u)


def seg_dist(P, j0, j1):
    return np.linalg.norm(seg_off(P, j0, j1), axis=1)


def seg_weights(P):
    D = np.zeros((len(P), len(SEG)))
    for i, (nm, j0, j1, rad) in enumerate(SEG):
        squash = (0.75, 1.0, 1.0) if nm == "torso" else (1.0, 1.0, 1.0)      # (the torso's capsule is flatter across)
        D[:, i] = np.linalg.norm(seg_off(P, j0, j1) * squash, axis=1) - rad
        if nm.endswith(".R"):
            D[P[:, 0] < S_J["pelvis"][0] + 0.01, i] = 9.0
        if nm.endswith(".L"):
            D[P[:, 0] > S_J["pelvis"][0] - 0.01, i] = 9.0
        if nm.startswith(("thigh", "shin")):
            D[P[:, 2] > S_J["pelvis"][2] + 0.12, i] = 9.0
        if nm == "headseg":
            D[P[:, 2] < S_J["neck"][2] - 0.04, i] = 9.0
    W = np.exp(-(D - D.min(1, keepdims=True)) / 0.03)
    return W / W.sum(1, keepdims=True)


def region_masks(P):
    """(bone, mask) per spec region."""
    out = []
    for r in SPEC.get("regions", []):
        x0, x1, y0, y1, z0, z1 = r["box"]
        m = (P[:, 0] >= x0) & (P[:, 0] <= x1) & (P[:, 1] >= y0) & (P[:, 1] <= y1) & (P[:, 2] >= z0) & (P[:, 2] <= z1)
        for seg, rad in r.get("except_segs", []):
            j0, j1 = next((s[1], s[2]) for s in SEG if s[0] == seg)
            m &= seg_dist(P, j0, j1) >= rad
        for seg, rad in r.get("in_segs", []):     # only within these capsules (a limb pinned whole where a part touches it)
            j0, j1 = next((s[1], s[2]) for s in SEG if s[0] == seg)
            m &= seg_dist(P, j0, j1) < rad
        for x0, x1, y0, y1, z0, z1 in r.get("except_boxes", []):
            m &= ~((P[:, 0] >= x0) & (P[:, 0] <= x1) & (P[:, 1] >= y0) & (P[:, 1] <= y1) & (P[:, 2] >= z0) & (P[:, 2] <= z1))
        out.append((r["bone"], m))
    return out


def seg_of(arm, bone):
    """The segment a bone's rigid part moves with in the fit: its first ancestor that is a limb or the head."""
    b = arm.data.bones[bone]
    while b:
        if b.name in SEG_NAMES:
            return b.name
        side = b.name[-2:]
        if b.name in ("hand" + side, "foot" + side):
            return ("forearm" if b.name.startswith("hand") else "shin") + side
        if b.name == "head":
            return "headseg"
        b = b.parent
    return "torso"


def fit_weights(arm, P):
    W = seg_weights(P)
    for bone, m in region_masks(P):
        W[m] = np.eye(len(SEG))[SEG_NAMES.index(seg_of(arm, bone))]
    return W


def rot_between(u, v):
    u, v = u / np.linalg.norm(u), v / np.linalg.norm(v)
    c = np.cross(u, v)
    s, d = np.linalg.norm(c), u @ v
    if s < 1e-7:
        return np.eye(3)
    k = np.array([[0, -c[2], c[1]], [c[2], 0, -c[0]], [-c[1], c[0], 0]]) / s
    return np.eye(3) + k * s + k @ k * (1 - d)


def fit(P, W, T, K):
    Q = np.zeros_like(P)
    for i, (nm, j0, j1, rad) in enumerate(SEG):
        p0, p1, q0, q1 = S_J[j0], S_J[j1], T[j0], T[j1]
        ln = np.linalg.norm(p1 - p0)
        u, v = (p1 - p0) / ln, (q1 - q0) / np.linalg.norm(q1 - q0)
        r = P - p0
        ax = r @ u
        inside = np.clip(ax, 0, ln)
        ax2 = inside * (np.linalg.norm(q1 - q0) / ln) + (ax - inside) * K       # (past the ends: the master's own scale)
        Q += W[:, i, None] * (q0 + ax2[:, None] * v + ((r - ax[:, None] * u) * K) @ rot_between(u, v).T)
    return Q


def capsule_weights(low, arm):
    """`weights` "capsule": each body bone's soft share by distance to its segment (minus its `radius`), never across the
    midline for a sided bone nor above the pelvis for a leg bone, the hips reaching the neck; smooth in space, so it cannot
    fail on a scan's loose or fused pieces the way bone heat does."""
    head = {b.name: np.array(b.head_local, float) for b in arm.data.bones}
    tail = {b.name: np.array(b.tail_local, float) for b in arm.data.bones}
    tail["hips"] = head["head"]
    for sd in "RL":     # (a hand bone is short or a stub: it reaches on along the forearm)
        u = tail["forearm." + sd] - head["forearm." + sd]
        tail["hand." + sd] = head["hand." + sd] + u / np.linalg.norm(u) * max(np.linalg.norm(tail["hand." + sd] - head["hand." + sd]), 0.3)
    rad = SPEC.get("radius", {})
    V = verts(low)
    names = [b for b in BODY if b in head]
    D = np.zeros((len(V), len(names)))
    for i, nm in enumerate(names):
        a, u = head[nm], tail[nm] - head[nm]
        h = np.clip(((V - a) @ u) / (u @ u), 0, 1)
        off = (V - (a + h[:, None] * u)) * ((0.75, 1, 1) if nm == "hips" else (1, 1, 1))
        D[:, i] = np.linalg.norm(off, axis=1) - rad.get(nm.split(".")[0], 0.06)
        if nm.endswith(".R"):
            D[V[:, 0] < -0.01, i] = 9.0
        if nm.endswith(".L"):
            D[V[:, 0] > 0.01, i] = 9.0
        if nm.split(".")[0] in ("thigh", "shin", "foot"):
            D[V[:, 2] > head["hips"][2] + 0.12, i] = 9.0
    W = np.exp(-(D - D.min(1, keepdims=True)) / float(SPEC.get("falloff", 0.035)))
    W /= W.sum(1, keepdims=True)
    return {nm: W[:, i] for i, nm in enumerate(names)}


def heat_weights(low, arm, P):
    """Step 3: bone heat (fit_warden.auto_weights) on the body bones of a copy of the rig whose hips bone reaches the neck
    (the contract has no spine: left alone, the chest goes to the arms and the head); then `past_wrist` (each hand's
    weights to its bone) and the `regions`, whole."""
    if SPEC.get("weights") == "capsule":
        return place_weights(capsule_weights(low, arm), P)
    tmp = arm.copy()
    tmp.data = arm.data.copy()
    tmp.animation_data_clear()
    bpy.context.scene.collection.objects.link(tmp)
    select([tmp], tmp)
    bpy.ops.object.mode_set(mode="EDIT")
    eb = tmp.data.edit_bones
    eb["hips"].tail = eb["head"].head
    bpy.ops.object.mode_set(mode="OBJECT")
    for b in tmp.data.bones:
        b.use_deform = b.name in BODY
    FW.auto_weights(low, tmp)
    gi = {g.index: g.name for g in low.vertex_groups}
    gr = {nm: np.zeros(len(P)) for nm in BODY if nm in arm.data.bones}
    for v in low.data.vertices:
        for e in v.groups:
            if gi[e.group] in gr:
                gr[gi[e.group]][v.index] = e.weight
    low.vertex_groups.clear()
    low.modifiers.clear()
    low.parent = None
    bpy.data.objects.remove(tmp)
    return place_weights(gr, P)


def place_weights(gr, P):
    """Each hand's weights to its `past_wrist` bone, then the `regions`, whole."""
    for sd, bone in SPEC["past_wrist"].items():
        hand = gr.pop("hand." + sd)
        gr[bone] = gr.get(bone, 0) + hand
    for bone, m in region_masks(P):
        for nm in gr:
            gr[nm] = gr[nm] * ~m
        gr[bone] = gr.get(bone, np.zeros(len(P))) + m
    return gr


def set_groups(ob, gr):
    names = list(gr)
    a = np.stack([np.broadcast_to(gr[k], (len(ob.data.vertices),)) for k in names], 1)
    idx = np.argsort(-a, axis=1)[:, :4]
    top = np.take_along_axis(a, idx, 1)
    top[top < top[:, :1] * 0.05] = 0
    top /= np.maximum(top.sum(1, keepdims=True), 1e-6)
    for i, nm in enumerate(names):
        vg = ob.vertex_groups.new(name=nm)
        r = np.nonzero((idx == i) & (top > 0))
        for v, c in zip(r[0].tolist(), r[1].tolist()):
            vg.add([v], float(top[v, c]), "REPLACE")
    return np.array(names)[idx[:, 0]]


def partners(bone, bones):
    """The bones a `detach` pair cuts `bone` from."""
    out = set()
    for x, y in SPEC.get("detach", []):
        if x == bone:
            out |= set(bones) - {bone} if y == "*" else {y}
        elif y == bone or y == "*":
            out.add(x)
    return (out & set(bones)) - {bone}


def detach(low, G, names):
    """Cuts the faces of each `detach` bone pair apart ("*": any other bone) and caps both openings: a scan fuses the gun to
    the belt, the pack to the shoulders, the hook's crescent to the shin, and those bones swing apart in the clips. Each
    face goes with its vertices' main bone; afterwards a vertex keeps no weight on a bone its faces were cut from.
    Returns the weights [vertex, bone] of the cut mesh and each vertex's index before the cut."""
    dom = np.array(names)[G.argmax(1)]
    cuts = {nm: partners(nm, names) for nm in names}
    bm = bmesh.new()
    bm.from_mesh(low.data)
    orig = bm.verts.layers.int.new("orig")
    for v in bm.verts:
        v[orig] = v.index
    lab = {}
    for f in bm.faces:
        votes = [dom[v.index] for v in f.verts]
        lab[f] = max(set(votes), key=votes.count)
    cut = [e for e in bm.edges if len(e.link_faces) == 2 and lab[e.link_faces[1]] in cuts[lab[e.link_faces[0]]]]
    ends = {v.index for e in cut for v in e.verts}
    bmesh.ops.split_edges(bm, edges=cut)
    rim = [e for e in bm.edges if len(e.link_faces) == 1 and all(v[orig] in ends for v in e.verts)]
    caps = bmesh.ops.triangulate(bm, faces=bmesh.ops.holes_fill(bm, edges=rim, sides=CAP_SIDES)["faces"])["faces"]
    bmesh.ops.recalc_face_normals(bm, faces=caps)
    uv = bm.loops.layers.uv.active
    capset = set(caps)
    for f in caps:              # (a cap takes the paint its rim's vertices have on the body)
        for lp in f.loops:
            src = next((l2 for l2 in lp.vert.link_loops if l2.face not in capset), None)
            if src is not None:
                lp[uv].uv = src[uv].uv
    bm.verts.index_update()
    o = np.array([v[orig] for v in bm.verts])
    W = G[o].copy()
    col = {nm: i for i, nm in enumerate(names)}
    for v in bm.verts:
        drop = set().union(*(cuts[lab[f]] for f in v.link_faces if f in lab))
        keep = W[v.index].copy()
        keep[[col[nm] for nm in drop]] = 0
        if keep.sum() > 1e-6:
            W[v.index] = keep / keep.sum()
        else:           # (all its weight was on bones it is cut from: its faces' own bone)
            own = lab[next(f for f in v.link_faces if f in lab)]
            W[v.index] = np.eye(len(names))[col[own]]
    bm.to_mesh(low.data)
    bm.free()
    low.data.update()
    print("detach: %d edges cut, %d cap triangles" % (len(cut), len(caps)), flush=True)
    return W, o


def smooth_weights(low, W, passes):
    """Each pass blends every vertex's weights halfway toward its neighbours' mean (not across a detach cut): wider blends
    stretch each edge less in the clips."""
    ed = np.empty(len(low.data.edges) * 2, np.int64)
    low.data.edges.foreach_get("vertices", ed)
    ed = ed.reshape(-1, 2)
    cnt = np.bincount(ed.ravel(), minlength=len(W)).astype(float)[:, None]
    for _ in range(passes):
        acc = np.zeros_like(W)
        np.add.at(acc, ed[:, 0], W[ed[:, 1]])
        np.add.at(acc, ed[:, 1], W[ed[:, 0]])
        W = np.where(cnt > 0, 0.5 * W + 0.5 * acc / np.maximum(cnt, 1), W)
    return W


def move_bones(arm, kept, T, K):
    """`move_bones` {bone: offset}: the bone's rest (and the kept parts on it) moves by the offset; its translation keys lose
    the offset in proportion to how far each goes toward the largest one, so the clips still end where they did (the junk
    ball hides in the new body at rest and still grows round him in a dash). {bone: {"to": point, "chain": [bones]}}: the
    bone's head onto a master point (through the fit) and its chain by the same offset, the keys as they were (Albert's fish
    onto the master's mast)."""
    for name, spec in SPEC.get("move_bones", {}).items():
        bones, fix = [name], not isinstance(spec, dict)
        if fix:
            d = Vector(spec)
        else:
            p = np.array([spec["to"]], float)
            d = Vector(fit(p, fit_weights(arm, p), T, K)[0]) - arm.data.bones[name].head_local
            bones += spec.get("chain", [])
        rest = {bn: (arm.data.bones[bn].head_local.copy(), arm.data.bones[bn].tail_local.copy()) for bn in bones}
        for bn in bones:
            move_bone(arm, kept, bn, d, fix)
        select([arm], arm)
        bpy.ops.object.mode_set(mode="EDIT")
        for bn, (h, t) in rest.items():     # (from the rest as it was: a connected child follows its parent's tail)
            arm.data.edit_bones[bn].head = h + d
            arm.data.edit_bones[bn].tail = t + d
        bpy.ops.object.mode_set(mode="OBJECT")


def move_bone(arm, kept, name, d, fix):
    """One bone's keys (corrected if `fix`) and kept parts."""
    b = arm.data.bones[name]
    dl = b.matrix_local.to_3x3().inverted() @ d
    path = 'pose.bones["%s"].location' % name
    curves = [[fc for fc in act.fcurves if fc.data_path == path] for act in bpy.data.actions]
    keys = [np.array([[kp.co[1] for kp in fc.keyframe_points] for fc in sorted(cs, key=lambda c: c.array_index)])
            for cs in curves if len(cs) == 3]
    far = max((k.T for k in keys), key=lambda t: np.linalg.norm(t, axis=1).max()) if keys and fix else np.zeros((1, 3))
    top = far[np.linalg.norm(far, axis=1).argmax()]
    for cs in curves if top @ top > 1e-12 else []:     # keys all at rest (Sparkle's gum only scales): nothing to correct
        if len(cs) != 3:
            continue
        cs = sorted(cs, key=lambda c: c.array_index)
        loc = np.array([[kp.co[1] for kp in fc.keyframe_points] for fc in cs]).T
        frac = loc @ top / float(top @ top)
        for i, fc in enumerate(cs):
            for kp, v in zip(fc.keyframe_points, loc[:, i] - frac * dl[i]):
                kp.co[1] = kp.handle_left[1] = kp.handle_right[1] = v
    if name in kept.vertex_groups:
        gi = kept.vertex_groups[name].index
        for v in kept.data.vertices:
            if any(g.group == gi and g.weight > 0.5 for g in v.groups):
                v.co += d
    print("moved", name, tuple(round(x, 3) for x in d), "keys", len(keys), flush=True)


# ----------------------------------------------------- step 4: slots, ink room, anchors
def hsv(rgb):
    mx, mn = rgb.max(1), rgb.min(1)
    d = np.maximum(mx - mn, 1e-6)
    r, g, b = rgb.T
    h = np.where(mx == r, ((g - b) / d) % 6, np.where(mx == g, (b - r) / d + 2, (r - g) / d + 4)) / 6
    return h, (mx - mn) / np.maximum(mx, 1e-6), mx


def tri_slots(ob, img, top_bone, P):
    me = ob.data
    n = img.size[0]
    px = np.array(img.pixels[:], F).reshape(n, n, 4)[..., :3]
    uv = np.empty(len(me.loops) * 2, F)
    me.uv_layers["UVMap"].data.foreach_get("uv", uv)
    c = uv.reshape(-1, 3, 2).mean(1)
    rgb = px[np.clip((c[:, 1] * n).astype(int), 0, n - 1), np.clip((c[:, 0] * n).astype(int), 0, n - 1)]
    h, s, v = hsv(rgb)
    lv = np.empty(len(me.loops), np.int32)
    me.loops.foreach_get("vertex_index", lv)
    tb = top_bone[lv.reshape(-1, 3)[:, 0]]
    cen = P[lv.reshape(-1, 3)].mean(1)
    out = np.full(len(c), SPEC["slot_default"], object)
    done = np.zeros(len(c), bool)
    for r in SPEC["slots"]:
        m = ~done
        if "bone" in r:
            m &= tb == r["bone"]
        if "box" in r:
            x0, x1, y0, y1, z0, z1 = r["box"]
            m &= (cen[:, 0] >= x0) & (cen[:, 0] <= x1) & (cen[:, 1] >= y0) & (cen[:, 1] <= y1) & (cen[:, 2] >= z0) & (cen[:, 2] <= z1)
        for key, val in (("h", h), ("s", s), ("v", v)):
            if key in r:
                m &= (val >= r[key][0]) & (val <= r[key][1])
        out[m] = r["slot"]
        done |= m
    return out


def move_anchors(arm, T, K):
    """The spec's anchors, through the fit (their own segment weights), in the rest pose; `anchor_bones` {anchor: bone} moves
    one onto another bone (Kael's arm blooms onto the master's cursed left arm)."""
    names = [n for n in SPEC.get("anchors", {}) if n in bpy.data.objects]
    if not names:
        return
    P = np.array([SPEC["anchors"][n] for n in names], float)
    Q = fit(P, fit_weights(arm, P), T, K)
    arm.data.pose_position = "REST"
    bpy.context.view_layer.update()
    for n, q in zip(names, Q):
        e = bpy.data.objects[n]
        rot = e.matrix_world.to_3x3().to_4x4()
        e.parent_bone = SPEC.get("anchor_bones", {}).get(n, e.parent_bone)
        bpy.context.view_layer.update()
        e.matrix_world = Matrix.Translation(Vector(q)) @ rot
    bpy.context.view_layer.update()
    arm.data.pose_position = "POSE"


def main():
    if not os.path.exists(os.path.join(WORK, "bake.blend")):
        bake()
    bpy.ops.wm.open_mainfile(filepath=os.path.join(WORK, "bake.blend"))
    bpy.context.scene.render.fps = FPS
    # a game .glb that is itself a swap's output brings a "Kept" of its own to the bake, so ours saves as "Kept.001"
    low, kept = bpy.data.objects["Low"], next(o for o in bpy.data.objects if o.name.startswith("Kept"))
    img = bpy.data.images["atlas"] if "atlas" in bpy.data.images else bpy.data.images["baked"]
    img.name = "atlas"
    sole = bpy.context.scene["sole"]
    arm, old = import_game(os.path.join(WORK, "game.glb"))
    P = verts(low) * (-1, -1, 1) - (0, 0, sole)
    T, K = targets(arm)
    set_verts(low, fit(P, fit_weights(arm, P), T, K))
    gr = heat_weights(low, arm, P)
    names = list(gr)
    G = np.stack([np.broadcast_to(gr[k], (len(P),)) for k in names], 1)
    W, o = detach(low, G, names)
    P = P[o]
    gr = dict(zip(names, smooth_weights(low, W, int(SPEC.get("smooth", 0))).T))
    top = set_groups(low, gr)
    move_bones(arm, kept, T, K)
    slots = [s + "-atlas" for s in tri_slots(low, img, top, P)] + (kept["slots"].split(",") if kept["slots"] else [])
    room = SPEC.get("room", {})
    vals = [room.get(b, room.get("*", 0.7)) for b in top]
    gname = {g.index: g.name for g in kept.vertex_groups}
    vals += [room.get(gname[max(v.groups, key=lambda e: e.weight).group], room.get("*", 0.7)) for v in kept.data.vertices]
    kept.data.uv_layers.remove(kept.data.uv_layers["old"])
    for o in (low, kept):
        for c in list(o.data.color_attributes):
            o.data.color_attributes.remove(c)
        o.data.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
    old_name = old.name
    bpy.data.objects.remove(old)
    for n in SPEC.get("drop_meshes", []):     # the game glb's own meshes the master replaces (Gil's scripted tail and fin)
        if n in bpy.data.objects and bpy.data.objects[n].type == "MESH":
            bpy.data.objects.remove(bpy.data.objects[n])
    select([low, kept], low)
    bpy.ops.object.join()
    me = low.data
    a = np.ones(len(me.vertices) * 4, F)
    a[3::4] = vals
    me.color_attributes["Col"].data.foreach_set("color", a)
    names = sorted(set(slots))
    emit = bpy.data.images.get("emit")
    for s in names:
        if s in bpy.data.materials:     # (the game glb's own, a kept part's: "flame-jet")
            bpy.data.materials[s].name = s + "-game"
        m = bpy.data.materials.new(s)
        m.use_nodes = True
        b = m.node_tree.nodes["Principled BSDF"]
        t = m.node_tree.nodes.new("ShaderNodeTexImage")
        t.image = img
        m.node_tree.links.new(t.outputs[0], b.inputs[0])
        b.inputs["Roughness"].default_value = 0.8
        if emit:
            e = m.node_tree.nodes.new("ShaderNodeTexImage")
            e.image = emit
            m.node_tree.links.new(e.outputs[0], b.inputs["Emission Color"])
            b.inputs["Emission Strength"].default_value = 1.0
        me.materials.append(m)
    me.polygons.foreach_set("material_index", np.array([names.index(s) for s in slots], np.int32))
    ntri = sum(len(p.vertices) - 2 for p in me.polygons)
    if ntri > SPEC.get("max_tris", 15000):       # the detach caps can push it over the budget: collapse a little, weights interpolated
        d = low.modifiers.new("Decimate", "DECIMATE")
        d.ratio = (SPEC.get("max_tris", 15000) - 100) / ntri
        bpy.context.view_layer.objects.active = low
        bpy.ops.object.modifier_apply(modifier=d.name)
    for p in me.polygons:
        p.use_smooth = True
    low.name = me.name = old_name
    low.parent = arm
    low.modifiers.new("Armature", "ARMATURE").object = arm
    move_anchors(arm, T, K)
    print("SWAP tris", sum(len(p.vertices) - 2 for p in me.polygons), "slots", {s: slots.count(s) for s in names}, flush=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(WORK, "fit.blend"))      # (before the relax: for looking at the weights)
    for k, v in SPEC.get("relax", {}).items():      # e.g. {"CUTS": 0}: relax only, no cut-and-cap holes
        setattr(skin_relax, k, v)
    if bpy.data.actions:
        skin_relax.relax(arm)
    else:       # (Gil: no clips in the glb, the game keys his moves in code; --stretch-check measures them there)
        print("SWAP no clips in the game glb: skin_relax skipped", flush=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(WORK, "swap.blend"))
    # an imported clip ends a hair under its last frame (2.1 s -> 62.999996), and the export dropped that frame
    for act in bpy.data.actions:
        act.use_frame_range = True
        act.frame_start, act.frame_end = round(act.frame_range[0]), round(act.frame_range[1])
    select([o for o in bpy.data.objects if o.type in ("ARMATURE", "MESH", "EMPTY")], arm)
    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True, export_apply=False, export_animations=True,
                              export_animation_mode="ACTIONS", export_skins=True, export_yup=True, export_materials="EXPORT",
                              export_image_format="JPEG", export_jpeg_quality=92, export_extras=False, export_vertex_color="ACTIVE",
                              export_force_sampling=True, export_frame_step=1, export_optimize_animation_size=False, export_def_bones=False)
    print("SWAP exported", OUT, os.path.getsize(OUT), "tris", sum(len(p.vertices) - 2 for p in me.polygons), flush=True)


main()
