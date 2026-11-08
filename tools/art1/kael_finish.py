"""ART-1 Kael v2, stage B: join, unwrap, bake the scan's paint, the curse veins' emission, the alpha cards, skin, export.
One 2048 colour atlas (the scan's paint; the scripted pieces on flat cells at its right edge), a 2048 emission map (the
curse veins on his right arm and chest: model_glow core tints it), a small RGBA card atlas (the shawl's torn hem and the
sash tails). The armature is the contract's (kael_rig.json) plus the mane's spring chains the game already knows. The sword (kael_pieces.sword) is joined to the body, skinned to hand.R: the clips carry it (docs/art/wardens/CLIPS.md).
Run: blender -b --factory-startup --python tools/art1/kael_finish.py -- <source.blend> <rig.json> <out.glb>"""
import sys, os, json, math
import bpy, bmesh
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "blender"))
import kael_pieces as K
from meshkit import smooth
from paintkit import hexc
import warden_kit as WK

a = sys.argv[sys.argv.index("--") + 1:]
SRC, RIG, OUT = a[0], a[1], a[2]
WORK = os.path.dirname(os.path.abspath(OUT))
ATLAS = 2048
CARDS = 512
UNIQ_W = 0.94                        # the scan's islands' share of the atlas width; the flat cells sit to its right
CELL = {"metal-sword": "#c9c1c9", "metal-sword_edge": "#ebe6ec", "metal-sword_dk": "#857e88",
        "leather-grip": "#7e1b25", "glow-sword": "#ffffff"}
# card cells (u0, v0, u1, v1) in the card atlas: the sash tail, the shawl's crimson hem, its bone hem
SASH_C, HEM_RED_C, HEM_BONE_C = (0.0, 0.0, 0.34, 1.0), (0.35, 0.0, 0.66, 1.0), (0.67, 0.0, 1.0, 1.0)
SLOTS = ["skin", "hair", "cloth", "leather", "metal"]
MATS = [s + "-kael" for s in SLOTS] + ["card-kael"]
CURSE_BONES = ("upper_arm.R", "forearm.R", "hand.R")   # the sword arm (the scan draws the curse on the left)
ARM_OFF = 0.06                       # m from the upper arm's bone: further out is the shawl
TORSO_R = (0.2, 0.135)               # m, the torso's skin ellipse (x, y) round the spine: outside it is the shawl
SASH_OUT = 0.018                     # m, the sash tails off the trousers' front
HEM_DROP = 0.045                     # m, the torn hem's tongues past the shawl's edge
BELT_UP = 0.12                       # m above the hips bone: the belt's top
rig = json.load(open(RIG))

bpy.ops.wm.open_mainfile(filepath=SRC)
sc = bpy.context.scene
src, low = bpy.data.objects["Src"], bpy.data.objects["Low"]


# ---- one mesh: the scan's low mesh
verts, faces, fsrc, vw, rooms = [], [], [], [], []
gn = {g.index: g.name for g in low.vertex_groups}
for v in low.data.vertices:
    verts.append(tuple(v.co))
    vw.append({gn[g.group]: g.weight for g in v.groups if g.weight > 0.01})
    rooms.append(1.0)
for p in low.data.polygons:
    faces.append(list(p.vertices))
    fsrc.append(None)
N_LOW = len(low.data.polygons)
me = bpy.data.meshes.new("Body")
me.from_pydata(verts, [], faces)
me.update()
ob = bpy.data.objects.new("Body", me)
sc.collection.objects.link(ob)
for m in MATS:
    mt = bpy.data.materials.new(m)
    mt.use_nodes = True
    me.materials.append(mt)
uv = me.uv_layers.new(name="UV")

# ---- unwrap the scan part, then squeeze it left of the flat cells
for o in bpy.data.objects:
    o.select_set(False)
bpy.context.view_layer.objects.active = ob
ob.select_set(True)
bpy.ops.object.mode_set(mode="EDIT")
bm = bmesh.from_edit_mesh(me)
bm.faces.ensure_lookup_table()
for f in bm.faces:
    f.select = f.index < N_LOW
