"""A v95 master's swap-spec `joints` read off Meshy's auto-rig of it, in the fit frame (his right +X, front +Y, soles on z 0).

Run: blender -b --factory-startup --python tools/art1/v95_meshy_joints.py -- WORK
WORK is a v95_swap work dir after a `--weights meshy` swap (WORK/meshy/rigged_character.glb and WORK/meshy/low.glb).
Prints a JSON `joints` block to compare with (or paste into) art/wardens/src/<id>_v95.json. Use it when the master
changes: a spec whose joints were read off an older master fits the limbs to the wrong place (Sparkle 11-20: the
11-12 master's wrists, 7 cm wider and 8 cm higher than the doll master's, left the live arms 20 cm off their bones,
which stretched the hands in every clip). pelvis is at hip height (the specs' convention); neck is Meshy's Head joint.
"""

import json
import os
import sys

import bpy
import numpy as np

MAP = {
    "neck": "Head",
    "shoulder.R": "RightArm",
    "elbow.R": "RightForeArm",
    "wrist.R": "RightHand",
    "shoulder.L": "LeftArm",
    "elbow.L": "LeftForeArm",
    "wrist.L": "LeftHand",
    "hip.R": "RightUpLeg",
    "knee.R": "RightLeg",
    "ankle.R": "RightFoot",
    "hip.L": "LeftUpLeg",
    "knee.L": "LeftLeg",
    "ankle.L": "LeftFoot",
}


def load(path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path)
    return list(bpy.data.objects)


def main():
    work = sys.argv[sys.argv.index("--") + 1]
    obs = load(os.path.join(work, "meshy", "rigged_character.glb"))
    arm = next(o for o in obs if o.type == "ARMATURE")
    me = max((o for o in obs if o.type == "MESH"), key=lambda o: len(o.data.vertices))  # (not the importer's bone shapes)
    R = np.array([me.matrix_world @ v.co for v in me.data.vertices])
    J = {b.name: np.array(arm.matrix_world @ b.head_local) for b in arm.data.bones}
    obs = load(os.path.join(work, "meshy", "low.glb"))
    lo = max((o for o in obs if o.type == "MESH"), key=lambda o: len(o.data.vertices))
    V = np.array([lo.matrix_world @ v.co for v in lo.data.vertices])
    # (the same mapping as v95_swap.meshy_weights: Meshy's mesh centred and scaled, bbox onto Low's; then the fit frame)
    z0 = V[:, 2].min()

    def at(name):
        p = (J[name] - R.min(0)) * (np.ptp(V, 0) / np.ptp(R, 0)) + V.min(0)
        return [round(float(c), 3) for c in p * (-1, -1, 1) - (0, 0, z0)]

    out = {k: at(b) for k, b in MAP.items()}
    hip = (np.array(out["hip.R"]) + out["hip.L"]) / 2
    out["pelvis"] = [round(float(c), 3) for c in (0.0, hip[1], hip[2])]
    out["crown"] = out["neck"][:2] + [round(float(V[:, 2].max() - z0), 3)]
    print("JOINTS " + json.dumps(out))


main()
