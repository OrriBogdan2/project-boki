"""Tarek's v2 model (ART-1, briefs/art-refs/tarek_v2): the fitted Meshy scan (fit_warden, tarek_fit.json) finished on the
contract armature. Adds the foot, lip and jaw bones, keys the carved jade glyphs of his stone into an emission map (the dark
seams stay dark), and adds the scripted props: three rough eye-stones orbiting his head, the shards round his right fist and the
ground rings, plus every anchor his kit's FX read.
    blender -b --factory-startup --python tools/art1/tarek_scan.py -- <fit.blend> <out dir>
Writes <out dir>/tarek.blend for tools/art1/tarek_clips.py."""
import math
import os
import subprocess
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector, noise

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "blender"))
import warden_kit as K  # noqa: E402

FIT, OUT = sys.argv[sys.argv.index("--") + 1:][:2]
JADE = np.array((0.36, 0.9, 0.72), np.float32)     # the glyphs' glow: jade with a slight teal (owner, 2026-11-07)
GLYPH_GREEN = (0.04, 0.12)    # how far a texel's green must stand over its red to read as a glyph (soft ramp)
GLYPH_BRIGHT = (0.3, 0.45)   # and how bright its green must be (the dark seams never pass)
STONE_R = 0.06                # m: an eye-stone's radius before its orbit scale
STONES = ({"angle": 300, "height": 0.34, "k": 1.3}, {"angle": 60, "height": 0.42, "k": 1.36}, {"angle": 180, "height": 0.3, "k": 1.2})
ORBIT_R = 0.45                # m: the eye-stones' orbit round the head's centre
STONE_TILT = 56               # degrees: each stone's eye tipped up toward the high match camera
FOOT_Z = (0.15, 0.08)         # m: the shin hands the foot over between these heights (smooth)
STONE_BONES = ("upper_arm.L", "forearm.L", "hand.L", "forearm.R")    # his stone: the whole left arm, the right gauntlet
CHEST_Z = 1.5                 # m: above this, his left breast (-x) is stone too (the waist wrap sits lower)


def log(*a):
    print("TAREKSCAN", *a, flush=True)


def verts_np(ob):
    a = np.zeros(len(ob.data.vertices) * 3, np.float32)
    ob.data.vertices.foreach_get("co", a)
    return a.reshape(-1, 3)


def sstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def group_mask(ob, name, w_min=0.5):
    gi = ob.vertex_groups[name].index
    return np.array([any(g.group == gi and g.weight > w_min for g in v.groups) for v in ob.data.vertices])


def add_bones(arm, body):
    """The feet (skinned from the shins below the ankle), the lips and the jaw (the contract's face bones)."""
    P = verts_np(body)
    skin = {i for i, m in enumerate(body.data.materials) if m.name.startswith("skin")}
    face = np.zeros(len(P), bool)
    for pl in body.data.polygons:
        if pl.material_index in skin:
            face[list(pl.vertices)] = True
    hc = Vector(P[face & group_mask(body, "head")].mean(0))
    hc.x = 0.0
    feet = {}
    for sd, sx in (("L", -1.0), ("R", 1.0)):
        ring = P[(np.abs(P[:, 2] - 0.11) < 0.03) & (P[:, 0] * sx > 0.02)]
        feet[sd] = Vector((ring[:, 0].mean(), ring[:, 1].mean(), 0.11))
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm.data.edit_bones

    def bone(nm, parent, head, tail):
        e = eb.new(nm)
        e.head, e.tail = head, tail
        e.align_roll(Vector((0, 0, 1)))
        e.parent = eb[parent]
        e.use_connect = False

    for sd, sx in (("L", -1.0), ("R", 1.0)):
        bone("foot." + sd, "shin." + sd, feet[sd], feet[sd] + Vector((0, 0.12, -0.04)))
        bone("lip." + sd, "head", hc + Vector((0.062 * sx, 0.1, -0.068)), hc + Vector((0.062 * sx, 0.125, -0.068)))
    bone("jaw", "head", hc + Vector((0, -0.02, -0.055)), hc + Vector((0, 0.09, -0.125)))
    bpy.ops.object.mode_set(mode="OBJECT")
    for sd in ("L", "R"):
        sh = body.vertex_groups["shin." + sd]
        g = body.vertex_groups.new(name="foot." + sd)
        for v in body.data.vertices:
            w = next((x.weight for x in v.groups if x.group == sh.index), 0.0)
            k = float(sstep(FOOT_Z[0], FOOT_Z[1], v.co.z)) * w
            if k > 0.01:
                g.add([v.index], k, "REPLACE")
                sh.add([v.index], w - k + 1e-4, "REPLACE")
    return hc


