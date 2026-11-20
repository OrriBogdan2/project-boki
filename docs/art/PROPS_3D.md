# 3D world props (art/props)

Our own world props as 3D models, made from the approved concepts (job 20261112-132007-a6). Loaded by
`PropGlb` (`scripts/match/prop_glb.gd`); checked by `--prop-glb-check` (`tools/prop_glb_check.gd`).

## Pipeline

1. **Concept**: the approved painting (`/home/boki/meshy/icons-props-1112/props/`). Effects (wind swirls,
   motes, ribbons) are painted out first (gemini edit, no Meshy credits) so Meshy doesn't model them.
2. **Meshy image-to-3D** (`meshy_task_v9.py create --pose "" --pbr off`), a few candidates each (enhance on and
   off, plus a Smart Topology remesh). Pick the one closest to the concept's shape, colour and cel look.
3. **Blender, cleanup only** (`/home/boki/meshy/props-3d-1112/scripts/cleanup.py`): join, pivot at the bottom
   centre, scale to game metres, decimate to the triangle budget, 1k JPEG texture, split into the parts the game
   animates (by face height, radius and texture colour), set each part's pivot, export glb (+Y up, front +Z).
4. **Godot**: `PropGlb.build(id, tint)` puts every surface on the toon shader with the prop's texture
   (outlined); `<id>_glow` surfaces glow unoutlined and, given a tint, draw the texture's light and shade in that
   tint. Returns null without the file or under `--prim-art`, so the caller keeps its primitive.

## The props

| id | size | tris | parts (pivot) | in game |
|---|---|---|---|---|
| `jump_pad` | 1.5 m wide, 0.5 m tall (Meshy's z x0.6: low enough to run onto, the spring still shows) | 7k | Base, Spring (bottom), Top = glow plate with chevrons (bottom centre) | `Models.jump_pad`: world pads and duel pads; chevrons point -Z (the landing) |
| `gust_fan` | 1.3 m tall | 9k | Body, Blades = glow (hub; spin about local Z) | scene only: no world fan yet |
| `updraft_vent` | 3.2 m wide (updraft r 1.6), rim 0.55 m tall | 7k | Rim, Grate, Glow (floor) | scene only: updrafts sit over the void at island edges |
| `chest` | 1.16 m wide (the sculpted chest), 1.12 m tall with its domed lid | 9k | Body, Lid (back hinge on the seam), Lock | scene only: `Models.chest` stays the sculpted chest |

Left to do: the pad compresses only through match.gd's existing plate pulse (no squash on launch); placing a
fan and ground vents needs world features that don't exist; swapping the chest needs KeyChest's padlock and
LockTag moved onto the model's Lock node. The official Khronos glTF validator wasn't run (not installed here);
the files are checked by Blender and Godot re-import and by `--prop-glb-check`.
