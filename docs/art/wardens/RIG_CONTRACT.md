# Warden .glb rig contract

What a Blender-built Warden (`art/wardens/<id>/<id>.glb`, OWNER INBOX 2026-11-03 16:30) must carry so the
game can drive it with the existing animation (HunterAnim and the kit moves in `scripts/match/kmoves_*.gd`),
the kits' effects can find their anchors, and gameplay stays per class. The loader is `scripts/heroes/warden_glb.gd`
(`WardenGlb`); `--warden-glb-check` asserts the contract's tables and the fallback.

## How the game uses it
Models.hunter still builds the procedural hunter: the node rig HunterAnim poses, the weapon, the glider, the hit
ring and the MantleLook sizes. When `art/wardens/<id>/<id>.glb` exists, `WardenGlb.dress` hides that hunter's
body meshes, adds the .glb under `Rig` and every frame copies each rig node's pose onto the bone mapped to it
(`WardenGlb.BONES`). So the .glb never needs to know about the animation code: it needs the bones below, in this
rest pose, at this scale. With no file the procedural model is used unchanged (the fallback).

## Scale, orientation, rest pose
- Units are metres at **class-neutral size**: build the Warden as a medium hunter whose head top is ~1.55 m
  (`--warden-model-check` prints the reference). The game applies the class, archetype (`body.size` in
  `content/archetypes/<id>.json`) and MantleLook height on the root, so never bake the hero's own height in.
- Up is +Y, the hunter faces **-Z** (Godot forward), its right hand is +X. Feet on Y = 0, centred on the origin.
  In Blender (Z up) model the Warden facing **+Y**, its back to the default front view; the glTF exporter's
  +Y-up conversion (Blender (x, y, z) → glTF (x, z, -y)) turns that into -Z.
- Rest pose: standing, arms hanging at the sides (not a T-pose), the hands' rest exactly at the procedural
  `Hand` positions below so the grips line up. Apply all transforms before export.
- Rig node positions in the neutral rig (rig space, metres, before the root scale): hips (Torso) 0.42 up;
  shoulders (ArmLPivot / ArmRPivot) at x ∓0.215 × chest width, 0.5 above the hips; elbow 0.21 below the
  shoulder, hand 0.235 below the elbow; neck (HeadPivot) 0.68 above the hips, the head's middle 0.18 above
  that; legs hang from x ∓0.11 × build, 0.44 up; knee 0.2 below the hip; sole 0.245 below the knee
  (HunterAnim THIGH / SHIN / UPPER / FORE). A Warden's own proportions come from `body.head`, `body.legs`,
  `body.neck` in its archetype JSON, which scale these nodes; the mesh is skinned to them as built.

## Bones (armature → rig node HunterAnim poses)
One armature, these bone names exactly (more bones are fine: cloth, hair, beard, they follow their parent).
Each bone's head sits on its rig node's origin, Y along the limb.

| bone | rig node (path under the model root) | what moves it |
|---|---|---|
| `root` | `Rig` | body lean, squash, dives, the downed fall |
| `hips` | `Rig/Torso` | the torso's twist, bob and lean; everything above hangs on it |
| `head` | `Rig/Torso/HeadPivot` | look, nod, emotes; the `head`, `jaw` sliders scale it |
| `upper_arm.L` / `.R` | `Rig/Torso/ArmLPivot` / `ArmRPivot` | arm IK (hands on grips, free hands, `fl`/`fr` keys) |
| `forearm.L` / `.R` | `.../ArmLPivot/Elbow` / `ArmRPivot/Elbow` | elbow bend |
| `hand.L` / `.R` | `.../Elbow/Hand` | the hand (kits read its world position: `ArchKit.hand_pos`) |
| `thigh.L` / `.R` | `Rig/Legs/LegL` / `LegR` | stride, stance width, the `legs` key channel |
| `shin.L` / `.R` | `Rig/Legs/LegL/Knee` / `LegR/Knee` | knee bend |
| `pauldron.L` / `.R` | `Rig/Torso/PauldronL` / `PauldronR` | turn part of the way with the arm |
| `skirt` | `Rig/Torso/Skirt` | sways with the stride (coat skirts, kilts, tunics) |
| `cape` | `Rig/Torso/Cape` (optional) | cloak / cape swing |
| `scarf` | `Rig/Torso/Scarf` (optional) | streaming tails |
| `tail` | `Rig/Torso/Tail` (optional) | a tail (Cinder, Moosh Moosh) |
| `wings` | `Rig/Torso/Wings` (optional) | wings |

