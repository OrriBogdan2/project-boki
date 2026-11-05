"""A Hunter's .glb cut down to the game's triangle budget (owner item 94), in Blender 4.5:

  ~/tools/blender-4.5.15-linux-x64/blender -b --factory-startup --python tools/blender/decimate_warden.py -- \
      art/wardens/vex/vex.glb [--tris=14000] [--out=path.glb] [--keep=Mane,ManeVolume]

Every skinned or static mesh is collapse-decimated by one shared ratio (target / current triangles), so the
small parts (weapon, braids, face decal) keep their share; meshes under KEEP_TRIS, and the ones named in
--keep (hair cards that break when collapsed: Kael's mane turned white), are left alone. The ratio never goes
under MIN_RATIO, so a model whose kept parts already fill the budget ends over it (WardenGlb check: TRIS_OVER). The armature,
bone names and rest pose, the anchors and sockets, materials, UVs and vertex weights are untouched (docs/
RIG_STANDARD.md: the rig must not change). Prints the before / after triangles per mesh.
"""
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import warden_kit as K  # noqa: E402

KEEP_TRIS = 400        # a mesh this small (an eye plate, a lens, a bolt) isn't worth cutting
DEFAULT_TRIS = 14000   # the Hunter budget: 10-15k triangles
MIN_RATIO = 0.25       # below this a body's face and hands fall apart


def _ink_back():
    """The ink room lives in COLOR_0's alpha (fit_warden.ink_room, outline.gdshader ink_mask). The importer wires
    COLOR_0 into each material (texture x Color Attribute), and the exporter then writes it back without alpha
    (every line at full width: Kael's mane drowned in ink). Unwired, as fit_warden leaves it, the active colour
    goes out whole."""
    for mat in bpy.data.materials:
        nt = mat.node_tree
        if nt is None:
            continue
        for vc in [n for n in nt.nodes if n.type == "VERTEX_COLOR"]:
            for mix in [lk.to_node for lk in vc.outputs[0].links if lk.to_node.type == "MIX"]:
                tex = next((lk.from_socket for i in mix.inputs if i.name == "A" for lk in i.links), None)
                for lk in [lk for o in mix.outputs for lk in o.links]:
                    if tex is not None:
                        nt.links.new(tex, lk.to_socket)
                nt.nodes.remove(mix)
            nt.nodes.remove(vc)


def main():
    a = sys.argv[sys.argv.index("--") + 1:]
    src = a[0]
    target = DEFAULT_TRIS
    out = src
    keep = set()
    for x in a[1:]:
        if x.startswith("--keep="):
            keep = set(x[7:].split(","))
        if x.startswith("--tris="):
            target = int(x[7:])
        if x.startswith("--out="):
            out = x[6:]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=src)
    objs = list(bpy.context.scene.objects)
    meshes = [o for o in objs if o.type == "MESH"]
    before = {o.name: K.tris([o]) for o in meshes}
    total = sum(before.values())
    small = sum(n for k, n in before.items() if n < KEEP_TRIS or k in keep)
    ratio = min(1.0, max(MIN_RATIO, (target - small) / max(1, total - small)))
    print("DECIMATE %s: %d tris, target %d, ratio %.3f" % (src, total, target, ratio))
    if ratio < 0.999:
        for o in meshes:
            if before[o.name] < KEEP_TRIS or o.name in keep:
                continue
            bpy.context.view_layer.objects.active = o
            md = o.modifiers.new("decimate", "DECIMATE")
            md.decimate_type = "COLLAPSE"
            md.ratio = ratio
            md.use_collapse_triangulate = True
            # (the armature modifier stays first: the decimate works on the rest-pose mesh)
            with bpy.context.temp_override(object=o, active_object=o):
                bpy.ops.object.modifier_apply(modifier=md.name)
    for o in meshes:
        print("DECIMATE   %-28s %6d -> %6d" % (o.name, before[o.name], K.tris([o])))
    print("DECIMATE total %d -> %d" % (total, K.tris(meshes)))
    # the toon shader's ink room rides on COLOR_0 (fit_warden): it goes back out when the model has it
    _ink_back()
    K.export(out, objs, colors=any(len(o.data.color_attributes) > 0 for o in meshes))


main()
