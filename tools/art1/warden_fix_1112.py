"""Owner fixes 2026-11-12 on the shipped Hunter .glb files (edits in place, no new scan; docs/art/wardens/V95_SWAP.md exports):
  ostra  (Motley): the fan of cards into his left glove, the orbiting cards down to the fan cards' size.
  thief  (Sable):  the moth wings off the hands (hips at the root, their thigh and shin below, set behind the legs), a narrower idle stance.
  rimewright (Neve, claire.glb): arm weights only on the arms (the skirt, sash and bow off them), the sleeves and gloves
                 turned onto the arm bones, the faces fusing the cuffs to the skirt cut.

    blender -b --factory-startup --python tools/art1/warden_fix_1112.py -- <ostra|sable|claire> IN.glb OUT.glb
  IN is the file before the fix (git show 272368589:art/wardens/<n>/<n>.glb): a second run on a fixed file applies it twice.
"""
import os
import sys
import bpy
import numpy as np
from mathutils import Matrix, Vector
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from posekit import FPS  # noqa: E402  (the clips' rate)

FAN_GRIP = Vector((0.03, 0.0, 0.03))   # m, rest frame: the fan's foot from the glove's centre: on the palm (toward the body) by the knuckles
ORBIT_K = 0.42                                  # the orbiting cards' size over the old (about the fan cards' size)


def load(path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = FPS              # before the import: the clips' keys land on whole frames
    bpy.ops.import_scene.gltf(filepath=path, bone_heuristic="BLENDER")
    for o in list(bpy.data.objects):
        if o.name.startswith("Icosphere"):      # the importer's bone shape, not the model's
            bpy.data.objects.remove(o)
    return next(o for o in bpy.data.objects if o.type == "ARMATURE")


def export(path):
    # an imported clip ends a hair under its last frame (2.1 s -> 62.999996); pin each to its whole frames (v95_swap.py)
    for act in bpy.data.actions:
        act.use_frame_range = True
        act.frame_start, act.frame_end = round(act.frame_range[0]), round(act.frame_range[1])
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=False, export_animations=True,
                              export_animation_mode="ACTIONS", export_skins=True, export_yup=True, export_materials="EXPORT",
                              export_image_format="JPEG", export_jpeg_quality=92, export_extras=False, export_vertex_color="ACTIVE",
                              export_force_sampling=True, export_frame_step=1, export_optimize_animation_size=False, export_def_bones=False)


def group_verts(ob, names, min_w=0.5):
    idx = {ob.vertex_groups[n].index for n in names if n in ob.vertex_groups}
    return [v.index for v in ob.data.vertices if sum(g.weight for g in v.groups if g.group in idx) > min_w]


def ostra(arm):
    body, fan = bpy.data.objects["Body"], bpy.data.objects["Fan"]
    glove = np.array([body.data.vertices[i].co for i in group_verts(body, ["hand.L"])])
    pivot = Vector(np.array([v.co for v in fan.data.vertices]).mean(0)) - Vector((0, 0, 0.095))   # the fan's foot: the cards meet there
    hand_c = Vector(glove[glove[:, 2] < np.percentile(glove[:, 2], 60)].mean(0))   # the hand without its cuff
    # turned over (the cards fan out past the fingertips, as the glove hangs in the rest pose) and its foot in the palm
    turn = Matrix.Rotation(np.pi, 3, "X")
    for v in fan.data.vertices:
        v.co = hand_c + FAN_GRIP + turn @ (v.co - pivot)
    d = hand_c + FAN_GRIP - pivot
    for o in bpy.data.objects:
        if o.name.startswith("orbit_cards_") and o.type == "MESH":
            for v in o.data.vertices:
                v.co *= ORBIT_K
            for ch in o.children:
                ch.location *= ORBIT_K
    print("FIX ostra: fan moved", tuple(round(x, 3) for x in d), "orbit cards x", ORBIT_K)


WING_TOP, WING_SPAN = 0.8, 0.2    # m: a wing rides the hips above WING_TOP and its thigh from WING_TOP - WING_SPAN down
WING_BACK = 0.025                 # m the wing moves back off the leg (none at its root)
WING_KNEE, WING_SHIN = 0.49, 0.75 # m, share: below the knee the tip takes up to this much of the shin (it bends back with the knee)
STANCE = {"idle": (0.004, 0.08), "stance": (0.008, 0.085)}   # clip -> (knee out past the hip joint, ankle from the middle), m


