## Match Hunters drawn at the reference's height, one size each (`body.match_k`, 11-27)

Owner rule: the reference game is right on every metric unless proven otherwise. A global bump (+10%) left 9 of 13
Hunters more than 10% off the reference on screen, so every archetype now carries its own drawn size:
`content/archetypes/<id>.json` `body.match_k` (default 1; `Arch.match_k`) multiplies `Hunter.VIS_SCALE` (1.12). Gil
has none: the owner made him different on purpose. Visual only: hit radius, hurtbox height, body collision, speeds
and ranges keep their size (the reference's own hurtbox is one shared 0.43 m x 1.76 m shape whatever the model).

Method (11-27, second pass): size on screen, as the player sees it. Each hunter idles in combat (its real idle,
weapon drawn) at the match camera, at 8 facings; its silhouette (everything the model draws: weapon, hair, ears, back
props) is read in metres of the view plane at the hunter: on-screen height and area, the mean of the 8 facings. The
reference is measured the same way off its own idle clips at its 66 deg camera. Size = sqrt(height x sqrt(area)), so a
thin pole or a floating rock moves it less than height alone. The owner's reads hold on this measure (the healer
smallest bar the pet, under the sniper; the samurai not small, 20th of 25), and on height or area alone; the first
pass's bind-pose body height had the healer 3rd smallest and the samurai 7th, and the listed model height counts ears.
`match_k` = reference size / ours at k = 1 (`--hunter-size-sheet --silhouette`, HSIL "lean all" rows). Caveat:
reference props that are loose meshes (a shield, a dagger, a bird) are not in its silhouette, ours are (Albert and
Sable read a little small for it).

Camera: pitch 66 deg both sides; the reference lens is 59 deg horizontal (35.3 vertical at 16:9), arm 30.2 m at its
widest; ours is 32 deg vertical at 23 m x 1.4572 = 33.5 m, 34.2 m of ground across on both sides: same px per m
across. Up the screen ours is taller: `CamRig.CHAR_LEAN` (20 deg) tips bodies back, so one metre of hunter reads
1.3-1.75x as tall as with no lean; the reference has none. `match_k` is set with the lean on (what the player sees);
with the lean off every hunter would want 9-26% more.

What follows a Hunter's size (all read `Arch.match_k`): overhead and hover plates and their anchors (`Hud._head`,
`HunterZone.rect_of`, the `CamRig` plate lean; a plate sits at its own offset or 0.6 m over the model's tallest
point (`body.top_h`, `HudPlate.up`), whichever is higher, so a bigger body does not float its plate), stun stars, vulnerable sparks, glider heat smoke, a shoulder Boki's bubble, Sparkle's fingertip.
Meshy-native stride follows the model scale (`WardenNative._stride_k`).

`--hunter-size-sheet --shots-dir=<dir>` (GPU) prints one HSIZE row per hunter for main's size and the parity size;
`--hunter-scale-shots` shoots both with the plate and `--gaps` (no renderer) prints the plate-over-model gaps.
