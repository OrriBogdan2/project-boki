# Monster models (art/mobs)

A common monster (MobModels) or Blight monster (BlightModels) with a file `art/mobs/<kind>/<kind>.glb`
is drawn from that skinned model instead of its primitives. `MobGlb.dress` does the swap after the
primitives are built, so nothing else changes:

- **Animation:** the primitives' pivots (Leg<i><side>, Torso, ArmL, Head, Bulb, Puff, EarL, Crystal ...)
  stay in the tree and `mob.gd` animates them as before. The model's skeleton has one bone per pivot,
  with the same name, and `MobGlb` copies each pivot's motion onto its bone every frame. Idle, walk,
  run, windup, attack, hurt and death all play unchanged.
- **Drawn parts:** the primitives are hidden, except the glow parts in `MobGlb.KEEP` (bomber fuse
  spark, sentinel floating shards, Blight watcher lamp), which still pulse as attacks wind up.
- **Colour:** one toon material with the model's texture. Its body hue band (measured from the
  texture when it was skinned, stored in the glTF extras as `band` = [hue, brightness]) is repainted
  to the kind's colour, then to the region's colour (`BiomeRun.recolor_mats`, like a pack model's
  cloth). Greys, bone whites and cream bellies (saturation under `BAND_MIN_SAT`) keep their paint.
- **Budget:** at most 7000 triangles, one draw call (`--mob-glb-check`).

## Making one

The pipeline scripts live with the art outputs (`/home/boki/meshy/mobs-spend-1112/tools`):

1. Render the in-game monster from 4 sides (`turn.sh`), then redraw it as a painted turnaround with
   Meshy image-to-image (`mob.sh ref`). The design stays the same: body plan, legs, colours.
2. Multi-image-to-3D from that turnaround (`mob.sh gen`; 6000 triangles, 2k texture).
3. Skin it to the pivots (`mob.sh skin`, Blender `mob_skin.py`). It welds the UV seams first.
   Weights come from the nearest primitive surface, or, for the ape-like brutes, from a Meshy
   auto-rig of the same mesh with its humanoid bones mapped onto the pivots
   (`--weights-from`). The procedural pivots are exported once per kind with `_mobpivots.tscn`.
4. Judge it in game: rest from 4 sides, walk and windup, against the turnaround and the old body.
