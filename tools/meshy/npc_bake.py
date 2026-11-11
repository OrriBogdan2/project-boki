"""A talking NPC's game GLB from Meshy's animate output (docs/art/npcs/PIPELINE.md): the clips renamed to the
NPC's poses, the painted albedo kept (down to TEX px, JPEG), the PBR normal and metal/rough maps dropped (the toon
shader draws the light), the one material named "npc-<id>".
Run: blender -b --factory-startup --python tools/meshy/npc_bake.py -- <animation_glb.glb> <out.glb> <id> <Clip=pose>...
  e.g. ... -- m3d/hob_anim/animation_glb.glb art/npcs/hob/hob.glb hob Idle=idle Stand_and_Chat=talk"""
import sys

import bpy

TEX = 1024


def main(src, out, nid, pairs):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=src)
    names = dict(p.split("=", 1) for p in pairs)
    for a in list(bpy.data.actions):
        base = a.name.split("|")[-1]
        for k, v in names.items():
            if base == k or base.startswith(k + "_") or a.name.startswith(k):
                a.name = v
                break
        else:
            bpy.data.actions.remove(a)
    for m in bpy.data.materials:
        if not m.use_nodes:
            continue
        m.name = "npc-" + nid
        nt = m.node_tree
        bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
        for sock in ("Normal", "Metallic", "Roughness"):
            for link in list(bsdf.inputs[sock].links):
                nt.links.remove(link)
        bsdf.inputs["Metallic"].default_value = 0.0
        bsdf.inputs["Roughness"].default_value = 1.0
        for _ in range(3):      # (a map's image node goes once the node it fed has gone)
            for n in list(nt.nodes):
                if n.type in ("TEX_IMAGE", "NORMAL_MAP", "SEPARATE_COLOR", "SEPRGB") and not any(o.links for o in n.outputs):
                    nt.nodes.remove(n)
        for n in nt.nodes:
            if n.type == "TEX_IMAGE" and n.image:
                n.image.scale(TEX, TEX)
                n.image.name = nid + "_albedo"
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_image_format="JPEG",
                              export_jpeg_quality=88, export_animation_mode="ACTIONS", export_yup=True)
    print("baked", out, sorted(a.name for a in bpy.data.actions))


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:]
    main(argv[0], argv[1], argv[2], argv[3:])