bmesh.update_edit_mesh(me)
bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.0, area_weight=0.0, scale_to_bounds=False)
bpy.ops.uv.pack_islands(rotate=True, scale=True, margin_method="FRACTION", margin=0.003, shape_method="CONCAVE")
bpy.ops.object.mode_set(mode="OBJECT")
cells = {}
for i, nm in enumerate(CELL):
    y0 = i / len(CELL)
    cells[nm] = ((UNIQ_W + 1.0) / 2, y0 + 0.5 / len(CELL))
uv = me.uv_layers["UV"]          # (the edit-mode round trip left the old reference dangling)
luv = np.zeros(len(me.loops) * 2)
uv.data.foreach_get("uv", luv)
luv = luv.reshape(-1, 2)
for p in me.polygons:
    ls = list(p.loop_indices)
    if p.index < N_LOW:
        luv[ls, 0] *= UNIQ_W
    else:
        luv[ls] = cells[fsrc[p.index]]
uv.data.foreach_set("uv", luv.ravel())
me.update()

# ---- bake the scan's paint (selected to active, emission of its base colour)
for mt in src.data.materials:
    nt = mt.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    tex = bsdf.inputs["Base Color"].links[0].from_socket
    em = nt.nodes.new("ShaderNodeEmission")
    nt.links.new(tex, em.inputs["Color"])
    nt.links.new(em.outputs[0], next(n for n in nt.nodes if n.type == "OUTPUT_MATERIAL").inputs["Surface"])
atlas = bpy.data.images.new("atlas", ATLAS, ATLAS)
for mt in me.materials:
    t = mt.node_tree.nodes.new("ShaderNodeTexImage")
    t.image = atlas
    mt.node_tree.nodes.active = t
sc.render.engine = "CYCLES"
sc.cycles.device = "CPU"
sc.cycles.samples = 1
sc.render.bake.use_selected_to_active = True
sc.render.bake.cage_extrusion = 0.03
sc.render.bake.max_ray_distance = 0.08
for o in bpy.data.objects:
    o.select_set(False)
src.select_set(True)
ob.select_set(True)
bpy.context.view_layer.objects.active = ob
bpy.ops.object.bake(type="EMIT", use_clear=True, margin=8)
COL = np.array(atlas.pixels[:], np.float32).reshape(ATLAS, ATLAS, 4)[..., :3].copy()
src.scale.x = -1                     # the scan mirrored: its cursed left arm and chest land on his right (sword) side
bpy.context.view_layer.update()
bpy.ops.object.bake(type="EMIT", use_clear=True, margin=8)
COL_MIR = np.array(atlas.pixels[:], np.float32).reshape(ATLAS, ATLAS, 4)[..., :3].copy()
print("baked")

# ---- per face: its paint, its slot
fuv = np.zeros((len(me.polygons), 2))
for p in me.polygons:
    fuv[p.index] = luv[list(p.loop_indices)].mean(0)
fc = np.array([np.mean([verts[i] for i in f], axis=0) for f in faces])
fw = [{} for _ in faces]
for i, f in enumerate(faces):
    for vi in f:
        for b, w in vw[vi].items():
            fw[i][b] = fw[i].get(b, 0.0) + w / len(f)
neck_z = WK.bone_head(rig, "head").z
sh_z = WK.bone_head(rig, "upper_arm.R").z
belt_z = WK.bone_head(rig, "hips").z + BELT_UP
arm_x = WK.bone_head(rig, "upper_arm.R").x
dom = [max(w, key=w.get) if w else "root" for w in fw]
# off the body: the shawl and the scarf stand out from the skin under them (an arm's skin within ARM_OFF of its bone,
# the torso's inside an ellipse of TORSO_R), or lie on his shoulders; the head's own faces are face, scarf or hair
off = np.zeros(len(faces), bool)
for i, b in enumerate(dom):
    x, y, z = fc[i]
    if b.startswith("upper_arm"):
        off[i] = math.hypot(x - math.copysign(arm_x, x), y) > ARM_OFF
    elif b in ("hips", "root"):
        off[i] = z > belt_z and (z > sh_z - 0.03 or math.hypot(x / TORSO_R[0], y / TORSO_R[1]) > 1.0)
