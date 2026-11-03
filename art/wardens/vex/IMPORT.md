# Vex: INTERIM mesh (replace with the Blender pass)

`vex.glb` is **not** the production model. Blender wasn't on the build box, so this one is generated in Godot by
`godot --headless -- --warden-build --warden=gunslinger` (`tools/warden_build.gd`, Vex's numbers in
`tools/warden_build_vex.gd`) from her turnaround sheet `docs/art/gen/wardens/venatrix_turnaround.png`, and
written with GLTFDocument. It exists so the game's .glb path (loader, armature, retargeted moves, anchors,
toon atlas, the Warden models setting) runs end to end on a real file. The Blender export replaces this file
under the same name; nothing else changes.

## What it is
- Tubes of rings: widths from the sheet's front view, depth and lean from its side view, rows mapped onto the
  rig's landmarks (soles, knees, hips, neck, crown). A domed shoulder plate, a ribbon for the scarf's tail.
  About 13.4k triangles, 6 toon slots (skin, hair, cloth, leather, metal, glow).
- Painted by projecting the sheet's front, back and side views onto the faces: one 1024 atlas (the figure at
  0.65 scale, her head at full size). Each face's slot is the nearest painted colour's.
- Skinned to the contract armature built from Vex's own rig (`WardenSkeleton`), rest pose as Models.hunter
  builds it. Anchors: `anchor_head_top` (head), `anchor_chest` (hips).
- The sheet draws the mechanical arm and the shoulder plate on her right; her Warden block
  (`docs/art/gen/index.md`) and the splash put them on her **left**. The body is taken mirrored to fix that;
  the head is not, so the mechanical eye stays on her right.

## What the Blender pass must add
- Real topology: a sculpted face (the projected face has seams at the cheeks and low resolution), hands with
  fingers, the beret as its own shape, boots with soles and toes, the plate carrier's pouches, bandolier and
  dog tags as geometry, the braid.
- Separate hard-surface pieces for the mechanical arm (pistons, cables, brass joints) and the plate (a real
  edge bevel), the prayer beads, scripture strips with wax seals (on the plate, belt and rifle).
- A painted atlas baked from the model (AO, edge wear, rim), not the sheet projected; the eye sigil (an open
  eye in a teardrop) painted clean.
- Her rifle as `weapon` (the long ember rifle with glowing vents), once the loader takes a .glb weapon; the
  procedural rifle is held until then.
- Proper skin weights at the shoulders and hips (these are blended over short spans by height).
