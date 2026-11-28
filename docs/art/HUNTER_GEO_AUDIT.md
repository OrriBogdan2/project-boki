# Hunter geometry audit (11-23, v2)

Owner 11-23: "make sure 3d models are checked for not clipping into each other and flattened hands" and "check all
individual parts, and make sure all parts dont clip through other parts". The check is `tools/anim/geo_check.py`
(numpy + scipy, no Blender or Godot; never writes a glb). It audited the in-game glb of all 13 hunters
(`content/rules/warden_native.json`: `meshy_native` -> `<key>_meshy.glb`, else `<key>.glb`).

Run it on a candidate before a swap:

```
python3 tools/anim/geo_check.py CANDIDATE.glb --compare LIVE.glb   # PASS / FAIL, exit code 1 on FAIL
python3 tools/anim/geo_check.py --hunter sable --out DIR            # the in-game glb of one hunter
python3 tools/anim/geo_check.py --all --out DIR                     # all 13: <key>.tsv, <key>.json, summary lines
```

FAIL when a held clip (idle, walk, run, crouch, glide, hold/guard loops; `HELD` in the script) clips a pair deeper
than 1 cm, a hand is FLAT, or the candidate is worse than `--compare` (a held pair 0.3 cm deeper, a hand's finger
separation 0.05 or thickness ratio 0.04 lower). Output is deterministic (same bytes under any `PYTHONHASHSEED`).

## How it measures