def sable_wings(body):
    """The moth wings (fur below the waist, between the coat's sides): off the hands and legs, onto the hips and their thigh."""
    me = body.data
    fur = {i for p in me.polygons if me.materials[p.material_index].name.startswith("fur") for i in p.vertices}
    P = np.array([v.co for v in me.vertices])
    is_fur = np.array([i in fur for i in range(len(P))])
    low = is_fur & (P[:, 2] < 1.0) & (P[:, 1] < 0.0)                # fur below the waist, at the back
    wing = grow(me, low & (np.abs(P[:, 0]) < 0.17), low)            # the panels between the coat's sides, all of each
    n = 0
    for v in me.vertices:
        if not wing[v.index]:
            continue
        for g in list(v.groups):
            body.vertex_groups[g.group].remove([v.index])
        t = min(max((WING_TOP - v.co.z) / WING_SPAN, 0.0), 1.0)
        k = min(max((WING_KNEE - v.co.z + 0.05) / 0.4, 0.0), 1.0) * WING_SHIN
        r = min(max((v.co.x + 0.03) / 0.06, 0.0), 1.0)   # the right leg's share (the two wings meet in the middle)
        v.co.y -= WING_BACK * t                    # a little more room behind the leg
        for g, w in (("hips", 1.0 - t), ("thigh.R", t * (1.0 - k) * r), ("shin.R", t * k * r),
                     ("thigh.L", t * (1.0 - k) * (1.0 - r)), ("shin.L", t * k * (1.0 - r))):
            if w > 0:
                body.vertex_groups[g].add([v.index], w, "REPLACE")
        n += 1
    return n


def lateral_turn(pb_mat, pivot, frm, to):
    """pb_mat turned about the front axis (Y) through pivot so the point frm swings to x = to (its height kept on the circle)."""
    a0 = np.arctan2(frm.x - pivot.x, pivot.z - frm.z)
    a1 = np.arctan2(to - pivot.x, np.sqrt(max((frm - pivot).length ** 2 - (to - pivot.x) ** 2, 1e-6)))
    R = Matrix.Translation(pivot) @ Matrix.Rotation(a0 - a1, 4, "Y") @ Matrix.Translation(-pivot)
    return R @ pb_mat


def sable_stance(arm):
    """Idle and stance with the knees under the hips (they bowed out): thigh then shin turned about the front axis each
    frame, the foot kept as it was in the world."""
    sc = bpy.context.scene
    for act, (knee_out, ankle_x) in STANCE.items():
        A = bpy.data.actions[act]
        arm.animation_data.action = A
        f0, f1 = (round(x) for x in A.frame_range)
        for f in range(f0, f1 + 1):
            sc.frame_set(f)
            for s, sg in (("L", -1), ("R", 1)):
                th, sh, ft = (arm.pose.bones[b + "." + s] for b in ("thigh", "shin", "foot"))
                foot0 = ft.matrix.copy()
                H, K = th.head.copy(), sh.head.copy()
                th.matrix = lateral_turn(th.matrix, H, K, H.x + sg * knee_out)
                bpy.context.view_layer.update()
                K, Ak = sh.head.copy(), ft.head.copy()
                sh.matrix = lateral_turn(sh.matrix, K, Ak, sg * ankle_x)
                bpy.context.view_layer.update()
                ft.matrix = Matrix.Translation(ft.head) @ foot0.to_3x3().to_4x4()
                bpy.context.view_layer.update()
                for pb in (th, sh, ft):
                    pb.keyframe_insert("rotation_quaternion", frame=f)
                    if pb == ft:
                        pb.keyframe_insert("location", frame=f)
        print("FIX sable stance", act, f0, f1)


def sable(arm):
    arm.animation_data_create()
    print("FIX sable wings: verts", sable_wings(bpy.data.objects["Body"]))
    sable_stance(arm)


# Neve's arms in the rest pose, the right side (the left mirrors it), m: where the mesh's sleeve and glove are; the
# bones hung straight down 6-10 cm inside them, so the elbow and wrist bent about the wrong points
ARM_GUESS = {"shoulder": (0.150, -0.035, 1.30), "elbow": (0.215, -0.035, 1.09), "wrist": (0.255, -0.01, 0.88), "tip": (0.30, 0.0, 0.72)}
SLEEVE_R, GLOVE_R = 0.065, 0.1     # m from the arm's line: the sleeve (fur) and the glove taken as arm
BLEND = 0.03                       # m: upper arm and forearm blend over this either side of the elbow


GROW_R = 0.11                      # m: the arm grows over the mesh to its fur, glove and arm-weighted neighbours this near its line


def grow(me, seed, allowed):
    """seed spread over the mesh's edges (welded across UV seams) to the allowed vertices it touches."""
    key = {}
    for v in me.vertices:
        key.setdefault(tuple(np.round(np.array(v.co) / 0.0005).astype(int)), []).append(v.index)
    nb = [[] for _ in me.vertices]
    for e in me.edges:
        a, b = e.vertices
        nb[a].append(b)
        nb[b].append(a)
    for ids in key.values():
        for i in ids:
            nb[i] += ids
    out = seed.copy()
    todo = list(np.nonzero(seed)[0])
    while todo:
        i = todo.pop()
        for j in nb[i]:
            if not out[j] and allowed[j]:
                out[j] = True
                todo.append(j)
    return out


