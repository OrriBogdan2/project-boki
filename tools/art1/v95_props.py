"""A v95 master (the Model Room's ~/meshy/v95/<Name>/v95.glb: Meshy, no rig) + its Hunter's props from the game .glb.

The owner (11-13, "should motley have his cards with him?" -> yes): a v95 master shows the props the game model carries.
No new modelling: each prop is the game mesh itself (copied whole, so its UVs, materials and textures come along),
moved from the game's rest frame into the master's fit frame (V95_SWAP.md: the master turned 180 deg about z, soles
on z 0, his front +Y, his right +X) and scaled by the height ratio. One empty, props_fit_to_master, carries them back
into the master's own frame, so the master itself is untouched (face lock: v95-promote keeps the head anyway).

    blender -b --factory-startup --python tools/art1/v95_props.py --
        <ostra|breaker|tarek> MASTER.glb GAME.glb OUT.glb OUT.jpg [x,y,z]

ostra   (Motley): the game's Fan on his left palm (x_fan, warden_fix_1112.py) and the 8 orbit cards on their two rings,
        spinning slowly (the game spins them in script, the Model Room plays the first clip).
breaker (Albert): the game's hammer in his right fist (anchor_hammer_grip on the fist).
tarek   (Tarek): the game's five fist shards about his right fist and the ground rings under his feet.
x,y,z (fit frame, m) overrides the measured hand. Writes OUT.jpg (3/4 view) and OUT_hand.jpg (the prop's hand close up).
"""
import math
import os
import sys

import bpy
import numpy as np
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:]
recipe = argv[0]
master_p, game_p, out_glb, out_jpg = [os.path.abspath(a) for a in argv[1:5]]
HAND = np.array(argv[5].split(","), float) if len(argv) > 5 else None
FAN_GRIP = np.array([0.03, 0.0, 0.03])   # warden_fix_1112.py: the fan's foot from the glove centre (game rest frame)
PROP_NAMES = ("x_fan_cards", "orbit_cards", "x_hammer", "props_fit_to_master")   # an earlier run's props, stripped


def world_verts(o):
    a = np.empty(len(o.data.vertices) * 3)
    o.data.vertices.foreach_get("co", a)
    M = np.array(o.matrix_world)
    return a.reshape(-1, 3) @ M[:3, :3].T + M[:3, 3]


def carry(src, M, name):
    """A copy of the game mesh src (UVs, materials, textures kept) with M (its local coords -> fit frame) baked in."""
    me = src.data.copy()
    me.name = name
    me.transform(M)
    if M.to_3x3().determinant() < 0:
        me.flip_normals()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=master_p)
for o in list(bpy.data.objects):
    if o.name.startswith(PROP_NAMES):
        bpy.data.objects.remove(o, do_unlink=True)
masters = [o for o in bpy.data.objects if o.type == "MESH"]
bpy.context.view_layer.update()
P0 = np.vstack([world_verts(o) for o in masters])
sole = P0[:, 2].min()
P = np.stack([-P0[:, 0], -P0[:, 1], P0[:, 2] - sole], 1)        # fit frame
H = P[:, 2].max()
FIT = Matrix.Rotation(math.pi, 4, "Z") @ Matrix.Translation((0, 0, sole))   # fit frame -> master frame

before = set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=game_p, bone_heuristic="BLENDER")
game = [o for o in bpy.data.objects if o not in before]
for o in game:
    if o.type == "ARMATURE":
        o.data.pose_position = "REST"  # bone-parented props: rest pose, not a clip frame
bpy.context.view_layer.update()
body = max((o for o in game if o.type == "MESH"), key=lambda o: len(o.data.vertices))
GV = world_verts(body)
s = H / (GV[:, 2].max() - GV[:, 2].min())
print("MASTER H", round(H, 3), "x", P[:, 0].min().round(3), P[:, 0].max().round(3))
print("GAME body", body.name, "s", round(s, 3))
props, spin = [], []


