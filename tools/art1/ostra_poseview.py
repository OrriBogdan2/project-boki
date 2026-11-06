"""Render clips: blender -b f.blend --python tools/art1/ostra_poseview.py -- outdir clip[,clip] [times comma | n] [view az:el:cz:size]"""
import bpy, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ostra_preview as PV
a = sys.argv[sys.argv.index("--") + 1:]
out, clips = a[0], a[1].split(",")
n = a[2] if len(a) > 2 else "5"
az, el, cz, size = [float(x) for x in (a[3] if len(a) > 3 else "335:10:1.05:2.5").split(":")]
os.makedirs(out, exist_ok=True)
sc, co, cam, so = PV.rig_scene()
for m in bpy.data.materials:
    if m.name.startswith(("glow-", "void-", "leather-face")) and m.use_nodes:
        bs = m.node_tree.nodes["Principled BSDF"]
        for nd in m.node_tree.nodes:
            if nd.type == "TEX_IMAGE":
                m.node_tree.links.new(nd.outputs[0], bs.inputs["Emission Color"])
                bs.inputs["Emission Strength"].default_value = 1.3
px = int(os.environ.get("OSTRA_PX", 300))
sc.render.resolution_x = sc.render.resolution_y = px
sc.cycles.samples = int(os.environ.get("OSTRA_SPP", 8))
PV.aim(co, cam, so, az, el, (0, 0, cz), size)
arm = bpy.data.objects["Armature"]
for c in clips:
    act = bpy.data.actions[c]
    arm.animation_data_create()
    arm.animation_data.action = act
    if act.slots:
        arm.animation_data.action_slot = act.slots[0]
    f0, f1 = act.frame_range
    ts = [float(x) for x in n.split(",") if x] if "," in n else [f0 + (f1 - f0) * i / max(int(n) - 1, 1) for i in range(int(n))]
    if "," in n:
        ts = [x * 30 for x in ts]
    for i, f in enumerate(ts):
        sc.frame_set(int(f), subframe=f - int(f))
        sc.render.filepath = "%s/%s_%02d.png" % (out, c, i)
        bpy.ops.render.render(write_still=True)