def seg_t(p, a, b):
    ab = b - a
    t = np.clip(((p - a) @ ab) / (ab @ ab), 0.0, 1.0)
    return t, np.linalg.norm(p - (a + t[:, None] * ab), axis=1)


def vertex_colours(me):
    """The atlas colour under each vertex (the body has one embedded atlas)."""
    img = next(i for i in bpy.data.images if i.size[0] > 0)
    w, h = img.size
    px = np.array(img.pixels[:]).reshape(h, w, 4)
    uv = me.uv_layers.active.data
    col = np.zeros((len(me.vertices), 3))
    for p in me.polygons:
        for li, vi in zip(p.loop_indices, p.vertices):
            u, v = uv[li].uv
            col[vi] = px[int(min(max(v, 0.0), 0.9999) * h), int(min(max(u, 0.0), 0.9999) * w), :3]
    return col


def body_part(me):
    """Vertex ids of the biggest welded piece (the body, not the spear's separate pieces)."""
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.verts.ensure_lookup_table()
    key = {}
    for v in bm.verts:
        key.setdefault(tuple(np.round(np.array(v.co) / 0.0005).astype(int)), []).append(v.index)
    parent = list(range(len(bm.verts)))

    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i
    for ids in key.values():
        for i in ids[1:]:
            parent[find(i)] = find(ids[0])
    for e in bm.edges:
        parent[find(e.verts[0].index)] = find(e.verts[1].index)
    roots = [find(i) for i in range(len(bm.verts))]
    big = max(set(roots), key=roots.count)
    return {i for i, r in enumerate(roots) if r == big}


def claire_joints(P, mat, sg):
    """The arm's joints on the mesh: each guess moved to the middle of the sleeve's fur round it."""
    J = {k: np.array(v) * [sg, 1, 1] for k, v in ARM_GUESS.items()}
    fur = np.array([m == "fur" for m in mat])
    for k in ("shoulder", "elbow", "wrist"):
        m = fur & (np.abs(P[:, 2] - J[k][2]) < 0.03) & (np.linalg.norm(P[:, :2] - J[k][:2], axis=1) < 0.06)
        if m.sum() > 5:
            J[k][:2] = P[m, :2].mean(0)
    return J


def claire_arms(arm):
    body = bpy.data.objects["Body"]
    me = body.data
    P = np.array([v.co for v in me.vertices])
    mat = [""] * len(P)
    for p in me.polygons:
        for i in p.vertices:
            mat[i] = me.materials[p.material_index].name.split("-")[0]
    col = vertex_colours(me)
    purple = (col[:, 2] > col[:, 0] + 0.02) & (col[:, 0] > col[:, 1] + 0.02)        # the gloves' paint
    red = col[:, 0] > col[:, 1] + 0.3                                                 # the sash and its bow
    own = np.zeros(len(P), bool)
    own[list(body_part(me))] = True
    groups = {g.name: g for g in body.vertex_groups}
    joints = {}
    arm_of = np.full(len(P), "", object)
    cut_z = {}
    for s, sg in (("R", 1), ("L", -1)):
        J = claire_joints(P, mat, sg)
        joints[s] = J
        bones = ["upper_arm." + s, "forearm." + s, "hand." + s] + (["fingers.L", "thumb.L"] if s == "L" else [])
        t1, d1 = seg_t(P, J["shoulder"], J["elbow"])
        t2, d2 = seg_t(P, J["elbow"], J["wrist"])
        d3 = seg_t(P, J["wrist"], J["tip"])[1]
        sleeve = own & np.array([m == "fur" for m in mat]) & (np.minimum(d1, d2) < SLEEVE_R) & (P[:, 0] * sg > abs(J["shoulder"][0]) - 0.03)
        arm_w = np.array([sum(g.weight for g in v.groups if body.vertex_groups[g.group].name in bones) for v in me.vertices])
        low = (P[:, 2] < J["wrist"][2] + 0.03) & (P[:, 2] > J["tip"][2] - 0.06)
        # the glove: its paint, or all-arm weights (the skirt beside it was only part arm), and the claws past it
        glove = own & ~red & low & ((((purple & (arm_w > 0.3)) | (arm_w > 0.9)) & (d3 < GLOVE_R))
                                    | (purple & (arm_w > 0.5) & (P[:, 0] * sg > J["wrist"][0] * sg)))
        is_arm = grow(me, sleeve | glove, own & ~red & (np.minimum(np.minimum(d1, d2), d3) < GROW_R)
                      & (np.array([m == "fur" for m in mat]) | purple | (arm_w > 0.5)) & (P[:, 0] * sg > abs(J["shoulder"][0]) - 0.03))
        l1 = np.linalg.norm(J["elbow"] - J["shoulder"])
        l2 = np.linalg.norm(J["wrist"] - J["elbow"])
        for i in map(int, np.nonzero(own)[0]):
            v = me.vertices[i]
            old = {body.vertex_groups[g.group].name: g.weight for g in v.groups}
            if not is_arm[i]:
                if not any(b in old for b in bones):
                    continue
                keep = {b: w for b, w in old.items() if b not in bones}
                tot = sum(keep.values())
                new = {b: w / tot for b, w in keep.items()} if tot > 0.05 else {"hips": 1.0}
            else:
                # along the arm: shoulder -> upper arm -> elbow -> forearm; the glove rides the forearm (the clips' wrist turns
                # were keyed for the old fist round the spear and fold this open glove flat)
                a_up = np.clip((t1[i] * l1 + 0.02) / 0.06, 0.0, 1.0)              # off the hips at the shoulder
                e = (t2[i] * l2 if d2[i] <= d1[i] else (t1[i] - 1.0) * l1)        # m past the elbow (negative above it)
                w_fore = np.clip((e + BLEND) / (2 * BLEND), 0.0, 1.0)
                new = {"hips": 1.0 - a_up, "upper_arm." + s: a_up * (1 - w_fore), "forearm." + s: a_up * w_fore}
            for b in old:
                groups[b].remove([i])
            for b, w in new.items():
                if w > 0.001:
                    groups[b].add([i], float(w), "REPLACE")
        arm_of[is_arm] = s
        cut_z[s] = J["shoulder"][2] - 0.06
        print("FIX claire", s, "arm verts", int(is_arm.sum()), "(sleeve", int(sleeve.sum()), "glove", int(glove.sum()), ")",
              {k: tuple(np.round(v, 3)) for k, v in J.items()})
    cut_bridges(me, arm_of, P, cut_z)
    return joints, arm_of


