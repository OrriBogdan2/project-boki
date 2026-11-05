"""Armature, skin weights, clips and export for a rigged Boki. Rotations in the clips are written in the creature's
own axes (rx: nose up, ry: turn to its left... see pose_key), so a clip reads the same on every bone."""
import bpy
import mathutils
import numpy as np

KEEP_INFLUENCES = 4
HARD_PIECES = ("tail", "collar", "sting", "tail_fin", "gills", "shards")
CLIP_SCALE = 0.95    # clip offsets are in the build's metres
# where an unused prop sits (from its rest place), collapsed inside the body so its ink shell never shows
HIDE_AT = {}


def armature(bones, bl):
    """bones: name -> (head, tail, parent), game axes."""
    data = bpy.data.armatures.new("Rig")
    obj = bpy.data.objects.new("Rig", data)
    bpy.context.scene.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    for name, (head, tail, _) in bones.items():
        e = data.edit_bones.new(name)
        e.head = bl(np.asarray(head, float)).tolist()
        e.tail = bl(np.asarray(tail, float)).tolist()
    for name, (_, _, parent) in bones.items():
        if parent:
            data.edit_bones[name].parent = data.edit_bones[parent]
    bpy.ops.object.mode_set(mode="OBJECT")
    obj.select_set(False)
    return obj


def bind(obj, arm):
    obj.parent = arm
    mod = obj.modifiers.new("Armature", "ARMATURE")
    mod.object = arm


def skin(body, face_obj, arm, pieces, piece_of, bl, sigma=0.012):
    """The creature: its body from the primitives, its face all on the head."""
    skin_only(body, arm, pieces, sigma)
    g = face_obj.vertex_groups.new(name="head")
    g.add(list(range(len(face_obj.data.vertices))), 1.0, "REPLACE")
    bind(face_obj, arm)


def skin_only(body, arm, pieces, sigma=0.012):
    """Each vertex follows the primitives it sits on, softened by their blend radii."""
    offset = 0
    groups = {}

    def group(obj, name):
        key = (obj.name, name)
        if key not in groups:
            groups[key] = obj.vertex_groups.new(name=name)
        return groups[key]

    for pc in pieces:
        prims = [p for p in pc.shape.prims if not p.sub]
        d = np.stack([p.d(pc.v) for p in prims], -1)
        bones = sorted({p.bone for p in prims})
        w = np.zeros((len(pc.v), len(bones)))
        hard = pc.prop or pc.name in HARD_PIECES
        s = 0.002 if hard else sigma
        for j, b in enumerate(bones):
            sel = [i for i, p in enumerate(prims) if p.bone == b]
            w[:, j] = np.exp(-np.maximum(d[:, sel].min(1) - d.min(1), 0.0) / s)
        order = np.argsort(-w, axis=1)[:, :KEEP_INFLUENCES]
        for i in range(len(pc.v)):
            top = order[i]
            vals = w[i, top]
            vals = vals / vals.sum()
            for j, val in zip(top, vals):
                if val > 0.03:
                    group(body, bones[j]).add([offset + i], float(val), "REPLACE")
        offset += len(pc.v)
    bind(body, arm)


def game_axis(v):
    return mathutils.Vector((v[0], -v[2], v[1]))


def quat_of(rx, ry, rz):
    """Game-axis euler to a Blender rotation."""
    return (mathutils.Quaternion(game_axis((0, 1, 0)), ry) @ mathutils.Quaternion(game_axis((1, 0, 0)), rx)
            @ mathutils.Quaternion(game_axis((0, 0, 1)), rz))


def bone_home(b, arm):
    """From a grown part's rest place to its parent's: collapsed there, inside the body, until BokiDna shows it."""
    return (b.parent.bone.head_local - b.bone.head_local)


def make_clips(arm, clips, fps=30):
    bpy.context.scene.render.fps = fps
    arm.animation_data_create()
    rest = {b.name: b.bone.matrix_local.to_quaternion() for b in arm.pose.bones}
    for b in arm.pose.bones:
        b.rotation_mode = "QUATERNION"
    for name, (seconds, loop, fn) in clips.items():
        action = bpy.data.actions.new(name)
        action.use_fake_user = True
        arm.animation_data.action = action
        frames = max(2, int(round(seconds * fps)))
        for f in range(frames + 1):
            pose = fn(f / frames if loop else f / frames)
            for b in arm.pose.bones:
                rot = pose.get(b.name, (0, 0, 0))
                rot = (0, 0, 0) if rot == "on" else rot
                q = rest[b.name].inverted() @ quat_of(*rot) @ rest[b.name]
                b.rotation_quaternion = q
                b.keyframe_insert("rotation_quaternion", frame=f + 1)
                hide = HIDE_AT.get(b.name)
                part = b.name.startswith("part_")
                if part:
                    off = bone_home(b, arm)
                    b.location = rest[b.name].inverted() @ off
                    b.keyframe_insert("location", frame=f + 1)
                    b.scale = (0.001, 0.001, 0.001)
                    b.keyframe_insert("scale", frame=f + 1)
                if b.name in ("root", "hips") or hide:
                    off = pose.get(b.name + "_at", (0, 0, 0))
                    if hide and pose.get(b.name) != "on":
                        off = hide
                    w = game_axis(off) * CLIP_SCALE
                    b.location = rest[b.name].inverted() @ w
                    b.keyframe_insert("location", frame=f + 1)
                sc = pose.get(b.name + "_sc", None)
                if b.name.startswith("prop_"):
                    sc = (1, 1, 1) if pose.get(b.name) == "on" else (0.001, 0.001, 0.001)
                elif sc is None:
                    sc = (1, 1, 1)
                if b.name == "root" or b.name.startswith("prop_"):
                    b.scale = _bone_scale(rest[b.name], sc)
                    b.keyframe_insert("scale", frame=f + 1)
    arm.animation_data.action = None


def _bone_scale(rest, sc):
    """Squash given along game x, y, z, for a bone whose rest axes may differ: uses the closest local axes."""
    m = rest.to_matrix()
    out = [1.0, 1.0, 1.0]
    for i, axis in enumerate(((1, 0, 0), (0, 1, 0), (0, 0, 1))):
        v = game_axis(axis)
        scores = [abs(m.col[j].dot(v)) for j in range(3)]
        out[scores.index(max(scores))] = sc[i]
    return out


def export(path):
    import os
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=path, export_format="GLB", export_animations=True, export_animation_mode="ACTIONS",
        export_force_sampling=True, export_frame_step=1, export_morph=True, export_skins=True,
        export_morph_normal=True, export_vertex_color="ACTIVE", export_all_vertex_colors=False, export_image_format="WEBP", export_image_quality=88, export_apply=False,
        export_yup=True, export_def_bones=False, export_extras=False)
