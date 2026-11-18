# Slam follow-through

Goal: the slams carry weight. The hit lands on the kit's hit frame, holds a short beat, and the body is back on the legs
when the kit's keys end (the recover). Gameplay timing does not change: the kits, their hits and their KMOVES tables are
untouched. Only the clip's own clock moves, set per move in `content/rules/warden_anim/<hero>.json`:

- `time`: [[kit s, clip s], ...] with straight lines between the points.
  - A flat stretch holds the impact.
  - A steep stretch skips a dead or frozen stretch of the clip.
  - The last point is the clip's end, at the kit's last key. The clip may stop short of its own keys there.
- `fade`: the blend-in in seconds. 0.04-0.05 on a hit at the kit's t=0, so the impact pose arrives in 2-3 frames.
- `blend_out`: the seconds before the clip's end over which the body goes back to the legs while the clip keeps playing,
  so it is back on them at the kit's recover (WardenClips `_time_map`, `blend_out` in `_pick`).

`--slam-follow-check` (tools/slam_follow_check.gd) runs each slam at 60 fps on the kit's clock, after the move it comes
out of, and traces the strike point (the blade's tip or a fist). A pass needs all four:

- the impact (the first still frame after the strike) lands within -2..+3 frames of the kit's hit
- it holds within 3 cm for 3-9 frames
- no frame moves faster than 20 m/s while the body goes back to the legs
- the body is back on the legs within 0.05 s of the recover

## Slams on the v95 clips (hetzner, 2026-11-18)

Eight slams: Kael's Finishing Slam and Meteor Drop, Tenzo's RMB slam and tap slam, Grimble's Anchor Drop and quake,
Albert's charged swing and Faultline. 31 of 32 rows pass. Kael's meteor landing whips 40 m/s going back to the legs (the
sword arcs between the drag and the carry pose mid-blend): it sits in the check's `OPEN` and needs a nearer key in
Blender. Kael's Finishing Slam needed `blend_out` 0.45 (0.2 whipped 41 m/s) and Tenzo's slam ends on the kit's 1.51 s
(the 1.36 s of the first map left him on the legs 0.16 s early).

Render a strip with `jobq submit --tree . --needs gpu --out slam_shots -- --slam-follow-check --shots-dir=slam_shots`:
every 3rd frame from 0.2 s before the hit, with and without the follow-through keys.
