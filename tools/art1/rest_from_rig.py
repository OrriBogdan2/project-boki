"""v95_swap's `rest_rig` (a Warden id): the game .glb's rest moves onto that Warden's current rig rest
(content/rules/warden_rest.json, WardenGlb.neutral_rest), so a regen can change the rig's proportions (archetype body
"legs", "torso", "neck") to the new art's instead of squashing the art onto the old rig. Albert's turnaround legs are 2x
his old rig's: the squash gave stubby legs and stretched knees (11-20).
 - every rig bone's head goes to its rig node; a bone keeps its axis (the clips' rotations mean what they did) and
   reaches the child at its tail (thigh to shin, shin to foot), else keeps its length;
 - bones the rig doesn't place (fingers, foot, weapon, shield, spring chains) ride their nearest placed ancestor; a
   foot scales with its leg (the rig's legs scale on y);
 - skinned meshes (the kept parts, the game's hammer) move with their bones;
 - each clip's root height is corrected per key so the lower foot stays as high over its rest as it was (a crouch on
   longer legs would push the feet under the floor)."""
import json
import os

import bpy
from mathutils import Vector

REST = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "content", "rules", "warden_rest.json")


def rig_heads(warden):
    """The rig's bone heads, Blender frame (Godot's (x, y, z) is Blender's (x, -z, y))."""
    rest = json.load(open(REST))[warden]
    return {b: Vector((m[9], -m[11], m[10])) for b, m in rest.items()}


def _feet(arm, feet):
    """Per action, per key frame: the lower foot's lowest point (armature z)."""
    out = {}
    for act in bpy.data.actions:
        arm.animation_data.action = act
        frames = sorted({round(kp.co[0]) for fc in act.fcurves for kp in fc.keyframe_points})
        rows = []
        for f in frames:
            bpy.context.scene.frame_set(f)
            rows.append(min(min(arm.pose.bones[n].head.z, arm.pose.bones[n].tail.z) for n in feet))
        out[act.name] = dict(zip(frames, rows))
    arm.animation_data.action = None
    return out


def _ground(arm, before, after, rest0, rest1):
    """Root keys: the lower foot keeps its height over its rest. Returns the largest correction."""
    root = next(b for b in arm.data.bones if b.parent is None)
    dl = root.matrix_local.to_3x3().inverted() @ Vector((0, 0, 1))
    path = 'pose.bones["%s"].location' % root.name
    worst = 0.0
    for act in bpy.data.actions:
        fcs = sorted((fc for fc in act.fcurves if fc.data_path == path), key=lambda c: c.array_index)
        if len(fcs) != 3:
            continue
        for i, fc in enumerate(fcs):
            for kp in fc.keyframe_points:
                f = round(kp.co[0])
                dz = (before[act.name][f] - rest0) - (after[act.name][f] - rest1)
                worst = max(worst, abs(dz))
                for h in (kp.co, kp.handle_left, kp.handle_right):
                    h[1] += dz * dl[i]
    return worst


def _new_heads(B, want):
    head0 = {b.name: b.head_local.copy() for b in B}
    new = {}
    for b in B:     # (parents first: bones are listed root down)
        if b.name in want:
            new[b.name] = want[b.name]
            continue
        p = b.parent
        while p and p.name not in want:
            p = p.parent
        if p and p.name.startswith("shin.") and p.parent and p.parent.name in want:     # (a foot: the leg's y scale)
            th = p.parent.name
            s = (want[th].z - want[p.name].z) / (head0[th].z - head0[p.name].z)
            kid = head0[b.name] - head0[p.name]
            new[b.name] = new[p.name] + Vector((kid.x, kid.y, kid.z * s))
        else:
            new[b.name] = head0[b.name] + (new[p.name] - head0[p.name] if p else Vector())
    return head0, new


def apply(arm, meshes, warden):
    """Moves the rest (see the module doc). Returns {bone: head offset}."""
    B = arm.data.bones
    want = rig_heads(warden)
    head0, new = _new_heads(B, want)
    tail0 = {b.name: b.tail_local.copy() for b in B}
    feet = [b.name for b in B if b.parent and b.parent.name.startswith("shin.")]
    mods = [(m, m.show_viewport) for o in bpy.data.objects if o.type == "MESH" for m in o.modifiers]
    for m, _ in mods:
        m.show_viewport = False
    keep = arm.animation_data.action
    before = _feet(arm, feet)
    rest0 = min(min(head0[n].z, tail0[n].z) for n in feet)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    for eb in arm.data.edit_bones:
        n = eb.name
        eb.use_connect = False
        kids = [c.name for c in B[n].children if (head0[c.name] - tail0[n]).length < 1e-3]
        eb.head, eb.tail = new[n], (new[kids[0]] if kids else new[n] + (tail0[n] - head0[n]))
    bpy.ops.object.mode_set(mode="OBJECT")
    off = {n: new[n] - head0[n] for n in new}
    for ob in meshes:
        gname = {g.index: g.name for g in ob.vertex_groups}
        for v in ob.data.vertices:
            if v.groups:
                v.co += off.get(gname[max(v.groups, key=lambda e: e.weight).group], Vector())
    after = _feet(arm, feet)
    rest1 = min(min(B[n].head_local.z, B[n].tail_local.z) for n in feet)
    worst = _ground(arm, before, after, rest0, rest1)
    arm.animation_data.action = keep
    for m, s in mods:
        m.show_viewport = s
    print("REST rig %s: z %s; root z fix max %.3f" % (warden, {n: round(off[n].z, 3) for n in want if n in off}, worst),
          flush=True)
    return off