def save_img(a, name):
    """Display-space numbers straight into a JPEG (ffmpeg: no colour management in the way), packed into the .blend."""
    h, w = a.shape[:2]
    raw = os.path.join(OUT, name + ".rgb")
    (np.clip(a[::-1], 0, 1) * 255.0 + 0.5).astype(np.uint8).tofile(raw)
    path = os.path.join(OUT, name + ".jpg")
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", "%dx%d" % (w, h), "-i", raw,
                    "-q:v", "3", "-pix_fmt", "yuvj444p", path], check=True)
    os.remove(raw)
    im = bpy.data.images.load(path)
    im.pack()
    return im


def face_mask(me, faces, w, h):
    """The atlas texels under the given faces (their UV triangles, filled)."""
    uv = np.zeros(len(me.loops) * 2, np.float32)
    me.uv_layers.active.data.foreach_get("uv", uv)
    uv = uv.reshape(-1, 2) * (w, h)
    mask = np.zeros((h, w), bool)
    for pl in faces:
        li = list(pl.loop_indices)
        for i in range(1, len(li) - 1):
            t = uv[[li[0], li[i], li[i + 1]]]
            x0, y0 = np.floor(t.min(0)).astype(int)
            x1, y1 = np.ceil(t.max(0)).astype(int)
            xs, ys = np.meshgrid(np.arange(max(x0, 0), min(x1, w)) + 0.5, np.arange(max(y0, 0), min(y1, h)) + 0.5)
            if xs.size == 0:
                continue
            (ax, ay), (bx, by), (cx, cy) = t
            d = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
            if abs(d) < 1e-9:
                continue
            l1 = ((by - cy) * (xs - cx) + (cx - bx) * (ys - cy)) / d
            l2 = ((cy - ay) * (xs - cx) + (ax - cx) * (ys - cy)) / d
            inside = (l1 >= -0.01) & (l2 >= -0.01) & (l1 + l2 <= 1.02)
            mask[ys[inside].astype(int), xs[inside].astype(int)] = True
    return mask


def stone_slot(body):
    """Stone the fit's colour vote left on the cloth slot (its glyphs, its pale facets) goes back to the stone (leather):
    no cloth hangs on his arms or over his left breast, where the stone climbs onto the chest."""
    me = body.data
    names = [m.name.split("-")[0] for m in me.materials]
    cloth, lea = names.index("cloth"), names.index("leather")
    gn = [g.name for g in body.vertex_groups]
    dom = [gn[max(v.groups, key=lambda g: g.weight).group] if len(v.groups) else "" for v in me.vertices]
    n = 0
    for pl in me.polygons:
        c = pl.center
        if pl.material_index == cloth and (dom[pl.vertices[0]] in STONE_BONES or (c.x < -0.05 and c.z > CHEST_Z)):
            pl.material_index = lea
            n += 1
    log("cloth faces to stone", n)


