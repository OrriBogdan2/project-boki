"""Preview renders from the .blend: blender -b f.blend --python tools/art1/ostra_look.py -- out_prefix [views]
views: comma list of name:az:el:cz:size (px via OSTRA_PX). Defaults to the model sheet."""
import bpy, math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ostra_preview as PV

a = sys.argv[sys.argv.index("--") + 1:]
out = a[0]
views = a[1] if len(a) > 1 else "front:0:6:1.05:2.3,q34:325:8:1.05:2.3,side:270:6:1.05:2.3,back:180:6:1.05:2.3,head:0:3:1.66:0.8,head34:320:6:1.66:0.8,top:0:58:1.0:2.4"
sc, co, cam, so = PV.rig_scene()
for m in bpy.data.materials:            # (the glow slots glow in the game; here, an emission preview)
    if m.name.startswith(("glow-", "void-")) and m.use_nodes:
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
