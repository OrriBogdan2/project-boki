# Hunter red tint, Sparkle's waist, which model each Hunter has (owner playtest 11-11, 0.24.4)

Shots: `godot -- --hunter-tint-shots --size=1920x1080 --shots-dir=<dir>` (tools/hunter_tint_shots.gd; xvfb + opengl3).
`before/` is ext/release-integ-0245 272368589, `after/` is ext/hunter-tint-1111. Files: `select.jpg` is every Hunter
on the Hunters screen's turntable stage (HunterViewer light). `match.jpg` and `match_close.jpg` are one of each in
a real match (clear evening). `lit.jpg` has each Hunter in the match light (top) over its bare albedo (bottom).
`tint.txt` has the mean colours. `neutral_glb.jpg` is the .glb files on their own glTF materials, as a glTF viewer
shows them.

## 1. Red tint: the cause
The textures are not red (neutral_glb.jpg, the albedo row of lit.jpg). The tint comes from the light. The default
"clear" raid light is a strong amber sun (`ffb27a`, linear 1.0/0.45/0.19). The world balances it with a blue-violet
ambient and fill. Painted Hunters did not get that balance: `WardenGlb.PAINTED` cuts the scene ambient
(`ambient_cut` 1, against lilac skin) and de-hues the blue fill (`light_neutral` 0.9), so the amber sun was the only
coloured light left. On top of that, the replacement ambient, `light_tint` and `shadow_tint` all leaned warm.

Fix: `light_neutral_warm` 0.8 for every painted slot, and `own_ambient`, `light_tint` and `shadow_tint` near
neutral. The per-slot `light_neutral_warm` patches of 0.8 or less in warden_look.json are removed (17 of them, all
skin-only workarounds for the same cast). Sable's skin keeps 1.0.

Red/blue of the mean colour in the match light vs the Hunter's own albedo (lit.jpg, front 3/4):

| Hunter | before | after | albedo |
|---|---|---|---|
| Lace | 1.36 | 1.23 | 1.13 |
| Kael | 1.36 | 1.26 | 1.18 |
| Vex | 1.24 | 1.13 | 1.21 |
| Albert | 1.25 | 1.14 | 1.23 |
| Cinder | 1.55 | 1.41 | 1.25 |
| Meeko | 1.26 | 1.15 | 1.18 |
| Tenzo (Tarek) | 1.34 | 1.23 | 1.34 |
| Grimble | 1.06 | 0.95 | 1.01 |
| Neve | 1.06 | 0.96 | 0.97 |
| Sparkle | 1.51 | 1.38 | 1.26 |
| Sable | 0.93 | 0.87 | 0.90 |
| Motley | 0.89 | 0.88 | 0.87 |
| Gil | 1.20 | 1.08 | 1.01 |

Before, the Hunters averaged +0.14 over their paint. After, the average is +0.03. What is left is per Hunter (the
signature `rim_far` colours: Lace, Kael and Cinder are red/orange). Gil's remaining +0.07 comes from the colour pick
(`WardenGlb._tint`): the default peach skin pick pushes his blue skin's red channel up to the 1.35x clamp. Not
changed here.

Still open: in the match light the Hunters render at about 55-65% of their paint's brightness (Neve 0.40 vs 0.73).
That is the evening light and is not changed here.

## 2. Sparkle's waist
In-game `art/wardens/ryzz/ryzz.glb` (2d5a5d20d, 11-11) is the swap of `~/meshy/v95/Sparkle/r2/final/sparkle_final.glb`
(underbust c + round-2 face, the body5 pick). It is not body6 `cand_B`. `cand_B` was made from that same file, with
only the vertex positions moved (pick.txt).

Measured as the torso loop width of a plane section in rest pose, the connected piece through the centre line
(arms left out), in units of pelvis height. Game pelvis 0.834 m, cand_B 0.930 m. Script: /tmp/tintsim/measure3.py
(Blender).

| | hip (max, 0.92) | waist (min, 1.28-1.32) | bust (1.36) |
|---|---|---|---|
| game ryzz.glb | 0.571 | 0.312 | 0.480 |
| body6 cand_B | 0.586 | 0.314 | 0.468 |

pick.txt (tape, convex hull): the game's basis has waist 0.224 and hip 0.490; cand_B has waist 0.216 (-3.6%) and
hip 0.502. So the game has the older model, but its waist is within about 3% of cand_B. Swapping in cand_B will not
change how big her waist looks. What reads wide is the tied hazard jacket around her hips, which is the same in
both. In a match the player's Build slider can also add up to 14% (MantleLook clamp).

## 3. Which pick each Hunter has
The picks list is from the brief. "Game" is the swap master named by `art/wardens/src/<id>_v95.json` or IMPORT.md.
Only Sparkle's body6 masters are copied to rpc4, so the masters were not hash-compared.

| Hunter (art id) | pick | game on 0.24.5 base (272368589) | 0.24.4 (owner's build) | status |
|---|---|---|---|---|
| Albert (breaker) | r2/appeal3/cand | appeal3 (albert_v95_body) | v2 slim hull (11-08) | ok on 0.24.5; 0.24.4 was old |
| Cinder (cinder) | r2/body6/cand_B | appeal4 cand_5 (bust5) | appeal3 body b | STALE |
| Grimble (dredge) | r2/appeal3/cand_b | v95 master (Grimble/v95.glb) | same | STALE |
| Kael (kael) | r2/appeal3/cand_c | appeal3 cand_c | same | ok |
| Meeko (pip) | r2/appeal3/cand_b | appeal3 cand_b | same | ok |
| Motley (ostra) | r2/appeal3/cand_b | appeal3 cand_b | same | ok |
| Sable (sable) | r2/body5/cand_3 | appeal3 cand_b_bugeye | same | STALE |
| Sparkle (ryzz) | r2/body6/cand_B | r2/final (body5 / underbust c) | same | STALE (small, see 2) |
| Vex (vex) | r2/appeal3/cand_b | appeal3 cand_b | same | ok (not body6 A) |
| Neve (claire) | r2/appeal3/cand_a | appeal3 cand_a | same | ok |
| Lace (hem) | r2/body6/cand_B | appeal3 cand_b | same | STALE |
| Tenzo (tarek) | r2/appeal3/cand_b | v2 Meshy scan (11-07), no v95 swap | same | STALE: "tarek looks bad" |
| Gil (gil) | (not on the list) | own model (11-10) | same | n/a |

ext/hunters3d-0246 59b74dd2d (READY earlier on 11-11, not merged) already carries Tarek appeal3 cand_b, Grimble
appeal3 cand_b and body6 Cinder B / Lace B / Sparkle B. But it also has Vex body6 A, which the owner rejected on
11-11, and Sable body6 A, which is not the body5 cand_3 pick. Job 171016-a2 had posted no READY when this was written.
