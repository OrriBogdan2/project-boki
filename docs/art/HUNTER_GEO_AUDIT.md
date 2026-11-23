# Hunter geometry audit (11-23)

Owner 11-23: "make sure 3d models are checked for not clipping into each other and flattened hands." The check is
`tools/anim/geo_check.py` (numpy + scipy, no Blender or Godot; never writes a glb). It audited the in-game glb of all 13
hunters (`content/rules/warden_native.json`: `meshy_native` -> `<key>_meshy.glb`, else `<key>.glb`).

Run it on a candidate before a swap:

```
python3 tools/anim/geo_check.py CANDIDATE.glb --compare LIVE.glb   # PASS / FAIL, exit code 1 on FAIL
python3 tools/anim/geo_check.py --hunter sable --out DIR            # the in-game glb of one hunter
python3 tools/anim/geo_check.py --all --out DIR                     # all 13: <key>.tsv, <key>.json, summary lines
```

FAIL when a held clip (idle, walk, run, crouch, glide, hold/guard loops; `HELD` in the script) clips a pair deeper
than 1 cm, a hand is FLAT, or the candidate is worse than `--compare` (a held pair 0.3 cm deeper, a hand ratio 0.04 lower).

## How it measures

- Parts: each skinned vertex goes to one body region by its dominant bone (head, hair, torso, upper arm, forearm, hand,
  thigh, shin, foot, left and right; outfit shells; props). Meshy's hand joint sits mid-forearm, so the hand is cut by
  geometry (the arm's far 10.5% of body height). Material names (skirt, sword, hammer...) and mesh pieces detached from the
  whole body (`part.2`) make their own parts. `/home/boki/bin/hunter-regions` does not exist on w2, so the region list
  comes from bone and material names.
- Clipping: every pair of parts that is not anatomically joined, both ways, every 2nd frame (30 fps) of every clip plus
  the bind pose. A point is inside a part when 90% of its 12 nearest surface points have it behind their normal; depth =
  the 3rd deepest such point; cloth shells only count as the sinking part; points near the hinge two parts share
  (two thighs at the hip) are skipped.
- Flat hands: PCA of the hand's skinned vertices; thickness ratio = palm thickness / palm width, at rest and at the
  worst clip frame; thumb lobe and finger separation are in the JSON. FLAT = ratio under 0.6 at rest or at any frame.
  Calibration: hands that look fine are Sable 0.80/0.81, Claire 0.89, Dredge 0.94/1.09, Ostra L 0.88; the flagged ones are
  Hem (Lace) 0.53/0.51 and Vex L 0.47; 0.6 sits in the gap.
- Check of the check: the skinning was compared with Blender's own evaluation of Sable's Attack clip at 1.0 s: 3 micron
  max difference over 85,938 vertices.

## Result (13 hunters)

| hunter | worst cm | frames over 1 cm | held frames over 1 cm | deepest held pairs (cm) | hand L | hand R |
|---|---|---|---|---|---|---|
| claire | 10.9 | 115 | 66 | thigh_L.2>hand_R.2 10.7, forearm_R.4>thigh_R.2 9.8 | ok 0.89 (worst 0.84) | ok 0.89 (worst 0.89) |
| ostra | 10.2 | 179 | 105 | foot_L>shin_R 9.8, thigh_L>thigh_R 9.6 | ok 0.88 (worst 0.65) | FLAT 0.79 (worst 0.51) |
| breaker | 11.1 | 660 | 404 | hand_R>head 11.1, prop:hammer>head 10.0 | ok 0.83 (worst 0.65) | FLAT 0.95 (worst 0.26) |
| hem | 11.0 | 118 | 82 | hand_L>thigh_R.2 10.9, hand_R>thigh_R.2 10.6 | FLAT 0.53 (worst 0.53) | FLAT 0.51 (worst 0.49) |
| ryzz | 9.9 | 40 | 10 | thigh_R>thigh_L 9.4, foot_R>foot_L 3.6 | FLAT 0.43 (worst 0.43) | FLAT 0.44 (worst 0.44) |
| dredge | 11.0 | 503 | 349 | forearm_L>head 11.0, forearm_L>thigh_R 10.8 | ok 0.94 (worst 0.94) | ok 1.09 (worst 1.09) |
| gil | 11.4 | 176 | 106 | thigh_R>hand_R 11.4, upper_arm_R>hand_R 10.9 | FLAT 0.51 (worst 0.47) | ok 0.97 (worst 0.69) |
| tarek | 11.4 | 157 | 88 | hand_L>thigh_L 11.4, hand_R>thigh_R 11.0 | ok 0.80 (worst 0.67) | FLAT 0.36 (worst 0.34) |
| pip | 11.5 | 177 | 104 | hair.3>forearm_R 9.3, hair.7>thigh_L 9.2 | FLAT 0.59 (worst 0.58) | FLAT 0.42 (worst 0.42) |
| kael | 10.1 | 53 | 26 | thigh_L>upper_arm_L 9.4, hand_L>thigh_L 8.8 | FLAT 0.36 (worst 0.36) | FLAT 0.29 (worst 0.24) |
| vex | 11.1 | 734 | 501 | torso>hand_L 10.9, thigh_L>forearm_L 10.6 | FLAT 0.47 (worst 0.26) | ok 0.76 (worst 0.76) |
| cinder | 11.0 | 115 | 60 | thigh_L>thigh_R 10.0, outfit:cloth>shin_R 5.7 | FLAT 0.71 (worst 0.52) | FLAT 0.68 (worst 0.50) |
| sable | 11.3 | 116 | 47 | hand_L>thigh_L 8.2, forearm_R>thigh_R 7.1 | ok 0.81 (worst 0.81) | ok 0.80 (worst 0.80) |

Read it as a ranking by frames, not by cm: depth saturates around 10-11 cm (the 12 cm search limit) for every
hunter, because Meshy's skin tears in the fast clips (the Attack frames render as shredded triangles) and big overlapping
cloth and limb shells sit inside each other. Fewest held frames: Ryzz 10, Kael 26, Sable 47, Cinder 60, Claire 66. Most:
Vex 501, Breaker 404, Dredge 349 (the contract rigs have 40-60 clips each).
By the 1 cm rule every hunter FAILs today, so `--compare` against the live glb is the practical gate for a swap.
FLAT hands (rest or worst frame under 0.6): Kael, Ryzz, Pip, Hem, Cinder (both); Gil L, Tarek R, Vex L, Ostra R and
Breaker R (worst frame only: the hand flattens in a clip).

## Not covered

- Props hung at runtime (Kael's sword, Cinder's heel jets: `WardenProps`) are not in the Meshy glb, so they are not
  tested; neither are the weapon anchors (`anchor_gun_R`).
- Depth is capped at 12 cm; the parts are blobs by bone weight, so a hand inside a coat panel and a coat that is skinned
  to the thigh read the same. Check the sheets before calling a pair a visible clip.
- Sparkle has no hunter key here, so the calibration used Sable, Claire, Dredge and Ostra as the fine ones.

Files: per hunter `<key>.tsv` (clip, frame, pair, depth_cm, flags) and `<key>.json` (per part: clips_into, flat,
thickness_ratio, for the hunter panel) in `/home/boki/gens/hunter-geo-1123/`, sheets `sheet_N.jpg` there.
Sheets: `--dump-shots DIR` writes the 3 worst frames per hunter, `--geo-shots` (tools/geo_shots.gd) renders them on
the GPU (`jobq submit --needs gpu --out geo-shots -- --geo-shots --geo-dir=res://DIR --shots-dir=geo-shots`),
`--sheets META PNGS OUT` builds the 1600 px pages (red border = a held clip over 1 cm, grey = not).