def right_fist(zmin, zmax):
    """His right fist (fit frame): the lowest part of the outermost +x arm in zmin..zmax, unless x,y,z is given."""
    if HAND is not None:
        return HAND
    arm = P[(P[:, 0] > P[:, 0].max() - 0.25) & (P[:, 2] > zmin) & (P[:, 2] < zmax)]
    return arm[arm[:, 2] < arm[:, 2].min() + 0.2].mean(0)


def ring_of(name, at):
    """An empty for a spinning group of carried parts (props + spin)."""
    e = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(e)
    e.location = at
    props.append(e)
    spin.append(e)
    return e


if recipe == "ostra":
    fan = next(o for o in game if o.name == "Fan")
    idx = body.vertex_groups["hand.L"].index
    glove = [v.index for v in body.data.vertices if any(g.group == idx and g.weight > 0.5 for g in v.groups)]
    gl = GV[glove]
    foot = gl[gl[:, 2] < np.percentile(gl[:, 2], 60)].mean(0) + FAN_GRIP
    xmin = P[:, 0].min()                         # his left hand: the outermost -x part above the waist
    hand = P[(P[:, 0] < xmin + 0.20) & (P[:, 2] > 1.0)].mean(0) if HAND is None else HAND
    print("HAND", hand.round(3), "fan foot (game)", foot.round(3))
    # game -z (toward the fingertips) -> up, game y -> along x, game x -> along y; a proper rotation (det +1)
    R = Matrix(((0, 1, 0, 0), (1, 0, 0, 0), (0, 0, -1, 0), (0, 0, 0, 1)))
    M = Matrix.Translation(Vector(hand) + Vector((0, 0, 0.02))) @ R @ Matrix.Scale(s, 4)
    M = M @ Matrix.Translation(-Vector(foot))
    props.append(carry(fan, M @ fan.matrix_world, "x_fan_cards"))
    axis = Vector((-0.03, 0.09, 0))                   # his body axis at the rings' heights (measured on cand_b)
    for ring in (o for o in game if o.type == "EMPTY" and o.name in ("orbit_cards", "orbit_cardsb")):
        c = ring.matrix_world.translation
        e = bpy.data.objects.new(ring.name, None)
        bpy.context.scene.collection.objects.link(e)
        e.location = axis + Vector((0, 0, c.z * s))
        for card in (o for o in game if o.parent == ring and o.type == "MESH"):
            rel = Matrix.Translation(-c) @ card.matrix_world    # world-oriented, about the ring's centre
            ob = carry(card, Matrix.Scale(s, 4) @ rel, card.name)
            ob.parent = e
        props.append(e)
        spin.append(e)
elif recipe == "breaker":
    ham = next(o for o in game if o.name == "hammer" and o.type == "MESH")
    grip = next(o for o in game if o.name == "anchor_hammer_grip").matrix_world.translation
    fist = hand = right_fist(0.0, 0.9)
    print("FIST", np.round(fist, 3), "grip (game)", np.round(grip, 3))
    M = Matrix.Translation(Vector(fist)) @ Matrix.Scale(s, 4) @ Matrix.Translation(-grip)
    HV = world_verts(ham)
    pitch = 0.0       # the game holds it level, head forward; his fist is lower, so tip the head up onto the floor
    while pitch < 30:
        T = Matrix.Translation(Vector(fist)) @ Matrix.Rotation(math.radians(pitch), 4, "X")
        Mp = T @ Matrix.Translation(-Vector(fist)) @ M
        if (HV @ np.array(Mp)[2, :3] + np.array(Mp)[2, 3]).min() >= 0:
            break
        pitch += 0.5
    print("PITCH", pitch)
    props.append(carry(ham, Mp @ ham.matrix_world, "x_hammer"))
