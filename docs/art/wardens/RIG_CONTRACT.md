# Warden .glb rig contract

What a Blender-built Warden (`art/wardens/<name>/<name>.glb`, named as its art: `vex`, `bjorn`, `pin`...;
`WardenGlb.ART`; OWNER INBOX 2026-11-03 16:30) must carry so the
game can drive it with the existing animation (HunterAnim and the kit moves in `scripts/match/kmoves_*.gd`),
the kits' effects can find their anchors, and gameplay stays per class. The loader is `scripts/heroes/warden_glb.gd`
(`WardenGlb`); `--warden-glb-check` asserts the contract's tables and the fallback.

## How the game uses it
Models.hunter still builds the procedural hunter: the node rig HunterAnim poses, the weapon, the glider, the hit
ring and the MantleLook sizes. When the Warden's .glb exists and the player hasn't set it to procedural
(Settings > Video > Warden models, per Warden), `WardenGlb.dress` hides that hunter's body meshes, adds the .glb
and every frame puts each bone where its rig node has moved from its rest in the Warden's neutral look
(`WardenGlb.BONES`, `WardenGlb.retarget`), so the kit moves retarget once for every Warden and MantleLook's
sliders reshape the 3D model too. The .glb never needs to know about the animation code: it needs the bones
below, in this rest pose, at this scale. A .glb whose armature doesn't match (`WardenSkeleton.mismatches`: names,
parents, each bone within 1 cm of its rig node) is refused and the procedural model stays: the fallback.
`WardenSkeleton.build` makes this armature from any Warden's rig. Shared are the bone names and layout only
(owner, 21:40): the bones sit where that Warden's own rig puts them, and every Warden keeps its own motion
(idle, run, stance, dash and kit moves come from HunterAnim and its own KMoves; the loader only copies them).
`--warden-glb-check` asserts that two Wardens' idle and run joint angles differ.

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

