"""ART-1 Kael's ledge climb (mantlekit), solved on the first Kael's rig (the build the other 49 clips were keyed on) and played on v2 by kael_retarget.py.
Personality (briefs/LORE_MASKS: grim, cold, never cocky): enormous and economical. The sword hand takes the lip with the blade trailing behind him, the chest
folds deep over it, the knee drives like a piston, and he comes down on the far side heavy, head low, the blade swinging back to his side.
Run: blender -b --python tools/art1/kael_mantle.py -- <kael.blend> <out.glb>   then   kael_retarget.py <out.glb> <kael.glb> <re.glb>   and   glb_add_clips.py <kael.glb> <re.glb> mantle"""
import os
import sys
import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from posekit import Clip, Solver, bake, ang_dir as D, FPS
import mantlekit

SH = 0.2608 * 0.9                                   # m: shoulder half-width (the first rig's)
HAND_Z, SHOULDER_Z, ANKLE_Z, NECK_Z = 0.8228, 1.2678, 0.10, 1.3729   # m: rest heights, arms hanging
GRIP_DIR = Vector((0.0, 0.76, -0.65)).normalized()  # the blade from the fist, rest pose (he faces +Y)
_a = (Vector((0, 0, -1.0)) - GRIP_DIR * GRIP_DIR.dot(Vector((0, 0, -1.0)))).normalized()
GRIP_AT = Vector((SH, 0.0, HAND_Z + 0.012)) + _a * 0.094 + Vector((-0.03, 0.0, 0.0))   # inside the closed fist
DZ, LK = SHOULDER_Z - 1.151, 1.3                    # the keys' build against this rig (Solver.remap)


def be(a, e, edge=(0, 0, 1)):
    """blade toward ang_dir(a, e), its edge toward `edge`."""
    return (D(a, e), edge)


READY = {
    "pel": (0.015, -0.015, -0.065), "prt": (0.10, 0.10, -0.03), "tor": (0.15, 0.12, 0.03), "hed": (-0.16, -0.14, 0.0),
    "G": (0.335, 0.20, 0.66), "BE": be(14, -30, (0.96, 0.1, 0.25)), "Lw": 0.0, "LP": (-0.315, 0.10, 0.63),
    "FL": (-0.165, 0.11, ANKLE_Z), "FR": (0.185, -0.10, ANKLE_Z), "FLy": 0.22, "FRy": -0.42, "FLp": 0.0, "FRp": 0.0,
    "brow": 0.7, "lid": 0.32, "fing": 0.1, "skirt": 0.0,
}
TRAIL = be(176, -30)
MANTLE = {"az": ANKLE_Z, "hx": SH, "dz": DZ, "lk": LK, "hands": {"G": 1.0, "LP": -1.0}, "w": 1.25, "nod": 0.12, "rise": 0.4, "tail": 0.55, "extra": {
    "reach": {"BE": TRAIL, "brow": 1.0, "fing": 0.9},
    "over": {"BE": TRAIL, "fing": 0.9, "tor": (0.5, 0.0, 0.0)},
    "step": {"BE": TRAIL, "fing": 0.9},
    "up": {"BE": be(150, -40), "G": (0.34, -0.1, 0.66), "LP": (-0.32, -0.06, 0.64), "fing": 0.1},
    "top": {"BE": be(100, -35), "G": (0.34, 0.05, 0.62), "LP": (-0.32, 0.05, 0.62)},
    "pop": {"BE": be(60, -40), "G": (0.34, 0.12, 0.66), "LP": (-0.32, 0.1, 0.62)},
    "land": {"BE": be(20, -50), "G": (0.34, 0.2, 0.62), "LP": (-0.32, 0.12, 0.6), "brow": 1.0}}}

if __name__ == "__main__":
    a = sys.argv[sys.argv.index("--") + 1:]
    bpy.ops.wm.open_mainfile(filepath=a[0])
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    rig = {"grip_rest": tuple(GRIP_AT), "blade_rest": tuple(GRIP_DIR), "edge_rest": tuple(_a), "pelvis": NECK_Z - 0.46, "hilt_l": 0.078, "dz": DZ, "leg_k": LK, "ankle_keys": ANKLE_Z, "ankle": ANKLE_Z,
           "lhand": {"k": (0, 1, -0.15), "o": (-1, 0, 0), "palm": (-SH + 0.006, 0.0, HAND_Z - 0.052)}}
    bpy.context.scene.render.fps = FPS
    sol = Solver(arm, rig)
    bpy.context.view_layer.objects.active = arm
    c = mantlekit.clip(lambda n, d, k: Clip(n, d, k, READY), READY, MANTLE)
    bake(arm, c, sol, lambda P: {})
    print("clips 1", c.name, round(c.dur, 3))
    bpy.ops.object.select_all(action="DESELECT")
    for o in bpy.data.objects:
        if o.type in ("ARMATURE", "MESH", "EMPTY") and o.name not in ("Src", "Low", "Skirt"):
            o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=a[1], export_format="GLB", use_selection=True, export_apply=False, export_animations=True,
                              export_animation_mode="ACTIONS", export_skins=True, export_yup=True, export_materials="EXPORT",
                              export_image_format="JPEG", export_jpeg_quality=92, export_extras=False, export_vertex_color="ACTIVE",
                              export_force_sampling=True, export_frame_step=1, export_optimize_animation_size=False, export_def_bones=False)
    print("exported", os.path.getsize(a[1]))
