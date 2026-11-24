"""matnames.py IN.glb OUT.glb : strip Blender's '.001' duplicate suffix from material names (graft import clash), so
warden_look's slot/tag lookups see the live names again. Names only."""

import bpy, sys

A = sys.argv[sys.argv.index("--") + 1 :]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=A[0])
for m in list(bpy.data.materials):
    if m.name[-4:] == ".001":
        base = m.name[:-4]
        o = bpy.data.materials.get(base)
        if o and o.users == 0:
            bpy.data.materials.remove(o)
        if not bpy.data.materials.get(base):
            m.name = base
print("MATS", sorted(m.name for m in bpy.data.materials if m.users))
bpy.ops.export_scene.gltf(
    filepath=A[1],
    export_format="GLB",
    export_animation_mode="ACTIONS",
    export_apply=False,
    export_skins=True,
    export_morph=False,
    export_image_format="JPEG",
)