def glyph_emission(body):
    """The carved glyphs on his stone, keyed from the atlas into the emission map (jade, slightly teal); the seams stay dark.
    Returns the emission image and two atlas UVs the props sample: a mid-grey stone texel and a bright glyph texel."""
    me = body.data
    lea = next(i for i, m in enumerate(me.materials) if m.name.startswith("leather"))
    img = next(n.image for n in me.materials[lea].node_tree.nodes if n.type == "TEX_IMAGE")
    w, h = img.size
    A = np.zeros(w * h * 4, np.float32)
    img.pixels.foreach_get(A)
    A = A.reshape(h, w, 4)[:, :, :3]
    mask = face_mask(me, [p for p in me.polygons if p.material_index == lea], w, h)
    g_r = A[:, :, 1] - A[:, :, 0]
    key = sstep(*GLYPH_GREEN, g_r) * sstep(*GLYPH_BRIGHT, A[:, :, 1]) * mask
    grown = key.copy()          # (one texel wider, so the thin strokes survive the half-size map)
    for ax in (0, 1):
        for d in (1, -1):
            grown = np.maximum(grown, np.roll(key, d, ax))
    key = grown * mask
    lum = A.mean(2)
    emit = key[:, :, None] * (0.5 * A + 0.5 * JADE * np.maximum(lum, 0.6)[:, :, None])
    log("glyph texels", int((key > 0.5).sum()), "of stone", int(mask.sum()))
    im = save_img((emit[::2, ::2] + emit[1::2, ::2] + emit[::2, 1::2] + emit[1::2, 1::2]) * 0.25, "tarek_emit")
    sat = A.max(2) - A.min(2)
    grey = mask & (sat < 0.06) & (key < 0.01)
    gy, gx = np.nonzero(grey)
    order = np.argsort(lum[gy, gx])
    i = order[len(order) // 2]
    ky, kx = np.unravel_index(np.argmax(key * A[:, :, 1]), key.shape)
    return im, ((gx[i] + 0.5) / w, (gy[i] + 0.5) / h), ((kx + 0.5) / w, (ky + 0.5) / h)


def emissive(mat, im):
    nt = mat.node_tree
    n = nt.nodes.new("ShaderNodeTexImage")
    n.image = im
    b = nt.nodes["Principled BSDF"]
    nt.links.new(n.outputs[0], b.inputs["Emission Color"])
    b.inputs["Emission Strength"].default_value = 1.0


def glow_material(atlas, im):
    m = bpy.data.materials.new("glow-tarek")
    m.use_nodes = True
    nt = m.node_tree
    t = nt.nodes.new("ShaderNodeTexImage")
    t.image = atlas
    nt.links.new(t.outputs[0], nt.nodes["Principled BSDF"].inputs["Base Color"])
    emissive(m, im)
    return m


def flat_uv(me, uv, faces=None):
    """Every loop (of the given faces) onto one atlas texel: a flat painted colour from the scan's own palette."""
    lay = me.uv_layers.get("UVMap") or me.uv_layers.new(name="UVMap")
    for pl in me.polygons if faces is None else faces:
        for li in pl.loop_indices:
            lay.data[li].uv = uv


def eye_stone(rock, glow, grey_uv, jade_uv):
    """A rough grey stone with one jade-teal eye on its +Y face, inset."""
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=3, radius=STONE_R)
    for v in bm.verts:
        n = noise.noise(v.co * (2.4 / STONE_R))
        v.co *= 1.0 + 0.16 * n
        v.co.z *= 0.86
    eye = [f for f in bm.faces if f.normal.normalized().y > 0.9]
    for f in eye:
        for v in f.verts:
            v.co.y -= 0.004
    me = bpy.data.meshes.new("eye_stone")
    bm.to_mesh(me)
    eye_ix = {f.index for f in eye}
    bm.free()
    me.materials.append(rock)
    me.materials.append(glow)
    me.uv_layers.new(name="UVMap")
    for pl in me.polygons:
        pl.material_index = 1 if pl.index in eye_ix else 0
    flat_uv(me, grey_uv)
    flat_uv(me, jade_uv, [p for p in me.polygons if p.material_index == 1])
    log("eye-stone tris", len(me.polygons), "eye", len(eye_ix))
    return me


def shard(rock, grey_uv):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=6, v_segments=3, radius=1.0)
    bmesh.ops.scale(bm, vec=(0.028, 0.024, 0.05), verts=bm.verts)
    me = bpy.data.meshes.new("shard")
    bm.to_mesh(me)
    bm.free()
    me.materials.append(rock)
    me.uv_layers.new(name="UVMap")
    flat_uv(me, grey_uv)
    return me


def empty(name, arm, bone=None, world=None):
    e = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(e)
    e.parent = arm
    if bone:
        e.parent_type = "BONE"
        e.parent_bone = bone
    bpy.context.view_layer.update()
    if world is not None:
        e.matrix_world = Matrix.Translation(Vector(world))
    return e


