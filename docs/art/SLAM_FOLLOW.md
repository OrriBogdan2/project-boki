# Slam follow-through

Goal: the slams carry the source's weight and timing with our poses. The hit lands on the kit's hit frame, holds for a
short beat, recoils a little, and the body is back on the legs when the kit's keys end (the recover). Gameplay timing
does not change: the kits, their hits and their KMOVES tables are untouched, and the combo checks stay green. Only the
clip's own clock moves, set per move in `content/rules/warden_anim/<hero>.json`:

- `time`: [[kit s, clip s], ...] with straight lines between the points.
  - A flat stretch holds the impact.
  - A steep stretch skips a dead or frozen stretch of the clip.
  - The last point is the clip's end, at the kit's last key. The clip may stop short of its own keys there.
- `fade`: the blend-in in seconds. Use 0.04-0.05 for a hit at the kit's t=0 so the impact pose arrives in 2-3 frames
  instead of 6.
- `blend_out`: the seconds before the clip's end over which the body goes back to the legs while the clip keeps
  playing. The hand-back then ends on the kit's recover. Without it the body handed back 0.16 s late (FADE_LOCO), and
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

| Slam | Impact | Hold | Recoil | Whip | Back on legs |
|---|---|---|---|---|---|
| Kael Finishing Slam (jug_slam) | f37/f36 (+1) → same | 2 → 6 f | 0.07 → 0.06 m | 3.4 → 5.8 m/s | 0.68 → 0.53 s (kit 0.55) |
| Kael Meteor Drop (jug_meteor_land) | +15 → +3 f | 2 → 6 f | 0.45 → 0.94 m | 10.2 → 13.9 m/s | 0.67 → 0.50 s (kit 0.50) |
| Tarek RMB slam (breah_slam) | -1 → -1 f | 4 → 4 f | 0.07 → 0.18 m | 3.6 → 1.5 m/s | 0.93 → 0.75 s (kit 0.76) |
| Tarek RMB tap slam (breah_slam_land) | +6 → +3 f | 5 → 4 f | 0.10 → 0.29 m | 3.2 → 1.9 m/s | 0.90 → 0.73 s (kit 0.75) |
| Grimble Anchor Drop (dr_anchor) | +0 → +0 f | 9 → 6 f | 0.34 → 0.31 m | 3.8 → 5.2 m/s | 0.77 → 0.60 s (kit 0.62) |
| Grimble air Anchor landing (dr_quake) | +6 → +3 f | 13 → 3 f | 0.36 → 0.29 m | 2.7 → 2.6 m/s | 0.90 → 0.73 s (kit 0.75) |
| Albert charged swing (bul_smash) | +7 → +3 f | 2 → 5 f | 3.46 → 0.86 m | 53.5 → 6.5 m/s | 0.67 → 0.50 s (kit 0.50) |
| Albert Faultline (bul_ult_slam) | +7 → +3 f | 3 → 6 f | 3.22 → 0.63 m | 47.8 → 6.8 m/s | 0.77 → 0.60 s (kit 0.60) |

Before: 19 of 32 checks failed. After: 0 failed. Meteor Drop's recoil grew because the clip's drag now plays inside the
0.3 s window, sooner after the hold.

Notes on the time maps:

- Kael's two slams and Tarek's held slam keep their clip timing up to the hit, then flatten for the hold.
- Grimble's Anchor Drop holds 4 frames and skips 2 dead frames.
- The two t=0 landings (Tarek's tap slam, Grimble's quake) skip most of their 0.33-0.4 s frozen opening.
- Albert's two swings lead the clip to its settled impact pose (clip 0.1 s at kit 0). The 2-frame fade from the wind
  pose is the swing.

Strips are in `docs/art/slam_follow/<move>.png`: before on top, after below, every 3rd frame (20 fps) from 0.2 s before
the hit. Render them with
`jobq submit --tree . --needs gpu --out slam_shots -- --slam-follow-check --shots-dir=slam_shots`. The "before" row is
the same move with its `time`, `fade` and `blend_out` keys removed.

## Blender follow-up

These need new keys in Blender. The maps above work around them; see docs/DEBT.md.

- Albert `lmb_slam` and `x_slam`:
  - They swing in 4 frames.
  - They recover by lifting the hammer back overhead (3.2-3.5 m at the tip), which reads as a bounce, not weight.
  - Key a 4-6 frame hold on the ground, a short recoil (about 0.3 m), and a recovery that ends on the idle carry at the
    kit's length (0.5 s and 0.6 s).
  - The maps stop the clip at 0.23 s and 0.3 s and blend to the legs from there.
- Tarek `rmb_land` and Grimble `quake`:
  - They open on a 0.33-0.4 s frozen pose.
  - Move the recovery up so it fills the kit's 0.75 s at 1:1.
  - The maps skip the frozen pose, so the recovery now plays at about 0.5-0.6x speed.
- Kael `meteor_land`: the sword drags along the ground at 10 m/s for 10 frames right after the impact. Key a settle
  there instead.