### Variant bones (a Warden's own extra bones)
A Warden may carry extra bones of its own, declared in `WardenGlb.EXTRA` (`<archetype>: {bone: parent}`), on top of
the table above. For that Warden they are part of its contract: `WardenSkeleton.mismatches` refuses a .glb that lacks
one or hangs it on another parent. They are skinned like the rest and follow their parent bone through the retarget
(the loader never writes them), and only that Warden's kit poses them, on their rest, with
`WardenGlb.pose_extra(model, bone, rot, scale)` (`rot` about the bone's head, its axis in model space as the model
rests; a zero scale hides what rides the bone). On a procedural model the call does nothing.
- **Grimble** (`dredge`, art id unchanged): declared in content/rules/warden_anim/dredge.json (`extra_bones`): `hook`, `gun`, `hoard`, `ball`, face and hand bones. See art/wardens/dredge/IMPORT.md.
- **Sable** (`thief`, art `sable`): declared in content/rules/warden_anim/sable.json: face bones, `x_breath` (the rib cage's swell) and `x_twirl` (the right pistol, spun round its breech; the blade anchors ride it).

The kit moves (`kmoves_*.gd`) only key channels on these nodes (`p` pitch, `y` yaw, `r` roll, `lift`, `sq`
squash, `fx`/`fy`/`fz` whole-body turns, `legs` [hip, knee, hip, knee], `fl`/`fr` free-hand targets, `gp` weapon
pitch, `blade`/`wa`/`wo` the weapon's swing), so a .glb that follows these bones gets every move for free.

### Spring chains (hair, braids, tails that swing)
Bones named `spring_<name>_<i>` form a chain: the first is a child of a contract bone (a braid hangs from `head`),
each is the next one's parent, and the last is the tip (no skin of its own; its head is the chain's end). The
loader (`WardenGlb.Springs`, run by Sync after the contract bones) swings every chain as a damped rope in world
space, pulled back toward the shape it has riding its parent rigidly (firmer at the root than at the tip), so it
trails behind a run, swings out of a turn and settles. Nothing in the kit moves or the checks depends on them.
`tools/meshy/warden_parts.py` builds Vex r3b's two braids this way; `fit_warden.py`'s `hair_springs` puts a scan's own
fused hair on such chains (Tarek's locs: the vertices of the hair slot in a box handed from the head to the chain by
how far down it they hang).

### Orbits (props that circle a bone)
An empty named `orbit_<name>` parented to a bone, its rest upright (identity rotation in the model frame), carries
unskinned props (Tarek's three seeing-stones round his head, each built facing out from the orbit's centre, its
iris out and its plain back in). `WardenGlb.Orbits` (run by Sync) turns the empty round its own up axis
(`ORBIT_HZ`) and bobs each prop on its own phase, so the orbit is data in the loader, never baked.
`tools/meshy/warden_parts.py` `orbit_props()` builds them (fit spec `orbits`). They count as skinned for
`--warden-glb-check` and stay out of `--warden-model-check`'s height.

### Hovering bodies
A body with no feet (Motley on his box, id `ostra`) is built with its ground at the box's foot; the rig's own hover (`KMovesStone.hover`, which lifts
`Rig`, so the `root` bone) floats it a hand's width over the shadow. With hand-keyed clips, `"rig_root": true` in its content/rules/warden_anim file keeps
the `root` bone on `Rig` under them, so the hover and the kit's lifts carry on. Its legs are unskinned.

### Design variants
Another design of the same Warden can sit beside the shipped model while the owner compares them:
`art/wardens/<art>_<tag>/<art>_<tag>.glb` (e.g. `vex_r3b`), built on the same rig. `--warden-variant=vex_r3b`
picks it for the session (comma-separated for several), and a Settings `warden_models` value of `vex_r3b` for
that Warden picks it in the save; with neither, or with the file missing, the Warden's own `<art>.glb` loads.
Whichever design the owner picks ships as `<art>/<art>.glb`.

## Nodes the game keeps from the procedural rig (do not model these into the body)
- `Rig/Torso/Aim/Gun` and its children: the held weapon (`Models.gun_parts`, `PinBjornWeapons`), its `Muzzle`
  (shots leave from it), `Mag` (reload anim), Bjorn's `Hammer` pivot (meta `hammer_pivot`; BjornFx finds the
  head at (0, 0, -0.62) in its space), the twin blades' `Offhand`. A .glb may carry its weapon as a separate,
  unskinned mesh named `weapon`, modelled in the Gun node's space (forward -Z, the Muzzle where shots leave),
  with its magazine as a child `weapon_mag`: the loader puts it under `Gun`, hides the procedural weapon and
  makes the magazine the Gun's `Mag` (Vex does). An empty `weapon_muzzle` under the weapon, on its mouth, moves the
  Gun's `Muzzle` there, for a weapon shorter or longer than the procedural one (Dredge's horn).
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
so hits flash, team colours and MantleLook tints work. Name each glTF material after its slot (or "<slot>-<texture>" where a model has several textures); the loader
makes one hero-toon ShaderMaterial per slot, with the baked atlas as the albedo texture and the baked AO in
the vertex colour (`vertex_ao`):