# ---- the curse side is mirrored in from the scan: arm, hand and chest skin take the mirrored bake (the shawl keeps its own)
# ---- texel maps: which face, where
ftex = -np.ones((ATLAS, ATLAS), np.int32)
for p in me.polygons:
    if p.index >= N_LOW:
        continue
    q = luv[list(p.loop_indices)] * ATLAS
    x0, y0 = np.floor(q.min(0)).astype(int)
    x1, y1 = np.ceil(q.max(0)).astype(int)
    if x1 - x0 > 200 or y1 - y0 > 200:
        continue
    xs, ys = np.meshgrid(np.arange(x0, x1 + 1), np.arange(y0, y1 + 1))
    pts = np.stack([xs.ravel() + 0.5, ys.ravel() + 0.5], 1)
    for k in range(1, len(q) - 1):
        a_, b_, c_ = q[0], q[k], q[k + 1]
        d = (b_[1] - c_[1]) * (a_[0] - c_[0]) + (c_[0] - b_[0]) * (a_[1] - c_[1])
        if abs(d) < 1e-9:
            continue
        l1 = ((b_[1] - c_[1]) * (pts[:, 0] - c_[0]) + (c_[0] - b_[0]) * (pts[:, 1] - c_[1])) / d
        l2 = ((c_[1] - a_[1]) * (pts[:, 0] - c_[0]) + (a_[0] - c_[0]) * (pts[:, 1] - c_[1])) / d
        ins = (l1 >= -0.02) & (l2 >= -0.02) & (l1 + l2 <= 1.04)
        xi, yi = pts[ins, 0].astype(int), pts[ins, 1].astype(int)
        ok = (xi >= 0) & (xi < ATLAS) & (yi >= 0) & (yi < ATLAS)
        ftex[yi[ok], xi[ok]] = p.index

okf = ftex >= 0
arm_f = np.array([d.startswith(("upper_arm", "forearm", "hand")) for d in dom]) & ~off
chest_all = np.array([d in ("hips", "root") for d in dom]) & ~off & (fc[:, 2] > belt_z + 0.04)
mir = np.zeros((ATLAS, ATLAS), bool)
mir[okf] = (arm_f | chest_all)[ftex[okf]]
COL[mir] = COL_MIR[mir]
px = np.clip((fuv * ATLAS).astype(int), 0, ATLAS - 1)
fcol = COL[px[:, 1], px[:, 0]]
mx, mn = fcol.max(1), fcol.min(1)
sat = (mx - mn) / np.maximum(mx, 1e-4)
curse_f = np.array([sum(w.get(b, 0) for b in CURSE_BONES) > 0.5 for w in fw]) & ~off
chest_f = np.array([b in ("hips", "root") for b in dom]) & ~off & (fc[:, 2] > belt_z + 0.04)
red = (fcol[:, 0] > 0.25) & (fcol[:, 0] - np.maximum(fcol[:, 1], fcol[:, 2]) > 0.15) & (sat > 0.5)
hair = (sat < 0.1) & (mx > 0.75) & ((fc[:, 2] > neck_z - 0.02) | (fc[:, 1] < -0.06))
dark = mx < 0.33
grey = (sat < 0.14) & (mx >= 0.33) & ~hair
slot = np.full(len(faces), "skin", dtype=object)
slot[red & ~curse_f & ~chest_f] = "cloth"
slot[off & ~hair] = "cloth"
slot[dark] = "leather"
slot[grey & ~off] = "metal"
slot[hair] = "hair"
head_f = np.array([b == "head" for b in dom])
slot[head_f & ~hair & ~red & ~dark] = "skin"
for i, p in enumerate(me.polygons):
    p.material_index = MATS.index(fsrc[i]) if i >= N_LOW else MATS.index(slot[i] + "-kael")
