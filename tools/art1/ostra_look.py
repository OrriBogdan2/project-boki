"""Preview renders from the .blend: blender -b f.blend --python tools/art1/ostra_look.py -- out_prefix [views]
views: comma list of name:az:el:cz:size (px via OSTRA_PX). Defaults to the model sheet."""
import bpy, math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ostra_preview as PV

a = sys.argv[sys.argv.index("--") + 1:]
out = a[0]
views = a[1] if len(a) > 1 else "front:0:6:1.0:2.5,q34:325:8:1.0:2.5,side:90:6:1.0:2.5,back:180:6:1.0:2.5,head:0:3:1.66:0.9,box:325:22:0.42:1.0,top:0:62:1.0:2.5"
sc, co, cam, so = PV.rig_scene()
for m in bpy.data.materials:            # (the glow slots glow in the game; here, an emission preview)
    if m.name.startswith(("glow-", "void-", "leather-face")) and m.use_nodes:
        bs = m.node_tree.nodes["Principled BSDF"]
        for n in m.node_tree.nodes:
            if n.type == "TEX_IMAGE":
                m.node_tree.links.new(n.outputs[0], bs.inputs["Emission Color"])
                bs.inputs["Emission Strength"].default_value = 1.3
px = int(os.environ.get("OSTRA_PX", 520))
sc.render.resolution_x = sc.render.resolution_y = px
os.makedirs(os.path.dirname(out), exist_ok=True)
for v in views.split(","):
    nm, az, el, cz, size = v.split(":")
    PV.aim(co, cam, so, float(az), float(el), (0, 0, float(cz)), float(size))
    sc.render.filepath = "%s_%s.png" % (out, nm)
    bpy.ops.render.render(write_still=True)
