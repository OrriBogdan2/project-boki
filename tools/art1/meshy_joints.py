"""A new Meshy master's swap joints from Meshy's own auto-rig (docs/art/wardens/V95_SWAP.md "Regen from the turnaround"):
no hand-read grid renders. Two modes (Blender):
  prep   GEN_GLB OUT_GLB HEIGHT    the generation scaled so its soles-to-crown height is HEIGHT m (the spec's metres)
  joints MASTER_GLB RIGGED_GLB OUT_JSON
                                   the rigged copy's bone heads (Meshy centres and rescales it: matched to the master by
                                   its bounding box) in the fit frame (his front +Y, his right +X, soles on z 0: a Meshy
                                   master turned 180 degrees and lifted by its sole), as a spec patch: `joints`, `head`.
Run: blender -b --factory-startup --python tools/art1/meshy_joints.py -- MODE ARGS"""
import json
import sys

import bpy
import numpy as np

# spec joint <- the Meshy bone whose head it is ("crown": the head_end tail)
BONES = {"pelvis": "Hips", "neck": "neck", "hip.R": "RightUpLeg", "knee.R": "RightLeg", "ankle.R": "RightFoot",
         "hip.L": "LeftUpLeg", "knee.L": "LeftLeg", "ankle.L": "LeftFoot", "shoulder.R": "RightArm",
         "elbow.R": "RightForeArm", "wrist.R": "RightHand", "shoulder.L": "LeftArm", "elbow.L": "LeftForeArm",
         "wrist.L": "LeftHand"}


def load(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    return [o for o in bpy.data.objects if o not in before]


def mesh_points(obs):
    pts = [np.array([o.matrix_world @ v.co for v in o.data.vertices]) for o in obs if o.type == "MESH"]
    return np.concatenate(pts)


def prep(gen, out, height):
    obs = load(gen)
    P = mesh_points(obs)
    k = height / np.ptp(P[:, 2])
    roots = [o for o in obs if o.parent is None]
    for o in roots:
        o.matrix_world = o.matrix_world.copy()
        o.scale = [s * k for s in o.scale]
        o.location = o.location * k
    bpy.ops.object.select_all(action="DESELECT")
    for o in obs:
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_selection=True, export_apply=True,
                              export_image_format="JPEG", export_jpeg_quality=92)
    print("MJOINTS prep: height %.3f -> %.3f m (x%.3f) -> %s" % (np.ptp(P[:, 2]), height, k, out))


def joints(master, rigged, out):
    M = mesh_points(load(master))
    obs = load(rigged)
    arm = next(o for o in obs if o.type == "ARMATURE")
    R = mesh_points([o for o in obs if o.parent == arm])  # (not Meshy's loose helper icosphere)
    k = np.ptp(M[:, 2]) / np.ptp(R[:, 2])
    lo_r = np.array([(R[:, 0].min() + R[:, 0].max()) / 2, (R[:, 1].min() + R[:, 1].max()) / 2, R[:, 2].min()])
    lo_m = np.array([(M[:, 0].min() + M[:, 0].max()) / 2, (M[:, 1].min() + M[:, 1].max()) / 2, M[:, 2].min()])
    sole = M[:, 2].min()

    def fit(p):  # rigged -> master -> fit frame
        q = (np.array(p) - lo_r) * k + lo_m
        return [round(-q[0], 3), round(-q[1], 3), round(q[2] - sole, 3)]

    bones = arm.data.bones
    head = lambda n: arm.matrix_world @ bones[n].head_local  # noqa: E731
    J = {j: fit(head(b)) for j, b in BONES.items()}
    top = fit(head("head_end") if "head_end" in bones else head("Head"))
    J["crown"] = [0.0, top[1], round(float(np.ptp(M[:, 2])) - 0.02, 3)]  # (head_end's tail is not the crown)
    J["pelvis"] = [J["pelvis"][0], J["pelvis"][1], round((J["hip.L"][2] + J["hip.R"][2]) / 2, 3)]
    if J["shoulder.L"][0] > 0:
        sys.exit("MJOINTS: Meshy's Left bones sit at +x in the fit frame (his right): the master is not facing -Y")
    hc = fit(head("Head"))
    r = round(max(0.12, min(0.18, (J["crown"][2] - hc[2]) * 0.6)), 3)
    patch = {"joints": J, "head": {"centre": [0.0, hc[1], round((hc[2] + J["crown"][2]) / 2, 3)], "r": r}}
    json.dump(patch, open(out, "w"), indent=1)
    print("MJOINTS", json.dumps(patch))


a = sys.argv[sys.argv.index("--") + 1:]
bpy.ops.wm.read_factory_settings(use_empty=True)
if a[0] == "prep":
    prep(a[1], a[2], float(a[3]))
else:
    joints(a[1], a[2], a[3])