elif recipe == "tarek":
    # the five fist shards about his right fist, the ground rings under his feet (the eye stones are in the master)
    hand = right_fist(0.6, 1.3)
    pivot = next(o for o in game if o.name == "anchor_fist_R").matrix_world.translation
    print("FIST", np.round(hand, 3), "fist_R (game)", np.round(pivot, 3))
    e = ring_of("orbit_shards", Vector(hand))
    for sh in (o for o in game if o.name.startswith("shard_") and o.type == "MESH"):
        carry(sh, Matrix.Scale(s, 4) @ Matrix.Translation(-pivot) @ sh.matrix_world, sh.name).parent = e
    feet = P[P[:, 2] < 0.1]
    rings = next(o for o in game if o.name == "ground_rings" and o.type == "MESH")
    c = rings.parent.matrix_world.translation
    e = ring_of("orbit_ground", Vector((feet[:, 0].mean(), feet[:, 1].mean(), 0)))
    M = Matrix.Scale(s, 4) @ Matrix.Translation(-Vector((c.x, c.y, 0)))
    carry(rings, M @ rings.matrix_world, rings.name).parent = e
else:
    raise SystemExit("recipe: ostra | breaker | tarek")

for k, e in enumerate(spin):          # a slow spin about his axis, the rings opposite ways (one scene clip, below)
    e.rotation_mode = "XYZ"
    for f, a in ((1, 0.0), (121, 2 * math.pi * (1 if k % 2 == 0 else -1))):
        e.rotation_euler = (0, 0, a)
        e.keyframe_insert("rotation_euler", frame=f)
    for fc in e.animation_data.action.fcurves:
        for kp in fc.keyframe_points:
            kp.interpolation = "LINEAR"
bpy.context.scene.frame_start, bpy.context.scene.frame_end = 1, 121
carrier = bpy.data.objects.new("props_fit_to_master", None)
bpy.context.scene.collection.objects.link(carrier)
carrier.matrix_world = FIT
for o in props:
    o.parent = carrier
for o in game:
    bpy.data.objects.remove(o, do_unlink=True)
for o in bpy.data.objects:          # the copies keep the game's node names (orbit_cards_0, shard_0, ...)
    if o.name[-4:-3] == "." and o.name[-3:].isdigit():
        o.name = o.name[:-4]
for o in list(bpy.data.objects):
    if o.name.startswith("Icosphere"):
        bpy.data.objects.remove(o)
bpy.context.view_layer.update()
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=out_glb, export_format="GLB", use_selection=True, export_animations=bool(spin),
                          export_animation_mode="SCENE", export_anim_scene_split_object=False,
                          export_image_format="AUTO", export_extras=False)

sc = bpy.context.scene
sc.render.engine = "BLENDER_WORKBENCH"
sc.display.shading.light = "STUDIO"
sc.display.shading.color_type = "TEXTURE"
sc.render.resolution_x, sc.render.resolution_y = 1100, 1300
sc.view_settings.view_transform = "Standard"
sc.world = bpy.data.worlds.new("w")
sc.world.color = (0.82, 0.8, 0.84)
sc.frame_set(30)
sc.render.image_settings.file_format = "JPEG"
sc.render.image_settings.quality = 92
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
sc.collection.objects.link(cam)
sc.camera = cam
cam.data.type = "ORTHO"
az = math.radians(-38 if recipe == "ostra" else 38)   # 3/4 from the prop's side (his front is +Y in the fit frame)


def shoot(ctr, dist, up, scale, path, res):
    cam.data.ortho_scale = scale
    loc = Vector(ctr) + Vector((math.sin(az) * dist, math.cos(az) * dist, up))
    cam.location = FIT @ loc
    cam.rotation_euler = ((FIT @ Vector(ctr)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)


shoot((0, 0.05, H * 0.5), 6, 1.6, H * 1.25, out_jpg, (1100, 1300))
shoot(tuple(hand), 3, 1.0, 0.7 if recipe == "ostra" else 1.1, out_jpg.replace(".jpg", "_hand.jpg"), (900, 900))
print("DONE", out_glb)