print("slots", {s: int((slot[:N_LOW] == s).sum()) for s in SLOTS})

# ---- the curse: his right (sword) arm, hand and the chest's veins glow (emission); the hand is bare crimson skin
zone = np.zeros((ATLAS, ATLAS), bool)
zone[okf] = (curse_f | (chest_f & (fc[:, 1] > 0)))[ftex[okf]] & (slot[ftex[okf]] != "leather")
hand_c = np.array([w.get("hand.R", 0) > 0.5 for w in fw]) & (slot != "metal")
r, g, b = COL[..., 0], COL[..., 1], COL[..., 2]
vein = smooth(0.18, 0.4, r - np.maximum(g, b)) * smooth(0.35, 0.6, r)
EMIT = np.where(zone, vein, 0.0)
hand_t = np.zeros((ATLAS, ATLAS), bool)
hand_t[okf] = hand_c[ftex[okf]]
lum = COL.mean(-1)
crimson = np.array([0.42, 0.05, 0.08]) * (0.55 + 0.9 * lum[..., None])
COL[hand_t] = np.maximum(COL[hand_t] * [1.0, 0.3, 0.32], crimson[hand_t])
EMIT[hand_t] = np.maximum(EMIT[hand_t], smooth(0.3, 0.55, r[hand_t] - np.maximum(g[hand_t], b[hand_t])))
print("veins", int((EMIT > 0.3).sum()), "texels")
for nm, (u, v_) in cells.items():
    x0, y0 = int((UNIQ_W + 0.004) * ATLAS), int((v_ - 0.5 / len(CELL)) * ATLAS) + 2
    COL[y0:y0 + ATLAS // len(CELL) - 4, x0:] = hexc(CELL[nm])


def save(img_name, arr, path, fmt="JPEG"):
    im = bpy.data.images.new(img_name, arr.shape[1], arr.shape[0], alpha=arr.shape[2] == 4)
    pxl = np.ones((arr.shape[0], arr.shape[1], 4), np.float32)
    pxl[..., :arr.shape[2]] = np.clip(arr, 0, 1)
    im.pixels.foreach_set(pxl.ravel())
    im.filepath_raw = path
    im.file_format = fmt
    im.save()
    return im


atlas_i = save("atlas", COL, os.path.join(WORK, "atlas.jpg"))
emit_i = save("emit", np.repeat(EMIT[..., None], 3, -1), os.path.join(WORK, "emit.jpg"))


# ---- the alpha cards: the shawl's torn hem (one card per rim edge, hanging), the sash tails
def card_atlas():
    rng = np.random.default_rng(3)
    img = np.zeros((CARDS // 2, CARDS, 4), np.float32)
    ys, xs = np.mgrid[0:CARDS // 2, 0:CARDS] / np.array([CARDS // 2, CARDS])[:, None, None]
    for (u0, v0, u1, v1), col, ragged in ((SASH_C, "#9e1624", "sides"), (HEM_RED_C, "#8e1420", "hem"), (HEM_BONE_C, "#d6ccbd", "hem")):
        cx = (xs - u0) / (u1 - u0)
        inside = (cx >= 0) & (cx <= 1)
        down = 1.0 - ys                   # (v 1 is the edge the card hangs from)
        shade = 0.82 + 0.18 * np.sin(cx * 9.0 + ys * 3.0)
        if ragged == "hem":
            # torn tongues of cloth, each its own length, tapering to a point
            k = 9
            t = (cx * k) % 1.0
            lens = rng.uniform(0.35, 1.0, k + 1)[np.clip((cx * k).astype(int), 0, k)]
            keep = down < lens * (1.0 - np.abs(t - 0.5) * 2.0) ** 0.6
        else:
            edge = np.interp(down, np.linspace(0, 1, 12), rng.uniform(0.0, 0.18, 12))
            keep = (cx > edge) & (cx < 1 - edge * 0.7) & (down < 0.88 + 0.12 * np.abs(np.sin(cx * 7)))
        m = inside & keep
        img[m, :3] = hexc(col) * shade[m, None] * (1.0 - 0.25 * ys[m, None])
        img[m, 3] = 1.0
    return img


def hem_cards():
    """Under each rim edge of the shawl (a cloth face over a skin or leather face) a hanging card, a little out."""
    out = []
    bvh = BVHTree.FromPolygons(verts, faces[:N_LOW])
    bmh = bmesh.new()
    bmh.from_mesh(me)
    bmh.faces.ensure_lookup_table()
    for e in bmh.edges:
        lf = e.link_faces
        if len(lf) != 2 or max(f.index for f in lf) >= N_LOW:
            continue
        s0, s1 = slot[lf[0].index], slot[lf[1].index]
        if (s0 == "cloth") == (s1 == "cloth") or "hair" in (s0, s1):
            continue
        cf, of_ = (lf[0], lf[1]) if s0 == "cloth" else (lf[1], lf[0])
        if cf.calc_center_median().z < of_.calc_center_median().z or cf.calc_center_median().z < belt_z:
            continue
        p0, p1 = np.array(e.verts[0].co), np.array(e.verts[1].co)
        if abs(p0[2] - p1[2]) > np.linalg.norm(p0[:2] - p1[:2]):
            continue                 # a steep edge is the shawl's side, not its hem
        nrm = np.array(cf.normal)
        if nrm[2] > 0.7:
            continue                 # a face looking up: the shawl's top, not a hanging edge
        nrm[2] = 0
        nrm = nrm / max(np.linalg.norm(nrm), 1e-6)
        below = bvh.ray_cast(Vector((p0 + p1) / 2 + nrm * 0.008 + (0, 0, -0.004)), Vector((0, 0, -1)), 0.12)
        if below[2] is not None and slot[below[2]] == "cloth":
            continue                 # more shawl under it: a colour edge inside the shawl, not its hem
        fn = np.array(cf.normal)
        along = np.array([0, 0, -1.0]) - fn * -fn[2]          # down the shawl's own surface, so the tear continues it
        drop = along / max(np.linalg.norm(along), 1e-6) * HEM_DROP + nrm * 0.004
        top = [p0 + nrm * 0.005 - drop * 0.25, p1 + nrm * 0.005 - drop * 0.25]      # (tucked a little under the edge)
        bone_ = fcol[cf.index].mean() > 0.45
        c = HEM_BONE_C if bone_ else HEM_RED_C
        u = (math.atan2(p0[0], p0[1]) / math.pi * 0.5 + 0.5) * 3 % 1
        u2 = min(1.0, u + np.linalg.norm(p1 - p0) * 6)
        uu = (c[0] + (c[2] - c[0]) * u, c[0] + (c[2] - c[0]) * u2)
        out.append(([top[0], top[1], top[1] + drop, top[0] + drop], [(uu[0], 1.0), (uu[1], 1.0), (uu[1], 0.0), (uu[0], 0.0)],
                    [vw[e.verts[0].index], vw[e.verts[1].index], vw[e.verts[1].index], vw[e.verts[0].index]]))
    bmh.free()
    return out


def sash_cards():
    """Two crimson tails from the knot at his right hip, down the front of his thigh, SASH_OUT off the trousers."""
    hip = WK.bone_head(rig, "thigh.R")
    bvh = BVHTree.FromPolygons(verts, faces[:N_LOW])
    out = []
    for k, (dx, ln, w) in enumerate(((0.0, 0.52, 0.03), (0.04, 0.44, 0.024))):
        n = 6
        path = []
        for j in range(n):
            x, z = hip.x + 0.03 + dx + 0.012 * j / n, belt_z - 0.02 - ln * j / (n - 1)
            hit = bvh.ray_cast(Vector((x, 0.6, z)), Vector((0, -1, 0)), 1.0)
            y = (hit[0].y if hit[0] is not None else 0.12) + SASH_OUT + 0.006 * k
            path.append((x, y, z))
        wt = np.clip(np.arange(n) / (n - 1), 0, 1)
        pc = K.card("sash%d" % k, path, np.full(n, w), (1.0, 0.25, 0.0), (SASH_C[0], 1.0, SASH_C[2], 0.0),
                    {"hips": 1.0 - wt * 0.6, "thigh.R": wt * 0.6})
        for f, uvq in zip(pc.f, pc.uv):
            out.append(([pc.v[i] for i in f], uvq, [{b: float(w_[i]) for b, w_ in pc.w.items()} for i in f]))
    return out


cards = hem_cards() + sash_cards()
bm = bmesh.new()
bm.from_mesh(me)
uvl = bm.loops.layers.uv["UV"]
dl = bm.verts.layers.deform.verify()
gidx = {}
for i, d in enumerate(vw):
    for b in d:
        gidx.setdefault(b, len(gidx))
card_mi = MATS.index("card-kael")
for quad, uvq, ws in cards:
    for d in ws:
        for b in d:
            gidx.setdefault(b, len(gidx))
    vs = [bm.verts.new(Vector(p)) for p in quad]
    for v_, d in zip(vs, ws):
        vw.append(d)
        rooms.append(0.0)
    f = bm.faces.new(vs)
    f.material_index = card_mi
    for l_, q in zip(f.loops, uvq):
        l_[uvl].uv = q
bm.to_mesh(me)
bm.free()
print("cards", len(cards))
cards_i = save("cards", card_atlas(), os.path.join(WORK, "cards.png"), "PNG")

# ---- materials
for mt in me.materials:
    nt = mt.node_tree
    for nd in list(nt.nodes):
        if nd.type == "TEX_IMAGE":
            nt.nodes.remove(nd)
    pb = nt.nodes["Principled BSDF"]
    t = nt.nodes.new("ShaderNodeTexImage")
    t.image = cards_i if mt.name == "card-kael" else atlas_i
    nt.links.new(t.outputs[0], pb.inputs["Base Color"])
    pb.inputs["Roughness"].default_value = 0.7
    if mt.name == "card-kael":
        nt.links.new(t.outputs["Alpha"], pb.inputs["Alpha"])
    if mt.name == "skin-kael":
        e = nt.nodes.new("ShaderNodeTexImage")
        e.image = emit_i
        nt.links.new(e.outputs[0], pb.inputs["Emission Color"])
        pb.inputs["Emission Strength"].default_value = 1.0
attr = me.color_attributes.new("ink", "FLOAT_COLOR", "POINT")
ic = np.ones((len(me.vertices), 4), np.float32)
ic[:, 3] = rooms
attr.data.foreach_set("color", ic.ravel())
me.color_attributes.active_color = attr

# ---- armature: the contract's, the springs the game knows
arm = WK.build_armature(rig)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="EDIT")
eb = arm.data.edit_bones


def spring(prefix, pts, parent):
    prev = parent
    for i in range(len(pts) - 1):
        e = eb.new("%s_%d" % (prefix, i))
        e.head, e.tail = Vector(pts[i]), Vector(pts[i + 1])
        e.parent = eb[prev]
        prev = e.name


top = WK.bone_head(rig, "head").z + 0.1
for nm, x, y in (("back", 0.0, -0.12), ("l", -0.1, -0.04), ("r", 0.1, -0.04), ("fl", -0.07, 0.04), ("fr", 0.08, 0.05)):
    ln = 0.11 if nm in ("back", "l", "r") else 0.03
    spring("spring_mane_" + nm, [(x, y, top - ln * i) for i in range(6)], "head")
bpy.ops.object.mode_set(mode="OBJECT")
ob.parent = arm
md = ob.modifiers.new("arm", "ARMATURE")
md.object = arm
for vi, d in enumerate(vw):
    tot = sum(d.values())
    for b, w in d.items():
        g = ob.vertex_groups.get(b) or ob.vertex_groups.new(name=b)
        g.add([vi], w / tot if tot > 0 else 0, "REPLACE")

# ---- FX points: the arm anchors sit on the cursed (right, sword) arm, its glow blooms there
up, el, hd = WK.bone_head(rig, "upper_arm.R"), WK.bone_head(rig, "forearm.R"), WK.bone_head(rig, "hand.R")
A = {"anchor_head_top": ("head", (0, 0, rig["land"]["crown"] + 0.07)), "anchor_chest": ("hips", (0, 0.1, up.z - 0.14)),
     "anchor_arm_up": ("upper_arm.R", tuple(up + (el - up) * 0.45 + Vector((0.02, 0.03, 0))))
     , "anchor_arm_elbow": ("forearm.R", tuple(el + Vector((0.01, 0.03, 0)))),
     "anchor_arm_fore": ("forearm.R", tuple(el + (hd - el) * 0.5 + Vector((0.01, 0.03, 0))))}
for nm, (bn, at) in A.items():
    WK.anchor(arm, bn, nm, at)

# ---- the sword: skinned to the sword hand (the clips move it), joined to the body, on the flat cells
sw = K.sword()
sm, so = K.sword_matrix(WK.bone_head(rig, "hand.R") + Vector((0, 0, -0.08)))
sv, sf, smat, srooms = [], [], [], []
for pc in sw:
    o = len(sv)
    sv += [tuple(sm @ v + so) for v in pc.v]
    sf += [[o + i for i in f] for f in pc.f]
    smat += [pc.mat] * len(pc.f)
    srooms += [pc.room] * len(pc.v)
wme = bpy.data.meshes.new("weapon")
wme.from_pydata(sv, [], sf)
wme.update()
wob = bpy.data.objects.new("weapon", wme)
sc.collection.objects.link(wob)
wm = sorted(set(smat))
for m in wm:
    mt = bpy.data.materials.new(m)
    mt.use_nodes = True
    t = mt.node_tree.nodes.new("ShaderNodeTexImage")
    t.image = atlas_i
    mt.node_tree.links.new(t.outputs[0], mt.node_tree.nodes["Principled BSDF"].inputs["Base Color"])
    wme.materials.append(mt)
wuv = wme.uv_layers.new(name="UV")
for p in wme.polygons:
    p.material_index = wm.index(smat[p.index])
    for li in p.loop_indices:
        wuv.data[li].uv = cells[smat[p.index]]
wattr = wme.color_attributes.new("ink", "FLOAT_COLOR", "POINT")
wic = np.ones((len(sv), 4), np.float32)
wic[:, 3] = srooms
wattr.data.foreach_set("color", wic.ravel())
wob.vertex_groups.new(name="hand.R").add(list(range(len(sv))), 1.0, "REPLACE")
bpy.ops.object.select_all(action="DESELECT")
wob.select_set(True)
ob.select_set(True)
bpy.context.view_layer.objects.active = ob
bpy.ops.object.join()
me = ob.data
me.polygons.foreach_set("use_smooth", [True] * len(me.polygons))
me.validate()                    # (the decimation leaves a few degenerate faces)
me.update()
for nm, f in (("weapon_muzzle", 1.0), ("anchor_blade_mid", 0.5), ("anchor_blade_root", 0.02)):
    WK.anchor(arm, "hand.R", nm, tuple(np.array(so) + sm @ np.array([0.0, K.BLADE_Y0 + K.BLADE_L * f, 0.0])))
print("tris", WK.tris([ob]))
for o in list(bpy.data.objects):
    if o.name in ("Src", "Low"):
        bpy.data.objects.remove(o)
bpy.ops.wm.save_as_mainfile(filepath=os.path.splitext(OUT)[0] + ".blend")
WK.export(OUT, [arm, ob] + [o for o in bpy.data.objects if o.type == "EMPTY"], colors=True)
print("exported", OUT, os.path.getsize(OUT))