| slot | shader surface | tinted by |
|---|---|---|
| `skin` | 4 (skin) | the player's skin pick (MantleLook `skin_col`) |
| `hair` | 5 (hair, fur) | the hair pick (`hair_col`) |
| `cloth` | 1 (cloth) | the outfit pick (`outfit_col`, within the Warden's range) |
| `leather` | 2 | — |
| `metal` | 3 (metal: cool shadows, gloss) | — |
| `brass` | 3 (as metal) | — (metal split off by its colour, so the model's look can lift it alone at the match camera: Vex's bronze) |
| `fur` | 5 | — |
| `eyes` | — (unshaded iris) | the eye pick (`eye_col`) |
| `team` | 1 | the team colour (keep it on one strong shape: a cuff, a cap, the stem's band) |
| `glow` | emissive | — (Bjorn's crack, Zedran's fuller) |
| `flame` | — (shaders/hero_flame.gdshader: strips of fire, raw UV, unlit, no atlas; `flame-liquid`: a tank's fuel; `warden_look` "slots" "flame-<tag>" sets its parameters) | — (Cinder's hair, tail and jets) |
| `void` | — (shaders/hero_void.gdshader: a drifting starfield over the paint, unlit) | — (Ostra's coat tears; `void-wisp` also fades out toward its tip: `WardenGlb.SOFT_TAGS`) |

A material with an emissive texture (glTF `emissiveTexture`) gets the toon shader's emission layer (`use_emit`,
`WardenGlb.EMIT`, crackling by `EMIT_FLICKER`): Sparkle's veins, Tarek's bracer cracks. The fit's `split` parts are
pieces cut off the body as their own skinned mesh on one "<slot>-<name>" material (Tarek's `bracers`, Ostra's
`mask`), with such a layer painted from the atlas (`emit`: the dark cracks between plates, or a colour range).
With a `model_glow.core` colour in the archetype JSON the layer is a mask drawn in that colour (`emit_tint`), its
texels' paint too, so a Warden's glow switches without a rebake (Sparkle's pink scar, charm, piping and veins: the
fit's `emit_art` projects that layer from the art's neon onto the body's own materials).
A .glb whose weapon is part of the body carries an empty `weapon` node (fit spec `weapon_empty`): the loader
hides the procedural weapon and the Gun node and its Muzzle stay (Tarek's fists).

A **flat-painted** model (hand-modelled, one colour a material and no atlas: Dredge) names its materials the same way
("<slot>-<what>": `metal-brass`, `leather-tar`); the loader shades each in its slot with its own base colour and the
procedural heroes' clean painted settings (little brushwork, the cool shadow and warm light tints), ink shell on.

Every material must end up in the root's `mats` meta (the loader does it) so hit flashes and mutations reach it.
A model's own shading (content/rules/warden_look.json, keyed by its art name; `WardenGlb.look`) goes on last:
`painted` sets hero-toon parameters on all of its surfaces, `slots` per slot, e.g. Vex's skin and gunmetal
with less top light and rim than the shared painted look, her lens and collar seams brighter on `glow`.
Materials tagged `braid` ("hair-braid") take the ink line on the hair slot (clean geometry, no ragged strands).
`halos` in the same file hang a glow disc of a constant size on screen on an anchor empty of the model (Vex:
`anchor_lens`, exported by the fit with its lens): a lens a pixel wide at the match camera still reads; the disc is
outside the .glb (a RemoteTransform3D on the anchor carries it), so the skin, bounds and slot checks never see it.
A painted (Meshy) atlas is shaded by `WardenGlb.PAINTED` (soft, near-white toon light, a light rim, brighter at
the match camera) with a thin ink shell that never grows past the fit's ink room, the vertex colour's alpha.
The loader puts each material's base-colour texture (the atlas) on `hero_toon.gdshader`'s `albedo_tex`
(`use_tex`), with `albedo` as a tint: the player's skin, hair and eye picks move the `skin`, `hair` and `eyes`
slots at most ±35% per channel from the Warden's own colours. Bone names may come through as `upper_arm_L`
(glTF tools swap the dot); the loader takes either.
The armature and its meshes sit at the .glb's origin (no offset on the scene root), so skeleton space is model space.

## Budget and checks
- **At most 15k triangles per Warden, weapon included** (owner item 94; `--warden-glb-check` holds it). A Meshy
  bake (30–50k) goes through `tools/blender/decimate_warden.py` (one collapse ratio for every part over 400
  triangles; the armature, rest pose, anchors, weights and materials are untouched). The import generates
  LODs (`meshes/generate_lods=true`), which the quality preset's LOD threshold uses.
- Textures: at most 2048² (`process/size_limit=2048`), VRAM-compressed (`compress/mode=2`, high quality:
  BPTC on desktop), mipmapped; one atlas per Warden where possible; no more than 8 material slots.
  A hand-made model may be flat-painted instead (one colour a material, no atlas) or use a 2048² atlas with
  its ageing painted in (Dredge); slots, not materials, count (Dredge's ten materials use four).
- `--warden-glb-check`: the bone table covers every part HunterAnim binds; a Warden without a .glb builds the
  procedural model (the fallback); a .glb present loads with the contract armature, every kit move of every
  table retargets exactly and each keyed channel moves its bones, the anchors ride bone attachments, every
  surface is on the hero toon shader with the atlas, the hit ring is unchanged, the budget holds, and the
  setting turns it procedural and back.
- The Blender builds: `godot --headless -- --warden-rig-json --warden=<id>` writes the armature and landmarks
  (art/wardens/src/<name>_rig.json); `blender -b --factory-startup --python tools/blender/<name>.py` builds,
  bakes and exports (shared helpers in tools/blender/warden_kit.py; Vex first, see art/wardens/vex/IMPORT.md).
- `--warden-model-check` then applies as for the procedural Wardens: anchors, every keyed move, hitbox, height
  on the sheet's scale, MantleLook extremes, the portrait.