- Parts: each skinned vertex goes to a body region by its dominant bone (head, hair, torso, upper arm, forearm, hand,
  thigh, shin, foot, L/R; outfit shells; props). The hand = one hand length (11% of body height) past the wrist joint;
  what the hand bone carries further out is `prop:held_L/R` (Sable's pistols, Tarek's and Dredge's held pieces). A body
  region keeps its main connected surface patch; stray patches (skin-weight bleed) join the region around them. Large
  detached mesh islands are their own part (`part.2`). `/home/boki/bin/hunter-regions` does not exist on w2.
- Clipping: every pair of parts that is not anatomically joined, both ways, every 2nd frame (30 fps) of every clip
  plus the bind pose. A point of A is inside B when its exact closest point on B's triangles is behind B's surface,
  that closest point is not on B's open cut rim (beside a sleeve opening is not inside), and going on inward reaches
  B's far wall (a one-sided coat tail has no inside). Depth = the 3rd deepest such point, searched up to 25 cm.
- Flat hands (rest pose): finger separation (1 - hand silhouette / its hull, in the palm plane), thickness ratio
  (thickness / width), thumb lobe. FLAT = separation under 0.20 (fused mitten) or ratio under 0.30 (paper thin).
  Calibration by eye on Blender renders: Sparkle (`ryzz`) slim hand with clear fingers = sep 0.51/0.54, ratio 0.46;
  Sable (fist on a pistol) = sep 0.26/0.23; Lace (`hem`) lumpy fused left hand = sep 0.11. The old rule (ratio under
  0.6) failed Sparkle, whom the owner calls fine: a slim open hand is thin, not flat.
  `fingers-unrigged` = the rig has finger bones but no vertex rides them (a warning, not a FAIL).
- Checks of the check: skinning equals Blender's own (Sable Attack 1.25 s and run 0 s: 0.0 mm over 85,938 vertices);
  flagged points were looked at in Blender renders (Sable's pistol sinks into her thigh in run; Breaker's right hand
  sits inside his helmet in lmb_hold; arms sweep through heads in the Attack clips).

## v1 -> v2 (why the first table was wrong)

v1 (PR #761 first push) saturated at 10-12 cm for every hunter and called the fast clips "torn skin". The skin does
not tear (Blender render of Sable Attack is clean). v1's inside test (12-nearest-vertex normal vote) counted points
beside open part rims and behind one-sided cloth as inside, and its hand cut took "the arm's far end", which on Sable is
the pistol barrel, so it measured guns as hands. Sparkle (`ryzz`) is the mage, not missing.

## Result (13 hunters)

| hunter | worst cm | frames over 1 cm | held frames over 1 cm | held worst cm | deepest held pairs (cm) | hand L (sep / ratio) | hand R (sep / ratio) |
|---|---|---|---|---|---|---|---|
| claire | 8.4 | 179 | 105 | 5.3 | hand_L.2>thigh_L.2 5.3, torso.3>shin_R.2 3.9 | ok 0.36 / 0.89 (fingers unrigged) | ok 0.38 / 0.57 (fingers unrigged) |
| ostra | 9.5 | 91 | 44 | 5.7 | foot_R>thigh_L 5.7, hair>torso 4.8 | ok 0.20 / 0.74 | ok 0.39 / 0.64 |
| breaker | 13.4 | 571 | 351 | 12.7 | hand_R>head 12.7, prop:hammer>head 12.2 | ok 0.46 / 0.94 (fingers unrigged) | ok 0.47 / 0.92 (fingers unrigged) |
| hem | 6.5 | 21 | 11 | 6.5 | outfit:skirt.2>shin_R.2 6.5, thigh_L.2>thigh_R.2 1.9 | FLAT 0.11 / 0.52 | ok 0.32 / 0.63 |
| ryzz | 8.2 | 34 | 6 | 3.8 | foot_R>foot_L 3.8, thigh_L>hand_L 2.8 | ok 0.51 / 0.46 | ok 0.54 / 0.45 |
| dredge | 25.0 | 538 | 360 | 12.5 | prop:held_L>head 12.5, prop:held_L>torso 11.4 | ok 0.51 / 0.57 (fingers unrigged) | ok 0.40 / 0.97 |
| gil | 13.6 | 159 | 97 | 13.4 | shin_L>thigh_R 13.4, hand_R>thigh_R 8.7 | ok 0.57 / 1.04 | ok 0.55 / 0.99 |
| tarek | 13.2 | 154 | 85 | 13.2 | prop:held_R>thigh_R 13.2, hand_R>thigh_R 12.9 | ok 0.26 / 0.80 | ok 0.45 / 0.38 |
| pip | 13.8 | 179 | 105 | 11.9 | hair.7>torso 11.9, hair.6>torso 10.3 | ok 0.57 / 0.49 | ok 0.59 / 0.46 |
| kael | 8.2 | 130 | 75 | 6.8 | forearm_R>upper_arm_L 6.8, hand_R>thigh_R 4.1 | ok 0.66 / 0.38 | ok 0.50 / 0.43 |
| vex | 12.4 | 734 | 501 | 10.2 | prop:coin>thigh_L 10.2, forearm_L>thigh_L 9.1 | ok 0.74 / 0.33 (fingers unrigged) | ok 0.31 / 0.75 |
| cinder | 9.3 | 108 | 62 | 9.3 | forearm_L>torso 9.3, outfit:cloth>shin_R 5.9 | ok 0.35 / 0.72 | ok 0.27 / 0.68 |
| sable | 9.4 | 129 | 61 | 8.5 | prop:held_L>thigh_L 8.5, hand_L>thigh_L 7.8 | ok 0.26 / 0.73 | ok 0.23 / 0.77 |

Fewest held clip frames: Ryzz 6, Hem 11, Ostra 44, Sable 61, Cinder 62. Most: Vex 501, Dredge 360, Breaker 351 (the
contract rigs have 40-60 clips each). By the 1 cm rule every hunter still FAILs, so `--compare` against the live glb is
the practical gate for a swap. The common held clips are hands/held props swinging into the thighs in walk/run and
arms through the head (Attack is a fast clip and is listed apart).

Hands: only Hem L is FLAT by geometry. Vex (owner-flagged) is a rig fault the shape test cannot see: Vex's contract
skeleton puts `hand.L` at the hip, so belt beads ride the hand bone, the visible hand rides the forearm, and
`fingers.L`/`thumb.L` carry no vertex (`fingers-unrigged`). Hem R looks lumpy in the render but measures sep 0.32.

## Not covered

- Props hung at runtime (Kael's sword, Cinder's heel jets: `WardenProps`) are not in the glb, so they are not tested.
- Dredge's 25.0 cm is the search cap, in a fast clip (pullend); held depths are under it.
- The FLAT threshold sits between 0.11 (Lace) and 0.23 (Sable's fist): a narrow gap from few owner-rated hands.

Files in `/home/boki/gens/hunter-geo-1123/`: per hunter `<key>.tsv` (clip, frame, pair, depth_cm, flags) and
`<key>.json` (per part: clips_into, flat, thickness_ratio, finger_sep, for the hunter panel); `sheet_1..3.jpg`
(1600 px, 3 worst frames per hunter, GPU job 20261123-233620-28759; red = the clipping part, see-through blue = the
part it sinks into; red border = a held clip over 1 cm, grey = a fast clip). Sheets: `--dump-shots DIR`, then
`jobq submit --tree . --needs gpu --out geo-shots -- --geo-shots --geo-dir=res://DIR --shots-dir=geo-shots`, then
`--sheets META PNGS OUT`.
