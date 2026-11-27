## Match Hunters drawn at the reference's height, one size each (`body.match_k`, 11-27)

Owner rule: the reference game is right on every metric unless proven otherwise. A global bump (+10%) left 9 of 13
Hunters more than 10% off the reference on screen, so every archetype now carries its own drawn size:
`content/archetypes/<id>.json` `body.match_k` (default 1; `Arch.match_k`) multiplies `Hunter.VIS_SCALE` (1.12). Gil
has none: the owner made him different on purpose. Visual only: hit radius, hurtbox height, body collision, speeds
and ranges keep their size (the reference's own hurtbox is one shared 0.43 m x 1.76 m shape whatever the model).

Method: crown (top of the skull, hair, horns, ears and props left out; `--hunter-size-sheet`) over the feet in metres
at the match camera, against the reference model's height. The reference only gives the unposed model height with
its weapons in, no skull height: where a weapon or hat stands above its head the true skull is lower than that number,
so the scale is an upper bound there. `match_k` = reference height / our crown height at k = 1.

Camera: pitch 66 deg both sides; the reference lens is 59 deg horizontal (35.3 vertical at 16:9), arm 30.2 m at its
widest; ours is 32 deg vertical at 23 m x 1.4572 = 33.5 m, 34.2 m of ground across on both sides. Same px per m, so
metres match on screen too; nothing to change.

What follows a Hunter's size (all read `Arch.match_k`): overhead and hover plates and their anchors (`Hud._head`,
`HunterZone.rect_of`, the `CamRig` plate lean; a plate sits at its own offset or 0.6 m over the model's tallest
point (`body.top_h`, `HudPlate.up`), whichever is higher, so a bigger body does not float its plate), stun stars, vulnerable sparks, glider heat smoke, a shoulder Boki's bubble, Sparkle's fingertip.
Meshy-native stride follows the model scale (`WardenNative._stride_k`).

`--hunter-size-sheet --shots-dir=<dir>` (GPU) prints one HSIZE row per hunter for main's size and the parity size;
`--hunter-scale-shots` shoots both with the plate and `--gaps` (no renderer) prints the plate-over-model gaps.
