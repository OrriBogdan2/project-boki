# Hunter rig standard (locked, RIGFIX 2026-11-04)

One skeleton, one set of attachment points and one set of scale rules for all 12 Hunters (Vex, Albert, Neve,
Kael, Cinder, Tenzo, Sparkle, Grimble, Meeko, Sable, Lace, Motley). Any rebuild of a Hunter's model (the face and texture
accuracy pass included) MUST keep everything below, so the animation work (HunterAnim and the kit moves) carries
over to the new model unchanged. `--rig-standard-check` asserts it; `docs/art/wardens/RIG_CONTRACT.md` has the
full bone table and loader details.

## Skeleton
- The contract armature, same names and parents on every Hunter: `root`, `hips`, `head`, `upper_arm.L/R`,
  `forearm.L/R`, `hand.L/R`, `thigh.L/R`, `shin.L/R`, `pauldron.L/R`, `skirt`; optional `cape`, `scarf`, `tail`,
  `wings`. Each bone's head sits on its rig node (within 1 cm: `WardenSkeleton.mismatches`).
- Extra bones are allowed only as declared variants (`WardenGlb.EXTRA`: Grimble's claw, eye, winch, rope, hook,
  pool) or as `spring_*` chains (hair, braids, locs, Motley's wisp) and `orbit_*` empties.
- Every limb vertex is skinned to the contract bones. Joints: knees and elbows bend only about their own bone
  (no weights from the far side of a joint), so a crouch or a flip never twists or collapses the mesh.

## Rest pose
Standing, facing -Z, +Y up, feet on y = 0, arms hanging straight down from the shoulders (not a T-pose), the hands
at the rig's `Hand` nodes. Apply all transforms before export.

## Scale
- The mesh is built as a medium hunter (head top about 1.55 m); the game applies class, archetype `body.size` and
  the MantleLook sliders on the root. Never bake a Hunter's own height in.
- Resulting heights against a medium hunter are owner decisions, asserted by `--warden-model-check`: Mossy 1.5x
  (his hitbox stays the heavy class's 0.50 m), Kael body 1.06, Motley body 0.9.
- The hit ring and radius are the class's, never the model's.

## Attachment points
| point | node | how it is placed |
|---|---|---|
| weapon | an unskinned mesh `weapon` in the .glb | modelled in the Gun node's space, its origin at the trigger hand's grip (`HunterAnim.HOLDS` "gr"); the loader seats it under `Gun` (under the `hammer_pivot` for a hammer). Size: warden_look `weapon_scale`; shift: `weapon_offset` [x, y, z] m |
| muzzle | empty `weapon_muzzle` under `weapon` | on the weapon's mouth: the Gun's `Muzzle` moves there |
| magazine | `weapon_mag` / `weapon_spin` | child of `weapon`; the reload and the spinning barrels |
| offhand | child `weapon_offhand` | a twin weapon's second piece, left of x = -0.04, handed to the left hand |
| shield | mesh `shield` | modelled in the Shield node's space on `Hand.L` (Mossy) |
| anchors | empties `anchor_head_top`, `anchor_chest`, plus a Hunter's own (`anchor_*`) | children of their bone; kits find them with `WardenGlb.anchor` |
| FX anchors | optional empties a Hero's looks read (`content/vfx/<arch>.json` "anchors"; Kael: `anchor_blade_tip`, `anchor_blade_mid`, under `weapon`; `anchor_chain_hand`, `anchor_feet`, on their bones; Lace: `anchor_nock`, `anchor_bow_root`, `weapon_muzzle`, `halo_bow_top`, `halo_bow_low`) | looks fall back to the Gun's space, then the body, without them (docs/HERO_VFX.md) |

The weapon is part of the Hunter's design: it stays seated in the hand (its bounds hold the grip within 6 cm) and
follows the hand in every state. `HunterAnim._weapon_to_hand` pulls a weapon whose grip the arm cannot reach (a flip,
a long lunge) to the hand, so it never detaches. Moves that deliberately free a hand (`fl`/`fr` keys: throws,
palm casts) are exempt.

Item 76b (ART-1): a Hero rebuilt with `skinned_weapon` (docs/art/wardens/CLIPS.md) carries no `weapon` node: its weapon is
skinned to its bones in the .glb, its FX points are empties on them (`weapon_muzzle`, the blade's root), and the Gun is
an invisible reference kept on the blade. `body.shoulder` in the archetype moves the arm pivots in or out (keep the
Hero's own width there, never by `body.chest`). A Hero's variant bones can sit in its data file (`extra_bones`).

## The check
`--rig-standard-check` (all 12): the armature matches the standard; the attachment points exist; the rest pose has
the arms hanging; the weapon's bounds hold the grip; and in the run, both casts and every kit move that keeps a hand
on the weapon (each key time and the midpoints), the trigger hand stays within 9 cm of the grip.
`--rig-shots --shots-dir=<dir>` renders one contact sheet per Hunter (idle, walk, run, hit and kit moves, match
zoom above, close below) for the visual audit.