def orbits(arm, hc, stone_me, shard_me, fist_r):
    """The eye-stones on an orbit round his head and the shards round his right fist (WardenGlb.Orbits turns them)."""
    e = empty("orbit_stones", arm, "head", hc)
    out = [e]
    tilt = math.radians(STONE_TILT)
    for i, it in enumerate(STONES):
        a = math.radians(it["angle"])
        o = bpy.data.objects.new("stone_%d" % i, stone_me)
        bpy.context.scene.collection.objects.link(o)
        o.parent = e
        p = hc + Vector((-math.sin(a), math.cos(a), 0)) * ORBIT_R + Vector((0, 0, it["height"]))
        o.matrix_world = Matrix.Translation(p) @ Matrix.Rotation(a, 4, "Z") @ Matrix.Rotation(tilt, 4, "X") @ Matrix.Scale(it["k"], 4)
        an = bpy.data.objects.new("anchor_stones_%d" % i, None)
        bpy.context.scene.collection.objects.link(an)
        an.parent = o
        an.location = (0, STONE_R, 0)
        out += [o, an]
    s = empty("orbit_shards", arm, "hand.R", fist_r)
    out.append(s)
    for i in range(5):
        a = 2 * math.pi * i / 5
        o = bpy.data.objects.new("shard_%d" % i, shard_me)
        bpy.context.scene.collection.objects.link(o)
        o.parent = s
        o.matrix_world = Matrix.Translation(Vector(fist_r) + Vector((math.cos(a) * 0.2, math.sin(a) * 0.2, (i % 3 - 1) * 0.05))) \
            @ Matrix.Rotation(a * 1.7, 4, "X")
        out.append(o)
    return out


def ground_rings(arm, glow, jade_uv):
    """The glowing rings under his feet: two broken arcs on the ground (they travel with him, turning slowly)."""
    bm = bmesh.new()
    for rad, w, arcs in ((0.62, 0.016, ((0.1, 2.9), (3.4, 5.9))), (0.46, 0.013, ((1.2, 3.9), (4.5, 6.9)))):
        for a0, a1 in arcs:
            n = 12
            vs = []
            for i in range(n + 1):
                a = a0 + (a1 - a0) * i / n
                t = 1.0 - abs(2.0 * i / n - 1.0) ** 3
                for r in (rad - w * t, rad + w * t):
                    vs.append(bm.verts.new((r * math.cos(a), r * math.sin(a), 0.03)))
            for i in range(n):
                bm.faces.new((vs[i * 2], vs[i * 2 + 1], vs[i * 2 + 3], vs[i * 2 + 2]))
    me = bpy.data.meshes.new("ground_rings")
    bm.to_mesh(me)
    bm.free()
    me.materials.append(glow)
    me.uv_layers.new(name="UVMap")
    flat_uv(me, jade_uv)
    e = empty("orbit_ground", arm)
    ob = bpy.data.objects.new("ground_rings", me)
    bpy.context.scene.collection.objects.link(ob)
    ob.parent = e
    return [e, ob]


def centroid(body, group):
    return Vector(verts_np(body)[group_mask(body, group)].mean(0))


def anchors(arm, body):
    """The FX points the kit reads (scripts/arch/kits/dolm_kit.gd): the fists are his weapon."""
    out = []
    for sd, sx in (("L", -1.0), ("R", 1.0)):
        out.append(empty("anchor_gauntlet_" + sd, arm, "forearm." + sd, centroid(body, "forearm." + sd) + Vector((0.06 * sx, 0, 0))))
        out.append(empty("anchor_fist_" + sd, arm, "hand." + sd, centroid(body, "hand." + sd)))
    wrist = arm.data.bones["hand.R"].head_local
    out.append(empty("anchor_wrist_R", arm, "hand.R", wrist))
    out.append(empty("weapon_muzzle", arm, "hand.R", centroid(body, "hand.R") + Vector((0, 0, -0.05))))
    return out


def main():
    bpy.ops.wm.open_mainfile(filepath=os.path.expanduser(FIT))
    os.makedirs(OUT, exist_ok=True)
    arm = bpy.data.objects["Armature"]
    body = bpy.data.objects["Body"]
    body.name = body.data.name = "tarek_body"
    me = body.data
    used = {p.material_index for p in me.polygons}
    for i in reversed(range(len(me.materials))):
        if i not in used:
            me.materials.pop(index=i)
    hc = add_bones(arm, body)
    stone_slot(body)
    im, grey_uv, jade_uv = glyph_emission(body)
    rock = next(m for m in me.materials if m.name.startswith("leather"))
    emissive(rock, im)
    atlas = next(n.image for n in rock.node_tree.nodes if n.type == "TEX_IMAGE" and n.image != im)
    atlas.name = "tarek_atlas"
    im.name = "tarek_emit"
    glow = glow_material(atlas, im)
    stone_me = eye_stone(rock, glow, grey_uv, jade_uv)
    shard_me = shard(rock, grey_uv)
    fist_r = centroid(body, "hand.R")
    extras = orbits(arm, hc, stone_me, shard_me, fist_r) + anchors(arm, body) + ground_rings(arm, glow, jade_uv)
    log("tris total", K.tris([body] + [o for o in extras if o.type == "MESH"]))
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "tarek.blend"))


main()
