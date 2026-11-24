# Slam follow-through

Goal: the slams carry the source's weight and timing with our poses. The hit lands on the kit's hit frame, holds for a
short beat, recoils a little, and the body is back on the legs when the kit's keys end (the recover). Gameplay timing
does not change: the kits, their hits and their KMOVES tables are untouched, and the combo checks stay green. Three slams
(Grimble's air Anchor landing, Albert's two swings) carry the follow-through as keys in
their clips (see Keyed clips below) and play 1:1. Grimble's Anchor Drop keeps it in the clip's own clock, set per move
in `content/rules/warden_anim/<hero>.json`:

- `time`: [[kit s, clip s], ...] with straight lines between the points.
  - A flat stretch holds the impact.
  - A steep stretch skips a dead or frozen stretch of the clip.
  - The last point is the clip's end, at the kit's last key. The clip may stop short of its own keys there.
- `fade`: the blend-in in seconds. Use 0.04-0.05 for a hit at the kit's t=0 so the impact pose arrives in 2-3 frames
  instead of 6.
- `blend_out`: the seconds before the clip's end over which the body goes back to the legs while the clip keeps
  playing (0.05 on the keyed clips, which end on the idle carry themselves). The hand-back then ends on the kit's recover. Without it the body handed back 0.16 s late (FADE_LOCO), and
  Albert's hammer whipped down from overhead at 35-53 m/s.

Measured by `--slam-follow-check` (tools/slam_follow_check.gd). Each slam runs at 60 fps on the kit's clock, after the
move it comes out of, and the check traces the strike point (the blade's tip or the fist). A pass needs all four of:

- the impact (the first still frame after the strike) lands within -2..+3 frames of the kit's hit
- it holds within 3 cm for 3-9 frames
- no frame moves faster than 20 m/s while the body goes back to the legs
- the body is back on the legs within 0.05 s of the recover

## Before / after

Columns:

- **Impact**: the impact frame against the kit's hit frame, with the offset.
- **Hold**: frames the strike point stays within 3 cm.
- **Recoil**: how far the strike point rises in the 0.3 s after the hold.
- **Whip**: the fastest frame while the body goes back to the legs.
- **Back on legs**: seconds after the hit, against the kit's recover.

| Slam | Impact (now) | Hold | Recoil | Whip | Back on legs |
|---|---|---|---|---|---|
| Grimble Anchor Drop (dr_anchor) | +0 f | 9 → 6 f | 0.34 → 0.31 m | 3.8 → 5.2 m/s | 0.77 → 0.60 s (kit 0.62) |
| Grimble air Anchor landing (dr_quake) | +3 f | 3 → 5 f | 0.29 → 0.23 m | 2.9 → 4.4 m/s | 0.73 → 0.75 s (kit 0.75) |
| Albert charged swing (bul_smash) | +3 f | 5 → 6 f | 0.71 → 0.69 m | 6.0 → 7.3 m/s | 0.50 → 0.52 s (kit 0.50) |
| Albert Faultline (bul_ult_slam) | +3 f | 7 → 7 f | 0.64 → 0.57 m | 6.3 → 4.6 m/s | 0.60 → 0.62 s (kit 0.60) |

Before = the moves on current main (v95 clips): the Anchor Drop has no follow-through keys at all; the three keyed
ones are measured with their `time` maps (11-20, before the keyed clips). After = this branch. Every row of
`--slam-follow-check` passes.

Grimble's Anchor Drop (dr_anchor) holds 4 frames and skips 2 dead frames.

Kael and Tarek are not in the table: they are drawn on Meshy's own skeleton (WardenNative, `meshy_native` in
`content/rules/warden_native.json`), whose `_meshy.glb` has only Idle, Attack, Jump_Run, crouch, walk and run. Every
Kael and Tarek move plays that one Attack clip, so their slams have no clip to key and `--slam-follow-check` prints
`SLAM skip` for them. Their contract clips (`kael.glb`, `tarek.glb`) are not drawn and stay as on main.

## Keyed clips

Three clips carry the follow-through as keys, made in Blender by `tools/art1/slam_follow_keys.py` (a table of
(kit s, source clip s, carry weight) rows per clip) and spliced onto the shipped glbs with `tools/art1/glb_add_clips.py`
(`=<clip>`, so only those clips change; no mesh, head or material is touched). Their moves play 1:1 on the kit's clock.
Each clip is the kit's length and has the same three beats:

- A 4-6 frame hold on the impact pose (the clip's own landing/impact).
- A short recoil (the clip's own first rise after the impact).
- A recovery that eases into the idle's first frame (the idle carry) and sits there for the last 0.05 s.

| Clip (kit move) | Length | Hold | Recoil | Recovery |
|---|---|---|---|---|
| Albert `lmb_slam` (bul_smash) | 0.50 s | 0.04-0.11 s | to 0.2 s | 0.2-0.45 s |
| Albert `x_slam` (bul_ult_slam) | 0.60 s | 0.03-0.11 s | to 0.24 s | 0.24-0.55 s |
| Grimble `quake` (dr_quake) | 0.75 s | 0-0.10 s | to 0.2 s, settle to 0.3 s | 0.3-0.70 s (the old recovery at 1:1) |

- Albert's hammer no longer lifts back overhead: it rises about a hand's width, then comes down to the carry.
- Grimble's 0.4 s frozen opening is now the hold, recoil and settle; the recovery plays at the clip's own speed (it was
  0.5-0.6x under the map).
- `blend_out` stays on these moves at 0.05 s: a longer one hands the body to the legs while the clip is still
  recovering, and the blend itself whipped the hammer. The clip now ends on the carry.

`jobq submit --tree . --needs gpu --out slam_shots -- --slam-follow-check --shots-dir=slam_shots` renders every 3rd frame
of each slam from 0.2 s before the hit, as played now (`after`) and without its `time`, `fade` and `blend_out` keys (`before`).