The kit moves (`kmoves_*.gd`) only key channels on these nodes (`p` pitch, `y` yaw, `r` roll, `lift`, `sq`
squash, `fx`/`fy`/`fz` whole-body turns, `legs` [hip, knee, hip, knee], `fl`/`fr` free-hand targets, `gp` weapon
pitch, `blade`/`wa`/`wo` the weapon's swing), so a .glb that follows these bones gets every move for free.

## Nodes the game keeps from the procedural rig (do not model these into the body)
- `Rig/Torso/Aim/Gun` and its children: the held weapon (`Models.gun_parts`, `PinBjornWeapons`), its `Muzzle`
  (shots leave from it), `Mag` (reload anim), Bjorn's `Hammer` pivot (meta `hammer_pivot`; BjornFx finds the
  head at (0, 0, -0.62) in its space), the twin blades' `Offhand`. A weapon may later come from the .glb as a
  separate mesh named `weapon`, parented to `Gun` by the loader; until then the procedural weapon stays.
- `Rig/Torso/ArmLPivot/Elbow/Hand/Shield`: Bjorn's prow rides his left hand.
- `Rig/Torso/Glider` (the paraglider; `meta skin`), `Rig/Torso/Shoulder` (a Boki's perch), `Rig/Torso/Halo`,
  `Rig/Torso/Focus`, `TeamRing` (the hit ring), and the root metas `cls`, `arch`, `race`, `wid`, `hip_y`, `mats`.
- Portraits frame the head at `HeadPivot` + (0, 0.18, 0) (`Portraits.head_at`): keep the head's middle there.

## Anchor empties to export
Empties (glTF nodes without mesh) parented to the bone, named exactly, for effects that should start on the
model rather than at a fixed offset. None is required today (kits use the hand bones, the Muzzle and the
Hammer pivot); export these so FX can move onto them without another export:
- `anchor_head_top` (bone `head`): nameplate, overhead tells (Bjorn's Guard pips, Pin's glint).
- `anchor_chest` (bone `hips`, at chest height): hit sparks, buffs.
- `anchor_weapon_tip` (on the weapon mesh, if exported): trails.
- Per hero: Bjorn `anchor_prow_crack` (the prow's glow), Zedran `anchor_fuller` (the blade's heat), Pin
  `anchor_nock` (the arrow on the string).

## Hitbox
Never in the .glb. The hit radius is the class's (`Arch.hit_r`: light 0.35, medium 0.40, heavy 0.50, Pin
0.37) and `TeamRing` shows it whatever the model's size; MantleLook sliders never change it
(`--warden-model-check`, `--mantle-look-check`).

## Materials (toon slots)
The game re-shades every surface with its toon shader (`shaders/hero_toon.gdshader` via `Models.hero_look`),
so hits flash, team colours and MantleLook tints work. Name each glTF material after its slot; the loader
makes one hero-toon ShaderMaterial per slot, with the baked atlas as the albedo texture and the baked AO in
the vertex colour (`vertex_ao`):

| slot | shader surface | tinted by |
|---|---|---|
| `skin` | 4 (skin) | the player's skin pick (MantleLook `skin_col`) |
| `hair` | 5 (hair, fur) | the hair pick (`hair_col`) |
| `cloth` | 1 (cloth) | the outfit pick (`outfit_col`, within the Warden's range) |
| `leather` | 2 | — |
| `metal` | 3 (metal: cool shadows, gloss) | — |
| `fur` | 5 | — |
| `eyes` | — (unshaded iris) | the eye pick (`eye_col`) |
| `team` | 1 | the team colour (keep it on one strong shape: a cuff, a cap, the stem's band) |
| `glow` | emissive | — (Bjorn's crack, Zedran's fuller) |

Every material must end up in the root's `mats` meta (the loader does it) so hit flashes and mutations reach it.
The toon shader has no albedo texture input yet: the loader stub shades each slot with the glTF material's base
colour. Adding the atlas (a `albedo_tex` uniform on `hero_toon.gdshader`, sampled into `albedo`) comes with the
first real .glb.
The armature and its meshes sit at the .glb's origin (no offset on the scene root), so skeleton space is model space.

## Budget and checks
- About 8–15k triangles per Warden, one 1024² atlas; no more than 8 material slots.
- `--warden-glb-check`: the bone table covers every part HunterAnim binds; a Warden without a .glb builds the
  procedural model (the fallback); a .glb present is loaded, its bones all found, and the body meshes hidden.
- `--warden-model-check` then applies as for the procedural Wardens: anchors, every keyed move, hitbox, height
  on the sheet's scale, MantleLook extremes, the portrait.
