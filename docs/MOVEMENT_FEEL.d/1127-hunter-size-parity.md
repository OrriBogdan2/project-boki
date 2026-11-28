## Match Hunters drawn at the reference's height, one size each (`body.match_k`, 11-27)

Owner rule: the reference game is right on every metric unless proven otherwise. A global bump (+10%) left 9 of 13
Hunters more than 10% off the reference on screen, so every archetype now carries its own drawn size:
`content/archetypes/<id>.json` `body.match_k` (default 1; `Arch.match_k`) multiplies `Hunter.VIS_SCALE` (1.12). Gil
has one too (1.242: at k 1 he drew 19% under his partner, a fish that read small beside it). Visual only: hit radius, hurtbox height, body collision, speeds
and ranges keep their size (the reference's own hurtbox is one shared 0.43 m x 1.76 m shape whatever the model).

Method (11-27, second pass): size on screen, as the player sees it. Each hunter idles in combat (its real idle,
weapon drawn) at the match camera, at 8 facings; its silhouette (everything the model draws: weapon, hair, ears, back
props) is read in metres of the view plane at the hunter: on-screen height and area, the mean of the 8 facings. The
reference is measured the same way off its own idle clips at its 66 deg camera. Size = sqrt(height x sqrt(area)), so a
thin pole or a floating rock moves it less than height alone. The owner's reads hold on this measure (the healer
smallest bar the pet, under the sniper; the samurai not small, 20th of 25), and on height or area alone; the first
pass's bind-pose body height had the healer 3rd smallest and the samurai 7th, and the listed model height counts ears.
`match_k` = reference size / ours at k = 1 (`--hunter-size-sheet --silhouette`, the mean of its two HSIL passes,
which differ by idle phase only: +-2.5%). Loose props are left out on both sides (the reference's are separate
meshes, out of its silhouette): Albert is sized on the HSIL "bare" row: the hammer, shield and lure bones shrunk away
and everything above the helmet dome (+0.1 m) plus the back poles (hip height and up, behind him) cut by a world-space
clip, because the poles are skinned into his body mesh and reach 1.4 m over his head (his arms-out hammer idle drew him
twice the reference's size on height alone: k 1.624; the older "crown" row cut his head too and gave 1.361). On the bare
row his body is 2.97 m x 3.13 m2 on screen at k 1.198 (size 2.293, re-measured 11-28 on the merged tree), against 2.91 m x 3.18 m2 for his partner (size 2.278, +0.7%, 25th of 25). Gil re-measured the same way: size 0.995 at k 1.242 against 0.994 for Beebo (+0.1%).
Sable is on the "body" row (held weapons hidden). The other 11 use the "all" row. With these, all 13 stand in the
reference's order of size, smallest to largest.

Width (11-28, reported, no model changed). The hunter facing the camera in its combat idle, one frame, silhouette
opened by 4 cm so hair spikes and blades drop out; per row the widest run, median over the rows 30-60% down the
silhouette (the torso and shoulder band), at match size, against the same read of its partner's silhouette (`width.py`,
private). One frame, so a partner caught mid-lean reads narrow: treat the gaps over +-30% as a lead, not a verdict.

| hunter | our width m | partner m | gap |
|---|---|---|---|
| Neve | 0.70 | 0.27 | +160% |
| Lace | 1.06 | 0.56 | +89% |
| Kael | 0.61 | 0.36 | +71% |
| Sable | 0.61 | 0.38 | +62% |
| Motley | 0.58 | 0.95 | -39% |
| Sparkle | 0.62 | 0.86 | -28% |
| Grimble | 0.99 | 1.36 | -27% |
| Albert | 1.27 | 1.53 | -17% |
| Vex | 0.99 | 0.85 | +17% |
| Cinder | 0.65 | 0.59 | +9% |
| Tenzo | 0.68 | 0.64 | +7% |
| Gil | 0.73 | 0.69 | +6% |
| Meeko | 0.78 | 0.77 | +2% |

Camera: pitch 66 deg both sides; the reference lens is 59 deg horizontal (35.3 vertical at 16:9), arm 30.2 m at its
widest; ours is 32 deg vertical at 23 m x 1.4572 = 33.5 m, 34.2 m of ground across on both sides: same px per m
across. Bodies stand upright like the reference's (`CamRig.CHAR_LEAN` 0; a
20 deg tip-back made one metre of hunter read 1.3-1.75x as tall as theirs). Leans that come from moving (stride
start, landing, glider tilt) are the body's own and stay.

What follows a Hunter's size (all read `Arch.match_k`): overhead and hover plates and their anchors (`Hud._head`,
`HunterZone.rect_of`, the `CamRig` plate lean (`CamRig.target`, set by `MatchCam.update`); a plate sits at its own
offset or 1.0 m over the model's tallest point (`body.top_h`, `HudPlate.up`; upright, its 17 px hang and some air), whichever is higher, so a bigger body does not float its plate), stun stars, vulnerable sparks, glider heat smoke, a shoulder Boki's bubble, Sparkle's fingertip.
Meshy-native stride follows the model scale (`WardenNative._stride_k`).

`--hunter-size-sheet --shots-dir=<dir>` (GPU) prints one HSIZE row per hunter for main's size and the parity size;
`--hunter-scale-shots` shoots both with the plate and `--gaps` (no renderer) prints the plate-over-model gaps.
`--hunter-size-sheet --lineup=<arch,...>` (GPU) draws those hunters side by side at their match size in one
game-camera frame (`lineup.png`).