def cut_bridges(me, arm_of, P, cut_z):
    """The scan fused the cuffs and gloves to the skirt and the sash where they touched: the faces joining an arm to
    the body below the armpit go (they stretched into spikes as soon as the arm moved)."""
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.faces.ensure_lookup_table()
    cut = []
    for f in bm.faces:
        sides = {arm_of[v.index] for v in f.verts}
        arm_side = next((x for x in sides if x), "")
        if arm_side and len(sides) > 1 and max(P[v.index][2] for v in f.verts) < cut_z[arm_side]:
            cut.append(f)
    bmesh.ops.delete(bm, geom=cut, context="FACES")
    bm.to_mesh(me)
    bm.free()
    print("FIX claire bridge faces cut", len(cut))


def claire_refit(arm, joints, arm_of):
    """The sleeves and gloves turned onto the arm bones (the rig contract keeps the bones on the game's rig nodes, so
    the mesh moves, not the bones): the upper arm about its shoulder onto upper_arm, the forearm and glove about the
    elbow onto forearm, each vertex by its own weights, so the joints bend where the clips bend them."""
    body = bpy.data.objects["Body"]
    B = arm.data.bones
    for s, J in joints.items():
        S, E, W = (Vector(J[k]) for k in ("shoulder", "elbow", "wrist"))
        Sb, Eb, Wb = (Vector(B[b + "." + s].head_local) for b in ("upper_arm", "forearm", "hand"))
        q_up = (E - S).rotation_difference(Eb - Sb).to_matrix()
        q_fo = (W - E).rotation_difference(Wb - Eb).to_matrix()
        e_new = Sb + q_up @ (E - S)
        g = {n: body.vertex_groups[n + "." + s].index for n in ("upper_arm", "forearm")}
        n = 0
        for i in np.nonzero(arm_of == s)[0]:
            v = body.data.vertices[int(i)]
            w = {x.group: x.weight for x in v.groups}
            wu, wf = w.get(g["upper_arm"], 0.0), w.get(g["forearm"], 0.0)
            p = v.co.copy()
            v.co = p * (1.0 - wu - wf) + (Sb + q_up @ (p - S)) * wu + (e_new + q_fo @ (p - E)) * wf
            n += 1
        print("FIX claire", s, "arm refit", n, "verts; elbow lands", round((e_new - Eb).length, 3), "m from the bone's")


def claire(arm):
    joints, arm_of = claire_arms(arm)
    claire_refit(arm, joints, arm_of)


if __name__ == "__main__":
    who, src, out = sys.argv[sys.argv.index("--") + 1:][:3]
    arm = load(src)
    {"ostra": ostra, "sable": sable, "claire": claire}[who](arm)
    export(out)
    print("FIX exported", out)
